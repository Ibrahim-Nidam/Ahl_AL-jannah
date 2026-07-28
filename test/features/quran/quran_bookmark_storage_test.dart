import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ahl_jannah/features/quran/data/services/quran_bookmark_storage.dart';
import 'package:ahl_jannah/features/quran/domain/entities/quran_bookmark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranBookmarkStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = QuranBookmarkStorage();
  });

  test('can load bookmarks initially as an empty mutable list', () async {
    final bookmarks = await storage.loadBookmarks();
    expect(bookmarks, isEmpty);
    
    final mockBookmark = QuranBookmark(
      id: 'test',
      type: QuranBookmarkType.page,
      surahId: 1,
      surahName: 'Test',
      page: 1,
      previewText: 'text',
      createdAt: DateTime.now(),
    );
    // Ensure we can add to the returned list without raising UnsupportedError
    expect(() => bookmarks.add(mockBookmark), returnsNormally);
  });

  test('can save and load page bookmarks successfully', () async {
    await storage.addPageBookmark(
      surahId: 1,
      surahName: 'Al-Fatiha',
      page: 1,
      previewText: 'Bismillah...',
    );

    final bookmarks = await storage.loadBookmarks();
    expect(bookmarks.length, 1);
    expect(bookmarks.first.surahName, 'Al-Fatiha');
    expect(bookmarks.first.isPageBookmark, true);
  });

  test('can save and load ayah bookmarks successfully', () async {
    await storage.addAyahBookmark(
      surahId: 2,
      surahName: 'Al-Baqarah',
      page: 2,
      ayahNumber: 5,
      previewText: 'Ayah text',
    );

    final bookmarks = await storage.loadBookmarks();
    expect(bookmarks.length, 1);
    expect(bookmarks.first.surahName, 'Al-Baqarah');
    expect(bookmarks.first.ayahNumber, 5);
    expect(bookmarks.first.isAyahBookmark, true);
  });

  test('can save, load and remove bookmarks successfully', () async {
    await storage.addPageBookmark(
      surahId: 1,
      surahName: 'Al-Fatiha',
      page: 1,
      previewText: 'Bismillah...',
    );

    final initial = await storage.loadBookmarks();
    expect(initial.length, 1);
    final id = initial.first.id;

    await storage.removeBookmark(id);

    final remaining = await storage.loadBookmarks();
    expect(remaining, isEmpty);
  });
}
