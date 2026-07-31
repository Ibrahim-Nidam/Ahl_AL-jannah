import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';

import '../../domain/entities/hadith_entities.dart';
import '../models/hadith_model.dart';

abstract class HadithLocalDataSource {
  Future<List<HadithAuthorMeta>> getAuthors();
  Future<List<HadithBookMeta>> getBooks(String authorId);
  Future<List<HadithItem>> getHadiths(String authorId, String bookId);

  /// Full-text search across every bundled collection (Arabic text,
  /// English translation, and book title). Results are capped so huge
  /// queries stay cheap.
  Future<List<HadithSearchResult>> searchHadiths(String query);
}

/// Describes one bundled collection folder under `assets/hadith/`.
class _AuthorDef {
  final String id;
  final String titleEn;
  final String titleAr;
  const _AuthorDef({required this.id, required this.titleEn, required this.titleAr});
}

/// Some upstream exports carry a UTF-8 BOM, which `dart:convert` rejects —
/// strip it before decoding.
String _stripBom(String raw) => raw.startsWith('\uFEFF') ? raw.substring(1) : raw;

/// Splits a combined book title like "1 Revelation كتاب بدء الوحى" at the
/// first Arabic-script character into its English and Arabic halves.
(String, String) _splitBookTitle(String combined) {
  final match = RegExp(r'[\u0600-\u06FF]').firstMatch(combined);
  if (match == null) return (combined.trim(), combined.trim());
  return (
    combined.substring(0, match.start).trim(),
    combined.substring(match.start).trim(),
  );
}

List<Map<String, dynamic>> _parseIndex(String raw) {
  final data = json.decode(_stripBom(raw)) as Map<String, dynamic>;
  final books = (data['books'] as List?) ?? const [];
  final result = <Map<String, dynamic>>[];
  for (final entry in books) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    final combined = map['title'] as String? ?? '';
    final (titleEn, titleAr) = _splitBookTitle(combined);
    result.add({
      'id': map['id'] as String? ?? '',
      'titleEn': titleEn,
      'titleAr': titleAr,
      'count': _asInt(map['count']) ?? 0,
    });
  }
  return result;
}

