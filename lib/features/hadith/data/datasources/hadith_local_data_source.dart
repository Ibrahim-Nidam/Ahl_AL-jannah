import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:injectable/injectable.dart';

import '../../domain/entities/hadith_entities.dart';
import '../models/hadith_model.dart';

abstract class HadithLocalDataSource {
  Future<List<HadithCollectionMeta>> getCollections();
  Future<List<HadithEntity>> getHadithsByCollection(String collectionId);
  Future<List<HadithSearchResult>> search(String query, {String? collectionId});
}

/// Decodes and unwraps a hadith JSON asset.
Map<String, dynamic> _decodeAndUnwrap(String raw) {
  final decoded = json.decode(raw) as Map<String, dynamic>;
  // Some exports (fawazahmed0 hadith-api dumps) wrap the actual payload
  // inside a top-level "data" envelope:
  // { "data": { "collection": ..., "items": [...] } }
  final inner = decoded['data'];
  if (inner is Map<String, dynamic>) return inner;
  return decoded;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Extracts only catalog metadata off the UI thread. Large files (Bukhari)
/// are fully parsed in the isolate, but only a tiny map crosses back —
/// not thousands of item records.
Map<String, dynamic> _parseCatalogMeta(String raw) {
  final data = _decodeAndUnwrap(raw);
  final items = data['items'];
  return {
    'collection': data['collection'],
    'lang': data['lang'],
    'count': _asInt(data['count']) ?? (items is List ? items.length : 0),
    'attribution': data['attribution'],
    'license': data['license'],
    'license_url': data['license_url'],
    'source_url': data['source_url'],
    'source_id': data['source_id'],
  };
}

/// Parses every hadith entry off the UI thread.
List<Map<String, dynamic>> _parseItems(String raw) {
  final data = _decodeAndUnwrap(raw);
  final fallbackCollectionId = (data['collection'] as String?) ?? '';
  final rawItems = (data['items'] as List?) ?? const [];
  final result = <Map<String, dynamic>>[];
  for (final entry in rawItems) {
    if (entry is! Map) continue;
    final json = Map<String, dynamic>.from(entry);
    result.add({
      'collectionId': json['collection'] as String? ?? fallbackCollectionId,
      'number': _asInt(json['number']) ?? 0,
      'arabicNumber': _asInt(json['arabic_number']),
      'book': _asInt(json['book']),
      'text': (json['text'] as String? ?? '').trim(),
    });
  }
  return result;
}

String _normalizeText(String text) {
  var normalized = text.toLowerCase();
  normalized = normalized.replaceAll(
    RegExp(r'[\u064B-\u0652\u0670\u0640\u0653-\u0655\u06DF-\u06E8\u06EA-\u06EC]'),
    '',
  );
  normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
  normalized = normalized.replaceAll('ة', 'ه');
  return normalized;
}

List<Map<String, dynamic>> _searchInIsolate(Map<String, dynamic> args) {
  final query = args['query'] as String;
  final scopedCollectionId = args['scopedCollectionId'] as String?;
  final entries = args['entries'] as List<dynamic>;
  final normalizedQuery = _normalizeText(query);
  if (normalizedQuery.isEmpty) return const [];

  final results = <Map<String, dynamic>>[];
  for (final entry in entries) {
    final meta = Map<String, dynamic>.from(entry as Map);
    if (scopedCollectionId != null && meta['collectionId'] != scopedCollectionId) {
      continue;
    }

    final items = _parseItems(meta['raw'] as String);
    for (final item in items) {
      final text = item['text'] as String;
      if (_normalizeText(text).contains(normalizedQuery)) {
        results.add({
          ...item,
          'collectionTitle': meta['displayTitle'],
          'collectionTitleAr': meta['displayTitleAr'],
        });
      }
    }
  }
  return results;
}

/// Discovers every `.json` file under `assets/hadith/` via the Flutter
/// asset manifest, parses each lazily on first access off the main
/// isolate, and caches the result in memory for the app's lifetime.
/// UI-side pagination for large collections lives in [HadithCubit].
///
/// To add a new collection: drop a JSON file matching this shape into
/// `assets/hadith/` — no Dart changes needed, just rebuild:
/// ```json
/// {
///   "collection": "muslim",
///   "lang": "ar",
///   "count": 1234,
///   "items": [{"collection": "muslim", "number": 1, "text": "..."}]
/// }
/// ```
@LazySingleton(as: HadithLocalDataSource)
class HadithLocalDataSourceImpl implements HadithLocalDataSource {
  static const _assetFolder = 'assets/hadith/';

  /// Known collection ids -> friendly English/Latin display titles.
  /// Anything not listed here falls back to a title-cased version of its
  /// id, so unrecognised future collections still render sensibly.
  static const _knownTitlesEn = <String, String>{
    'bukhari': 'Sahih al-Bukhari',
    'muslim': 'Sahih Muslim',
    'qudsi': 'Hadith Qudsi (40)',
    'nawawi': "Nawawi's 40 Hadith",
    'tirmidhi': 'Jami at-Tirmidhi',
    'abudawud': 'Sunan Abu Dawud',
    'nasai': "Sunan an-Nasa'i",
    'ibnmajah': 'Sunan Ibn Majah',
    'malik': 'Muwatta Malik',
    'riyadussalihin': 'Riyad as-Salihin',
  };

  /// Same collections, in Arabic — used so collection names don't show up
  /// in Latin script when the app is running in Arabic.
  static const _knownTitlesAr = <String, String>{
    'bukhari': 'صحيح البخاري',
    'muslim': 'صحيح مسلم',
    'qudsi': 'الأحاديث القدسية (٤٠)',
    'nawawi': 'الأربعون النووية',
    'tirmidhi': 'جامع الترمذي',
    'abudawud': 'سنن أبي داود',
    'nasai': 'سنن النسائي',
    'ibnmajah': 'سنن ابن ماجه',
    'malik': 'موطأ الإمام مالك',
    'riyadussalihin': 'رياض الصالحين',
  };

  List<HadithCollectionMeta>? _collectionsCache;
  final Map<String, List<HadithModel>> _itemsCache = {};
  final Map<String, Future<String>> _rawCache = {};

  Future<List<String>> _discoverAssetPaths() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((p) => p.startsWith(_assetFolder) && p.endsWith('.json'))
        .toList();
    paths.sort();
    return paths;
  }

  String _titleForEn(String collectionId) {
    final known = _knownTitlesEn[collectionId.toLowerCase()];
    if (known != null) return known;
    if (collectionId.isEmpty) return collectionId;
    return collectionId
        .split(RegExp(r'[_\s/-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  String _titleForAr(String collectionId) {
    final known = _knownTitlesAr[collectionId.toLowerCase()];
    if (known != null) return known;
    // No sensible Arabic transliteration for an unknown id — fall back
    // to the English/Latin form rather than showing a raw slug.
    return _titleForEn(collectionId);
  }

  Future<String> _loadRawString(String assetPath) {
    return _rawCache.putIfAbsent(
      assetPath,
      () => rootBundle.loadString(assetPath),
    );
  }

  Future<Map<String, dynamic>> _loadCatalogMeta(String assetPath) async {
    final raw = await _loadRawString(assetPath);
    return compute(_parseCatalogMeta, raw);
  }

  @override
  Future<List<HadithCollectionMeta>> getCollections() async {
    final cached = _collectionsCache;
    if (cached != null) return cached;

    final paths = await _discoverAssetPaths();
    final metas = <HadithCollectionMeta>[];

    for (final path in paths) {
      try {
        final data = await _loadCatalogMeta(path);
        final collectionId = (data['collection'] as String?) ?? path;
        metas.add(
          HadithCollectionMeta(
            collectionId: collectionId,
            assetPath: path,
            lang: (data['lang'] as String?) ?? 'ar',
            count: (data['count'] as num?)?.toInt() ?? 0,
            displayTitle: _titleForEn(collectionId),
            displayTitleAr: _titleForAr(collectionId),
            attribution: data['attribution'] as String?,
            license: data['license'] as String?,
            licenseUrl: data['license_url'] as String?,
            sourceUrl: data['source_url'] as String?,
            sourceId: data['source_id'] as String?,
          ),
        );
      } catch (e) {
        // A malformed/unrelated json file in this folder shouldn't take
        // down the whole catalog — skip it.
        continue;
      }
    }

    metas.sort((a, b) => a.displayTitle.compareTo(b.displayTitle));
    _collectionsCache = metas;
    return metas;
  }

  Future<List<HadithModel>> _loadItems(String collectionId) async {
    final cached = _itemsCache[collectionId];
    if (cached != null) return cached;

    final collections = await getCollections();
    final meta = collections.firstWhere(
      (c) => c.collectionId == collectionId,
      orElse: () => throw StateError('Unknown hadith collection: $collectionId'),
    );

    final raw = await _loadRawString(meta.assetPath);
    final parsed = await compute(_parseItems, raw);
    final items = parsed.map(HadithModel.fromParsedMap).toList(growable: false);
    _itemsCache[collectionId] = items;
    return items;
  }

  @override
  Future<List<HadithEntity>> getHadithsByCollection(String collectionId) {
    return _loadItems(collectionId);
  }

  @override
  Future<List<HadithSearchResult>> search(String query, {String? collectionId}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final collections = await getCollections();
    final targets =
        collectionId == null ? collections : collections.where((c) => c.collectionId == collectionId);

    final entries = <Map<String, dynamic>>[];
    for (final meta in targets) {
      entries.add({
        'collectionId': meta.collectionId,
        'displayTitle': meta.displayTitle,
        'displayTitleAr': meta.displayTitleAr,
        'raw': await _loadRawString(meta.assetPath),
      });
    }

    final hits = await compute(_searchInIsolate, {
      'query': trimmed,
      'scopedCollectionId': collectionId,
      'entries': entries,
    });

    return hits
        .map(
          (hit) => HadithSearchResult(
            hadith: HadithModel.fromParsedMap(hit),
            collectionTitle: hit['collectionTitle'] as String,
            collectionTitleAr: hit['collectionTitleAr'] as String,
          ),
        )
        .toList(growable: false);
  }
}
