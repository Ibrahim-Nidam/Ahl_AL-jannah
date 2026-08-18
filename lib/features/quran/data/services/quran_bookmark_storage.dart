import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../domain/entities/quran_bookmark.dart';

/// Bookmark storage is scoped per riwaya: Hafs and Warsh use different
/// SharedPreferences keys, so each riwaya keeps its own bookmarks and
/// "last reading position". The data is tiny (tens of bytes per entry), so
/// this adds no meaningful storage; it just avoids the ayah-number and
/// text mismatches between the two editions.
class QuranBookmarkStorage {
  /// Existing Hafs keys are reused unchanged, so bookmarks saved before
  /// per-riwaya storage existed keep working (they are Hafs bookmarks).
  String _bookmarksKey(QuranRiwaya riwaya) {
    return riwaya == QuranRiwaya.warsh
        ? '${AppConstants.keyQuranBookmarks}_warsh'
        : AppConstants.keyQuranBookmarks;
  }

  String _lastPositionKey(QuranRiwaya riwaya) {
    return riwaya == QuranRiwaya.warsh
        ? '${AppConstants.keyQuranLastPosition}_warsh'
        : AppConstants.keyQuranLastPosition;
  }

  Future<List<QuranBookmark>> loadBookmarks(QuranRiwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_bookmarksKey(riwaya));
    if (raw == null || raw.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(QuranBookmark.fromJson)
          .toList()
        ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<void> addPageBookmark({
    required QuranRiwaya riwaya,
    required int surahId,
    required String surahName,
    required int page,
    required String previewText,
    int? ayahNumber,
    String? readingMode,
  }) async {
    final bookmark = QuranBookmark(
      id: 'page-${DateTime.now().microsecondsSinceEpoch}',
      type: QuranBookmarkType.page,
      surahId: surahId,
      surahName: surahName,
      page: page,
      ayahNumber: ayahNumber,
      previewText: previewText,
      createdAt: DateTime.now(),
      readingMode: readingMode,
    );
    await _saveBookmark(riwaya, bookmark);
  }

  Future<void> addAyahBookmark({
    required QuranRiwaya riwaya,
    required int surahId,
    required String surahName,
    required int page,
    required int ayahNumber,
    required String previewText,
    String? readingMode,
  }) async {
    final bookmark = QuranBookmark(
      id: 'ayah-${DateTime.now().microsecondsSinceEpoch}',
      type: QuranBookmarkType.ayah,
      surahId: surahId,
      surahName: surahName,
      page: page,
      ayahNumber: ayahNumber,
      previewText: previewText,
      createdAt: DateTime.now(),
      readingMode: readingMode,
    );
    await _saveBookmark(riwaya, bookmark);
  }

  Future<void> removeBookmark(QuranRiwaya riwaya, String id) async {
    final bookmarks = await loadBookmarks(riwaya);
    bookmarks.removeWhere((bookmark) => bookmark.id == id);
    await _persist(riwaya, bookmarks);
  }

  Future<void> _saveBookmark(QuranRiwaya riwaya, QuranBookmark bookmark) async {
    final bookmarks = await loadBookmarks(riwaya);
    bookmarks.add(bookmark);
    await _persist(riwaya, bookmarks);
  }

  Future<void> _persist(
    QuranRiwaya riwaya,
    List<QuranBookmark> bookmarks,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _bookmarksKey(riwaya),
      jsonEncode(bookmarks.map((bookmark) => bookmark.toJson()).toList()),
    );
  }

  // ── Automatic "last reading position" ──
  //
  // Stored entirely separately from the user-visible bookmarks list above
  // (a distinct SharedPreferences key, a single entry, always overwritten)
  // so it never appears in the Bookmarks page and never risks corrupting
  // or being confused with bookmarks the user explicitly created.

  Future<QuranBookmark?> getLastPosition(QuranRiwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastPositionKey(riwaya));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return QuranBookmark.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastPosition({
    required QuranRiwaya riwaya,
    required int surahId,
    required String surahName,
    required int page,
    required String previewText,
    int? ayahNumber,
    String? readingMode,
    double? scrollOffset,
  }) async {
    final position = QuranBookmark(
      id: 'last_position',
      type: QuranBookmarkType.page,
      surahId: surahId,
      surahName: surahName,
      page: page,
      ayahNumber: ayahNumber,
      previewText: previewText,
      createdAt: DateTime.now(),
      readingMode: readingMode,
      scrollOffset: scrollOffset,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastPositionKey(riwaya),
      jsonEncode(position.toJson()),
    );
  }

  Future<void> clearLastPosition(QuranRiwaya riwaya) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPositionKey(riwaya));
  }
}
