import 'package:ahl_jannah/features/quran/data/services/quran_bookmark_storage.dart';
import 'package:ahl_jannah/features/quran/domain/entities/quran_bookmark.dart';
import 'package:ahl_jannah/features/settings/domain/entities/settings_entities.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranBookmarkStorage storage;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    storage = QuranBookmarkStorage();
  });

  test('can load bookmarks initially as an empty mutable list', () async {
    final bookmarks = await storage.loadBookmarks(QuranRiwaya.hafsAnAsim);
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
      riwaya: QuranRiwaya.hafsAnAsim,
      surahId: 1,
      surahName: 'Al-Fatiha',
      page: 1,
      previewText: 'Bismillah...',
    );

    final bookmarks = await storage.loadBookmarks(QuranRiwaya.hafsAnAsim);
    expect(bookmarks.length, 1);
    expect(bookmarks.first.surahName, 'Al-Fatiha');
    expect(bookmarks.first.isPageBookmark, true);
  });

  test('can save and load ayah bookmarks successfully', () async {
    await storage.addAyahBookmark(
      riwaya: QuranRiwaya.hafsAnAsim,
      surahId: 2,
      surahName: 'Al-Baqarah',
      page: 2,
      ayahNumber: 5,
      previewText: 'Ayah text',
    );

    final bookmarks = await storage.loadBookmarks(QuranRiwaya.hafsAnAsim);
    expect(bookmarks.length, 1);
    expect(bookmarks.first.surahName, 'Al-Baqarah');
    expect(bookmarks.first.ayahNumber, 5);
    expect(bookmarks.first.isAyahBookmark, true);
  });

  test('can save, load and remove bookmarks successfully', () async {
    await storage.addPageBookmark(
      riwaya: QuranRiwaya.hafsAnAsim,
      surahId: 1,
      surahName: 'Al-Fatiha',
      page: 1,
      previewText: 'Bismillah...',
    );

    final initial = await storage.loadBookmarks(QuranRiwaya.hafsAnAsim);
    expect(initial.length, 1);
    final id = initial.first.id;

    await storage.removeBookmark(QuranRiwaya.hafsAnAsim, id);

    final remaining = await storage.loadBookmarks(QuranRiwaya.hafsAnAsim);
    expect(remaining, isEmpty);
  });

  test('Hafs and Warsh bookmarks are stored independently', () async {
    await storage.addPageBookmark(
      riwaya: QuranRiwaya.hafsAnAsim,
      surahId: 1,
      surahName: 'Al-Fatiha',
      page: 1,
      previewText: 'Hafs page 1',
    );
    await storage.addAyahBookmark(
      riwaya: QuranRiwaya.warsh,
      surahId: 2,
      surahName: 'Al-Baqarah',
      page: 2,
      ayahNumber: 5,
      previewText: 'Warsh 2:5',
    );

    final hafs = await storage.loadBookmarks(QuranRiwaya.hafsAnAsim);
    final warsh = await storage.loadBookmarks(QuranRiwaya.warsh);
    expect(hafs.length, 1);
    expect(hafs.single.isPageBookmark, true);
    expect(warsh.length, 1);
    expect(warsh.single.isAyahBookmark, true);
    expect(warsh.single.ayahNumber, 5);

    // Removing from one riwaya must not touch the other.
    await storage.removeBookmark(QuranRiwaya.hafsAnAsim, hafs.single.id);
    expect(await storage.loadBookmarks(QuranRiwaya.hafsAnAsim), isEmpty);
    expect((await storage.loadBookmarks(QuranRiwaya.warsh)).length, 1);
  });

  test('last position is stored independently per riwaya', () async {
    await storage.saveLastPosition(
      riwaya: QuranRiwaya.hafsAnAsim,
      surahId: 1,
      surahName: 'Al-Fatiha',
      page: 1,
      previewText: 'Hafs pos',
    );
    await storage.saveLastPosition(
      riwaya: QuranRiwaya.warsh,
      surahId: 18,
      surahName: 'Al-Kahf',
      page: 293,
      previewText: 'Warsh pos',
    );

    final hafs = await storage.getLastPosition(QuranRiwaya.hafsAnAsim);
    final warsh = await storage.getLastPosition(QuranRiwaya.warsh);
    expect(hafs?.page, 1);
    expect(warsh?.page, 293);

    await storage.clearLastPosition(QuranRiwaya.warsh);
    expect(await storage.getLastPosition(QuranRiwaya.warsh), isNull);
    expect((await storage.getLastPosition(QuranRiwaya.hafsAnAsim))?.page, 1);
  });
}
