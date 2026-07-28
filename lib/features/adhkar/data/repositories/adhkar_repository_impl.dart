/// Repository implementation for the Adhkar catalog.
library;

import 'package:injectable/injectable.dart';

import '../../domain/entities/adhkar_entities.dart';
import '../../domain/repositories/adhkar_repository.dart';
import '../datasources/adhkar_local_data_source.dart';

@LazySingleton(as: AdhkarRepository)
class AdhkarRepositoryImpl implements AdhkarRepository {
  final AdhkarLocalDataSource _dataSource;

  AdhkarRepositoryImpl(this._dataSource);

  /// Deep-link / notification category keys pinned to the top of the list.
  static const List<String> _priorityCategories = [
    'أذكار الصباح',
    'أذكار المساء',
  ];

  @override
  Future<List<AdhkarItem>> getAllAdhkar() => _dataSource.loadAdhkar();

  @override
  Future<List<AdhkarCategory>> getCategories() async {
    final items = await _dataSource.loadAdhkar();
    final counts = <String, int>{};
    final labelsEn = <String, String>{};
    final labelsAr = <String, String>{};

    for (final item in items) {
      counts[item.category] = (counts[item.category] ?? 0) + 1;
      if (item.categoryEn.isNotEmpty) {
        labelsEn.putIfAbsent(item.category, () => item.categoryEn);
      }
      if (item.categoryAr.isNotEmpty) {
        labelsAr.putIfAbsent(item.category, () => item.categoryAr);
      }
    }

    final categories = counts.entries
        .map(
          (e) => AdhkarCategory(
            name: e.key,
            nameEn: labelsEn[e.key] ?? '',
            nameAr: labelsAr[e.key] ?? '',
            itemCount: e.value,
          ),
        )
        .toList();

    categories.sort((a, b) {
      final ai = _priorityCategories.indexOf(a.name);
      final bi = _priorityCategories.indexOf(b.name);
      if (ai != -1 || bi != -1) {
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return categories;
  }

  @override
  Future<List<AdhkarItem>> getAdhkarByCategory(String category) async {
    final items = await _dataSource.loadAdhkar();
    return items.where((i) => i.category == category).toList(growable: false);
  }

  @override
  Future<List<AdhkarItem>> searchAdhkar(
    String query, {
    String? category,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final items = await _dataSource.loadAdhkar();
    final q = trimmed.toLowerCase();

    Iterable<AdhkarItem> source = items;
    if (category != null && category.isNotEmpty) {
      source = source.where((i) => i.category == category);
    }

    return source.where((i) {
      return i.arabic.toLowerCase().contains(q) ||
          i.translation.toLowerCase().contains(q) ||
          i.transliteration.toLowerCase().contains(q) ||
          i.category.toLowerCase().contains(q) ||
          i.categoryEn.toLowerCase().contains(q) ||
          i.categoryAr.toLowerCase().contains(q) ||
          i.reference.toLowerCase().contains(q) ||
          i.benefits.toLowerCase().contains(q) ||
          i.benefitsAr.toLowerCase().contains(q) ||
          i.book.toLowerCase().contains(q) ||
          i.narrator.toLowerCase().contains(q) ||
          i.authenticity.toLowerCase().contains(q) ||
          i.search.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  // ── Favorites ──

  @override
  Future<Set<String>> getFavoriteKeys() => _dataSource.getFavoriteKeys();

  @override
  Future<void> toggleFavorite(String uniqueKey) async {
    final keys = await _dataSource.getFavoriteKeys();
    if (keys.contains(uniqueKey)) {
      keys.remove(uniqueKey);
    } else {
      keys.add(uniqueKey);
    }
    await _dataSource.saveFavoriteKeys(keys);
  }

  @override
  Future<bool> isFavorite(String uniqueKey) async {
    final keys = await _dataSource.getFavoriteKeys();
    return keys.contains(uniqueKey);
  }

  // ── Settings ──

  @override
  Future<AdhkarSettings> getSettings() => _dataSource.getSettings();

  @override
  Future<void> saveSettings(AdhkarSettings settings) =>
      _dataSource.saveSettings(settings);

  // ── Tasbeeh Stats ──

  @override
  Future<TasbeehStats> getTasbeehStats() => _dataSource.getTasbeehStats();

  @override
  Future<TasbeehStats> recordTasbeehProgress({
    required String dhikrText,
    required int repetitions,
    required int durationMs,
    bool countAsCompletedSession = false,
  }) async {
    final current = await _dataSource.getTasbeehStats();
    final updated = current.recordProgress(
      dhikrText: dhikrText,
      repetitions: repetitions,
      durationMs: durationMs,
      countAsCompletedSession: countAsCompletedSession,
    );
    await _dataSource.saveTasbeehStats(updated);
    return updated;
  }

  @override
  Future<TasbeehStats> clearTasbeehStatsDay(String date) async {
    final updated = (await _dataSource.getTasbeehStats()).clearDay(date);
    await _dataSource.saveTasbeehStats(updated);
    return updated;
  }

  @override
  Future<TasbeehStats> clearAllTasbeehStats() async {
    const empty = TasbeehStats();
    await _dataSource.saveTasbeehStats(empty);
    return empty;
  }

  // ── Tasbeeh Session ──

  @override
  Future<Map<String, dynamic>?> getSavedTasbeehSession() =>
      _dataSource.getTasbeehSession();

  @override
  Future<void> saveTasbeehSession(Map<String, dynamic> session) =>
      _dataSource.saveTasbeehSession(session);

  // ── Tasbeeh Collection ──

  @override
  Future<List<TasbeehCollectionItem>> getTasbeehCollection() =>
      _dataSource.getTasbeehCollection();

  @override
  Future<void> saveTasbeehCollection(List<TasbeehCollectionItem> items) =>
      _dataSource.saveTasbeehCollection(items);
}
