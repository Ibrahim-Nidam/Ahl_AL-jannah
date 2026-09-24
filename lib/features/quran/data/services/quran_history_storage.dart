import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../domain/entities/quran_history_item.dart';

class QuranHistoryStorage {
  static const String _keyHistoryPrefix = 'quran_reading_history_';

  String _getKey(QuranRiwaya riwaya) => '$_keyHistoryPrefix${riwaya.name}';

  /// Loads up to 5 history items, ordered with the most recent at index 0.
  Future<List<QuranHistoryItem>> loadHistory(QuranRiwaya riwaya) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_getKey(riwaya));
      if (jsonList == null || jsonList.isEmpty) {
        return const [];
      }
      final items = <QuranHistoryItem>[];
      for (final str in jsonList) {
        try {
          final Map<String, dynamic> map =
              json.decode(str) as Map<String, dynamic>;
          items.add(QuranHistoryItem.fromJson(map));
        } catch (e) {
          debugPrint('[QuranHistoryStorage] Error parsing item: $e');
        }
      }
      items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return items.take(5).toList();
    } catch (e) {
      debugPrint('[QuranHistoryStorage] loadHistory error: $e');
      return const [];
    }
  }

  /// Adds or updates a surah entry in history (FIFO queue capped at 5).
  ///
  /// If the user navigates across multiple pages within the same surah,
  /// the single entry for that surah is updated with the latest page visited.
  Future<void> saveHistoryItem({
    required QuranRiwaya riwaya,
    required int surahId,
    required String surahNameEn,
    required String surahNameAr,
    required int page,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await loadHistory(riwaya);

      // Remove any existing entry for this surahId so we update it
      final updatedList =
          current.where((item) => item.surahId != surahId).toList();

      // Prepend updated item at index 0
      updatedList.insert(
        0,
        QuranHistoryItem(
          surahId: surahId,
          surahNameEn: surahNameEn,
          surahNameAr: surahNameAr,
          page: page,
          updatedAt: DateTime.now(),
        ),
      );

      // Keep at most 5 items (FIFO queue)
      final finalItems = updatedList.take(5).toList();

      final jsonList =
          finalItems.map((item) => json.encode(item.toJson())).toList();
      await prefs.setStringList(_getKey(riwaya), jsonList);
    } catch (e) {
      debugPrint('[QuranHistoryStorage] saveHistoryItem error: $e');
    }
  }
}
