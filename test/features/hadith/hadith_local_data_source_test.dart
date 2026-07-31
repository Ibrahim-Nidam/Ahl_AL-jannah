import 'package:ahl_jannah/features/hadith/data/datasources/hadith_local_data_source.dart';
import 'package:ahl_jannah/features/hadith/domain/entities/hadith_entities.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The default [rootBundle] loader is used so this suite also guards the
  // real asset pipeline (assets must be declared in pubspec, e.g. the hadith
  // subfolders must be listed individually — directory entries do not recurse).
  final dataSource = HadithLocalDataSourceImpl();

  setUpAll(() async {
    // Ensure the asset bundle actually contains a hadith file; fail fast with
    // a clear message instead of a cryptic load error mid-suite.
    try {
      await rootBundle.loadString('assets/hadith/bukhari/001_revelation.json');
    } catch (e) {
      fail(
        'Hadith assets are not bundled for tests. Add the hadith subfolders '
        'under `assets:` in pubspec.yaml (individual folders, not the parent): $e',
      );
    }
  });

  group('HadithLocalDataSourceImpl', () {
    test('discovers the four bundled authors with correct counts', () async {
      final authors = await dataSource.getAuthors();

      expect(authors, hasLength(4));
      expect(authors.map((a) => a.id), [
        'bukhari',
        'muslim',
        'forty_nawawi',
        'forty_qudsi',
      ]);

      final bukhari = authors.firstWhere((a) => a.id == 'bukhari');
      expect(bukhari.bookCount, 97);
      expect(bukhari.hadithCount, 7277);
      expect(bukhari.titleEn, 'Sahih al-Bukhari');

      final muslim = authors.firstWhere((a) => a.id == 'muslim');
      expect(muslim.bookCount, 57);
      expect(muslim.hadithCount, 7459);

      final nawawi = authors.firstWhere((a) => a.id == 'forty_nawawi');
      expect(nawawi.bookCount, 1);
      expect(nawawi.hadithCount, 42);

      final qudsi = authors.firstWhere((a) => a.id == 'forty_qudsi');
      expect(qudsi.bookCount, 1);
      expect(qudsi.hadithCount, 40);
    });

    test('getBooks returns book metadata from the index', () async {
      final books = await dataSource.getBooks('bukhari');
      expect(books, hasLength(97));
      expect(books.first.id, '001_revelation');
      expect(books.first.titleEn, contains('Revelation'));
      expect(books.first.titleAr, contains('الوحى'));
      expect(books.first.count, 7);
    });

    test('book titles split into locale-aware English and Arabic halves', () async {
      final books = await dataSource.getBooks('bukhari');
      final revelation = books.firstWhere((b) => b.id == '001_revelation');
      expect(revelation.titleFor('en'), revelation.titleEn);
      expect(revelation.titleFor('ar'), revelation.titleAr);
      expect(revelation.titleFor('fr'), revelation.titleEn);
      // No Arabic script leaks into the English half.
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(revelation.titleEn), isFalse);
      // And the Arabic half is pure Arabic.
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(revelation.titleAr), isTrue);
    });

    test('searchHadiths finds matches across English, Arabic and titles', () async {
      final byEnglish = await dataSource.searchHadiths('narrated');
      expect(byEnglish, isNotEmpty);
      expect(byEnglish.first.item.english.toLowerCase(), contains('narrated'));

      final byArabic = await dataSource.searchHadiths('عُمَر');
      expect(byArabic, isNotEmpty);
      expect(byArabic.any((r) => r.item.arabic.contains('عُمَر')), isTrue);

      final byBookTitle = await dataSource.searchHadiths('revelation');
      expect(byBookTitle, isNotEmpty);
      expect(byBookTitle.any((r) => r.book.titleEn.toLowerCase() == '1 revelation'), isTrue);

      final empty = await dataSource.searchHadiths('   ');
      expect(empty, isEmpty);
    });

    test('getHadiths parses a book file (BOM handled) into ar + en', () async {
      final items = await dataSource.getHadiths('bukhari', '001_revelation');
      expect(items, hasLength(7));

      final first = items.first;
      expect(first.authorId, 'bukhari');
      expect(first.id, 1);
      expect(first.book, contains('Revelation'));
      expect(first.arabic, isNotEmpty);
      expect(first.english, isNotEmpty);
      expect(first.english, contains('Narrated'));

      // The file carries a UTF-8 BOM in the raw source; parsing must not fail.
      for (final item in items) {
        expect(item.arabic, isNotEmpty);
        expect(item.english, isNotEmpty);
      }
    });

    test('forty_nawawi single book parses 42 hadiths', () async {
      final books = await dataSource.getBooks('forty_nawawi');
      expect(books, hasLength(1));

      final items = await dataSource.getHadiths('forty_nawawi', books.first.id);
      expect(items, hasLength(42));
      expect(items.first.english, contains('narrated'));
      expect(items.first.arabic, contains('عُمَر'));
    });

    test('returns HadithItem-typed lists', () async {
      final items = await dataSource.getHadiths('muslim', '001_the_book_of_faith');
      expect(items, isNotEmpty);
      expect(items.first, isA<HadithItem>());
    });
  });
}