/// Parses a single book file (a JSON array of hadiths) off the UI thread.
List<Map<String, dynamic>> _parseBook(Map<String, dynamic> args) {
  final raw = args['raw'] as String;
  final authorId = args['authorId'] as String;
  final decoded = json.decode(_stripBom(raw));
  final list = decoded is List ? decoded : const [];
  final result = <Map<String, dynamic>>[];
  for (final entry in list) {
    if (entry is! Map) continue;
    final map = Map<String, dynamic>.from(entry);
    result.add({
      'authorId': authorId,
      'id': _asInt(map['id']) ?? 0,
      'book': (map['book'] as String? ?? '').trim(),
      'reference': (map['reference'] as String? ?? '').trim(),
      'grade': (map['grade'] as String? ?? '').trim(),
      'arabic': (map['arabic'] as String? ?? '').trim(),
      'english': (map['english'] as String? ?? '').trim(),
    });
  }
  return result;
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// Loads the CheeseWithSauce HadithsJSONFormat collections bundled under
/// `assets/hadith/`. Each author is a folder:
///
/// ```text
/// assets/hadith/bukhari/_index.json   { "collection": "bukhari",
/// assets/hadith/bukhari/001_....json    "books": [{"id","title","count"}, ...] }
/// assets/hadith/muslim/_index.json    + one .json file per book (a JSON array
/// assets/hadith/muslim/001_....json    of {collection,book,reference,grade,
/// assets/hadith/forty_nawawi/book.json  arabic,english,id})
/// ```
///
/// Book files are large (Muslim has ~7.5k hadiths) so each is parsed off
/// the main isolate and cached for the app's lifetime. UI-side pagination
/// for the resulting list lives in [HadithCubit].
@LazySingleton(as: HadithLocalDataSource)
class HadithLocalDataSourceImpl implements HadithLocalDataSource {
  static const _assetRoot = 'assets/hadith/';

  /// The bundled authors, in display order. Every other collection in the
  /// upstream repo can be added later by bundling its folder + appending a
  /// definition here.
  static const List<_AuthorDef> _authors = [
    _AuthorDef(id: 'bukhari', titleEn: 'Sahih al-Bukhari', titleAr: 'صحيح البخاري'),
    _AuthorDef(id: 'muslim', titleEn: 'Sahih Muslim', titleAr: 'صحيح مسلم'),
    _AuthorDef(id: 'forty_nawawi', titleEn: "Forty Hadith of an-Nawawi", titleAr: 'الأربعون النووية'),
    _AuthorDef(id: 'forty_qudsi', titleEn: 'Forty Hadith Qudsi', titleAr: 'الأحاديث القدسية'),
  ];

  List<HadithAuthorMeta>? _authorsCache;
  final Map<String, List<HadithBookMeta>> _booksCache = {};
  final Map<String, Future<List<HadithItem>>> _itemsCache = {};
  final Map<String, Future<String>> _rawCache = {};

  String _folder(String authorId) => '$_assetRoot$authorId/';

  Future<String> _loadRawString(String assetPath) {
    return _rawCache.putIfAbsent(assetPath, () => rootBundle.loadString(assetPath));
  }

  Future<List<HadithBookMeta>> _loadBooks(String authorId) async {
    final cached = _booksCache[authorId];
    if (cached != null) return cached;

    final raw = await _loadRawString('${_folder(authorId)}_index.json');
    final parsed = await compute(_parseIndex, raw);
    final books = parsed
        .map((b) => HadithBookMeta(
              authorId: authorId,
              id: b['id'] as String,
              titleEn: b['titleEn'] as String,
              titleAr: b['titleAr'] as String,
              count: b['count'] as int,
            ))
        .toList(growable: false);
    _booksCache[authorId] = books;
    return books;
  }

  @override
  Future<List<HadithAuthorMeta>> getAuthors() async {
    final cached = _authorsCache;
    if (cached != null) return cached;

    final metas = <HadithAuthorMeta>[];
    for (final def in _authors) {
      final books = await _loadBooks(def.id);
      final bookCount = books.length;
      final hadithCount = books.fold<int>(0, (sum, b) => sum + b.count);
      metas.add(
        HadithAuthorMeta(
          id: def.id,
          titleEn: def.titleEn,
          titleAr: def.titleAr,
          subtitleEn: '$bookCount books · $hadithCount hadiths',
          subtitleAr: '$hadithCount حديثاً · $bookCount كتاباً',
          bookCount: bookCount,
          hadithCount: hadithCount,
        ),
      );
    }
    _authorsCache = metas;
    return metas;
  }

  @override
  Future<List<HadithBookMeta>> getBooks(String authorId) => _loadBooks(authorId);

  @override
  Future<List<HadithItem>> getHadiths(String authorId, String bookId) async {
    final cacheKey = '$authorId/$bookId';
    final cached = _itemsCache[cacheKey];
    if (cached != null) return cached;

    final raw = await _loadRawString('${_folder(authorId)}$bookId.json');
    final future = compute(_parseBook, {'raw': raw, 'authorId': authorId}).then(
      (parsed) => parsed.map(HadithModel.fromParsedMap).toList(growable: false),
    );
    _itemsCache[cacheKey] = future;
    return future;
  }

  static const int _maxSearchResults = 300;

  @override
  Future<List<HadithSearchResult>> searchHadiths(String query) async {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return const [];

    final results = <HadithSearchResult>[];
    final authors = await getAuthors();
    for (final author in authors) {
      final books = await _loadBooks(author.id);
      for (final book in books) {
        final bookMatches = book.titleEn.toLowerCase().contains(normalized) ||
            book.titleAr.contains(normalized);
        if (bookMatches) {
          final items = await getHadiths(author.id, book.id);
          for (final item in items) {
            results.add(HadithSearchResult(author: author, book: book, item: item));
            if (results.length >= _maxSearchResults) return results;
          }
          continue;
        }
        final items = await getHadiths(author.id, book.id);
        for (final item in items) {
          if (item.arabic.contains(normalized) ||
              item.english.toLowerCase().contains(normalized)) {
            results.add(HadithSearchResult(author: author, book: book, item: item));
            if (results.length >= _maxSearchResults) return results;
          }
        }
      }
    }
    return results;
  }
}
