import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/quran_bookmark.dart';

class QuranBookmarkStorage {
  Future<List<QuranBookmark>> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyQuranBookmarks);
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
    await _saveBookmark(bookmark);
  }

  Future<void> addAyahBookmark({
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
    await _saveBookmark(bookmark);
  }

  Future<void> removeBookmark(String id) async {
    final bookmarks = await loadBookmarks();
    bookmarks.removeWhere((bookmark) => bookmark.id == id);
    await _persist(bookmarks);
  }

  Future<void> _saveBookmark(QuranBookmark bookmark) async {
    final bookmarks = await loadBookmarks();
    bookmarks.add(bookmark);
    await _persist(bookmarks);
  }

  Future<void> _persist(List<QuranBookmark> bookmarks) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.keyQuranBookmarks,
      jsonEncode(bookmarks.map((bookmark) => bookmark.toJson()).toList()),
    );
  }

  // ── Automatic "last reading position" ──
  //
  // Stored entirely separately from the user-visible bookmarks list above
  // (a distinct SharedPreferences key, a single entry, always overwritten)
  // so it never appears in the Bookmarks page and never risks corrupting
  // or being confused with bookmarks the user explicitly created.

  Future<QuranBookmark?> getLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.keyQuranLastPosition);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return QuranBookmark.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastPosition({
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
      AppConstants.keyQuranLastPosition,
      jsonEncode(position.toJson()),
    );
  }

  Future<void> clearLastPosition() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyQuranLastPosition);
  }
}