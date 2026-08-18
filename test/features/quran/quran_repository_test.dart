import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:ahl_jannah/features/quran/data/datasources/quran_database.dart';
import 'package:ahl_jannah/features/quran/data/datasources/quran_local_data_source.dart';
import 'package:ahl_jannah/features/quran/data/datasources/quran_warsh_data_source.dart';
import 'package:ahl_jannah/features/quran/data/repositories/quran_repository_impl.dart';
import 'package:ahl_jannah/features/quran/domain/entities/quran_entities.dart';
import 'package:sqlite3/sqlite3.dart' show AllowedArgumentCount;

class _FakeWarshDataSource implements WarshQuranDataSource {
  @override
  Future<List<AyahEntity>> getAyahsByPage(int page) async => [];

  @override
  Future<List<AyahEntity>> getAyahsBySurah(int surahId) async => [];

  @override
  Future<List<AyahEntity>> getAyahsByJuz(int juz) async => [];

  @override
  Future<Map<int, int>> getSurahAyahCounts() async => {};
}

void main() {
  late QuranDatabase database;
  late QuranLocalDataSource dataSource;
  late QuranRepositoryImpl repository;

  setUp(() {
    // Initialize in-memory database for testing
    database = QuranDatabase.forTesting(
      NativeDatabase.memory(
        setup: (db) {
          db.createFunction(
            functionName: 'remove_diacritics',
            argumentCount: const AllowedArgumentCount(1),
            function: (args) {
              final text = args.first as String?;
              if (text == null) return null;
              var normalized = text.replaceAll(
                RegExp(
                  r'[\u064B-\u0652\u0670\u0640\u0653-\u0655\u06DF-\u06E8\u06EA-\u06EC]',
                ),
                '',
              );
              normalized = normalized.replaceAll(RegExp(r'[أإآٱ]'), 'ا');
              normalized = normalized.replaceAll('ة', 'ه');
              return normalized;
            },
          );
        },
      ),
    );
    dataSource = QuranLocalDataSourceImpl(database);
    repository = QuranRepositoryImpl(dataSource, _FakeWarshDataSource());
  });

  tearDown(() async {
    await database.close();
  });

  test('can insert and retrieve surahs and ayahs', () async {
    // Insert test Surah
    await database
        .into(database.surahs)
        .insert(
          SurahsCompanion.insert(
            id: const Value(1),
            nameAr: 'الفاتحة',
            nameEn: 'Al-Faatiha',
            revelation: 'meccan',
            ayahCount: 7,
          ),
        );

    // Insert test Ayah
    await database
        .into(database.ayahs)
        .insert(
          AyahsCompanion.insert(
            id: const Value(1),
            surahId: 1,
            number: 1,
            textAr: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
            translationEn: const Value('In the name of Allah...'),
            translationFr: const Value('Au nom d\'Allah...'),
            juz: 1,
            page: 1,
            hizb: 1,
          ),
        );

    final surahs = await repository.getSurahs();
    expect(surahs.length, 1);
    expect(surahs.first.nameEn, 'Al-Faatiha');

    final ayahs = await repository.getAyahsBySurah(1);
    expect(ayahs.length, 1);
    expect(ayahs.first.textAr, 'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ');
  });

  test('searching Quran matches text and translations', () async {
    // Insert test Surah
    await database
        .into(database.surahs)
        .insert(
          SurahsCompanion.insert(
            id: const Value(2),
            nameAr: 'البقرة',
            nameEn: 'Al-Baqara',
            revelation: 'medinan',
            ayahCount: 286,
          ),
        );

    // Insert test Ayahs
    await database
        .into(database.ayahs)
        .insert(
          AyahsCompanion.insert(
            id: const Value(2),
            surahId: 2,
            number: 1,
            textAr: 'الم',
            translationEn: const Value('Alif, Lam, Meem.'),
            translationFr: const Value('Alif, Lam, Meem.'),
            juz: 1,
            page: 2,
            hizb: 1,
          ),
        );

    await database
        .into(database.ayahs)
        .insert(
          AyahsCompanion.insert(
            id: const Value(3),
            surahId: 2,
            number: 255,
            textAr: 'اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ',
            translationEn: const Value(
              'Allah - there is no deity except Him, the Ever-Living, the Sustainer of all existence.',
            ),
            translationFr: const Value(
              'Allah! Point de divinité à part Lui, le Vivant, Celui qui subsiste par lui-même.',
            ),
            juz: 3,
            page: 42,
            hizb: 5,
          ),
        );

    // Search Arabic text with diacritics
    final arabicResults = await repository.searchQuran('الْحَيُّ');
    expect(arabicResults.length, 1);
    expect(arabicResults.first.number, 255);

    // Search Arabic text WITHOUT diacritics and normalized letters
    final arabicNoTashkilResults = await repository.searchQuran(
      'الله لا اله الا هو الحي القيوم',
    );
    expect(arabicNoTashkilResults.length, 1);
    expect(arabicNoTashkilResults.first.number, 255);

    // Search English translation
    final englishResults = await repository.searchQuran('Sustainer');
    expect(englishResults.length, 1);
    expect(englishResults.first.number, 255);

    // Search French translation
    final frenchResults = await repository.searchQuran('divinité');
    expect(frenchResults.length, 1);
    expect(frenchResults.first.number, 255);
  });
}
