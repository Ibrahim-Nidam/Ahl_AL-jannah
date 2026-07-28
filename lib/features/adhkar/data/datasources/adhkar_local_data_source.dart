/// Local data source that reads the Adhkar catalog from the bundled JSON asset
/// and persists user data (favorites, settings, stats) in SharedPreferences.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/adhkar_entities.dart';
import '../models/adhkar_model.dart';

abstract class AdhkarLocalDataSource {
  Future<List<AdhkarItemModel>> loadAdhkar();
  Future<Set<String>> getFavoriteKeys();
  Future<void> saveFavoriteKeys(Set<String> keys);
  Future<AdhkarSettings> getSettings();
  Future<void> saveSettings(AdhkarSettings settings);
  Future<TasbeehStats> getTasbeehStats();
  Future<void> saveTasbeehStats(TasbeehStats stats);
  Future<Map<String, dynamic>?> getTasbeehSession();
  Future<void> saveTasbeehSession(Map<String, dynamic> session);
  Future<List<TasbeehCollectionItem>> getTasbeehCollection();
  Future<void> saveTasbeehCollection(List<TasbeehCollectionItem> items);
}

@LazySingleton(as: AdhkarLocalDataSource)
class AdhkarLocalDataSourceImpl implements AdhkarLocalDataSource {
  static const String _catalogAsset = 'assets/adhkar_catalog.json';
  static const String _legacyAsset = 'assets/adhkar.json';

  static const String _keyFavorites = 'adhkar_favorites';
  static const String _keySettings = 'adhkar_settings';
  static const String _keyTasbeehStats = 'adhkar_tasbeeh_stats';
  static const String _keyTasbeehSession = 'adhkar_tasbeeh_session';
  static const String _keyTasbeehCollection = 'adhkar_tasbeeh_collection';

  /// In-memory cache so we parse the JSON asset only once.
  List<AdhkarItemModel>? _cache;

  @override
  Future<List<AdhkarItemModel>> loadAdhkar() async {
    if (_cache != null) return _cache!;

    final raw = await _loadCatalogRaw();
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final items = decoded
        .whereType<Map<String, dynamic>>()
        .map(AdhkarItemModel.fromJson)
        .toList(growable: false);

    // Keep catalog order stable (already ordered within each category).
    _cache = items;
    return _cache!;
  }

  Future<String> _loadCatalogRaw() async {
    try {
      return await rootBundle.loadString(_catalogAsset);
    } catch (_) {
      // Fallback keeps the feature usable if only the legacy asset is present.
      return rootBundle.loadString(_legacyAsset);
    }
  }

  // ── Favorites ──

  @override
  Future<Set<String>> getFavoriteKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_keyFavorites);
    return list?.toSet() ?? {};
  }

  @override
  Future<void> saveFavoriteKeys(Set<String> keys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFavorites, keys.toList());
  }

  // ── Settings ──

  @override
  Future<AdhkarSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySettings);
    if (raw == null) return const AdhkarSettings();
    try {
      return AdhkarSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AdhkarSettings();
    }
  }

  @override
  Future<void> saveSettings(AdhkarSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettings, jsonEncode(settings.toJson()));
  }

  // ── Tasbeeh Stats ──

  @override
  Future<TasbeehStats> getTasbeehStats() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTasbeehStats);
    if (raw == null) return TasbeehStats.empty();
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return TasbeehStats.fromJson(decoded);
    } catch (_) {
      return TasbeehStats.empty();
    }
  }

  @override
  Future<void> saveTasbeehStats(TasbeehStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTasbeehStats, jsonEncode(stats.toJson()));
  }

  // ── Tasbeeh Session ──

  @override
  Future<Map<String, dynamic>?> getTasbeehSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTasbeehSession);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveTasbeehSession(Map<String, dynamic> session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyTasbeehSession, jsonEncode(session));
  }

  // ── Tasbeeh Collection ──

  @override
  Future<List<TasbeehCollectionItem>> getTasbeehCollection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyTasbeehCollection);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(TasbeehCollectionItem.fromJson)
          .where((e) => e.arabic.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveTasbeehCollection(List<TasbeehCollectionItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyTasbeehCollection,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }
}
