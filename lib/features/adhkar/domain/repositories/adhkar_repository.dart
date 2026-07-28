/// Repository contract for the Adhkar catalog.
library;

import '../entities/adhkar_entities.dart';

abstract class AdhkarRepository {
  /// Load all adhkar from the local catalog JSON asset (cached).
  Future<List<AdhkarItem>> getAllAdhkar();

  /// Get dynamically-derived category list.
  Future<List<AdhkarCategory>> getCategories();

  /// Get adhkar filtered by category key.
  Future<List<AdhkarItem>> getAdhkarByCategory(String category);

  /// Search adhkar by text query (Arabic, translation, transliteration, …).
  /// When [category] is set, results are limited to that category.
  Future<List<AdhkarItem>> searchAdhkar(String query, {String? category});

  // ── Favorites ──

  Future<Set<String>> getFavoriteKeys();
  Future<void> toggleFavorite(String uniqueKey);
  Future<bool> isFavorite(String uniqueKey);

  // ── Settings ──

  Future<AdhkarSettings> getSettings();
  Future<void> saveSettings(AdhkarSettings settings);

  // ── Tasbeeh Stats ──

  Future<TasbeehStats> getTasbeehStats();

  /// Records counting progress. No-op when [dhikrText] is empty.
  Future<TasbeehStats> recordTasbeehProgress({
    required String dhikrText,
    required int repetitions,
    required int durationMs,
    bool countAsCompletedSession = false,
  });

  Future<TasbeehStats> clearTasbeehStatsDay(String date);
  Future<TasbeehStats> clearAllTasbeehStats();

  // ── Tasbeeh Session Persistence ──

  Future<Map<String, dynamic>?> getSavedTasbeehSession();
  Future<void> saveTasbeehSession(Map<String, dynamic> session);

  // ── Tasbeeh Collection ──

  Future<List<TasbeehCollectionItem>> getTasbeehCollection();
  Future<void> saveTasbeehCollection(List<TasbeehCollectionItem> items);
}
