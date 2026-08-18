import 'dart:io';

import 'package:ahl_jannah/features/quran/data/datasources/quran_warsh_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression test for the app's real Warsh data path
/// (`WarshQuranDatabase._run` → `LazyDatabase.runSelect`).
///
/// LazyDatabase does NOT open itself when `runSelect` is called — it reads
/// its `late final _delegate` directly, so the first query on an unopened
/// database throws
/// `LateInitializationError: Field '_delegate @…' has not been initialized`.
/// This was exactly the crash when toggling Warsh inside the Quran reader.
/// These tests force the real lazy path (via [WarshQuranDatabase.withOpener])
/// and assert the query succeeds and maps rows correctly.
void main() {
  late WarshQuranDatabase database;

  setUp(() {
    final dbFile = File('assets/quran_warsh.db');
    if (!dbFile.existsSync()) {
      throw StateError(
        'assets/quran_warsh.db not found at ${dbFile.absolute.path}. '
        'Run scripts/build_warsh_db.py first, and run tests from the '
        'ahl_jannah project root.',
      );
    }
    database = WarshQuranDatabase.withOpener(() => NativeDatabase(dbFile));
  });

  tearDown(() async {
    await database.close();
  });

  test('first query on a fresh WarshQuranDatabase must not hit the '
      'uninitialized _delegate (late-init crash regression)', () async {
    final rows = await database.getAyahsByPage(1);
    expect(rows, isNotEmpty);
    expect(rows.first.page, 1);
    expect(rows.first.textAr.trim(), isNotEmpty);
  });

  test(
    'getAyahsBySurah returns contiguous, correctly numbered ayahs',
    () async {
      final rows = await database.getAyahsBySurah(1);
      expect(rows.length, 7);
      expect(rows.map((r) => r.number).toList(), [1, 2, 3, 4, 5, 6, 7]);
      expect(rows.every((r) => r.surahId == 1), isTrue);
    },
  );

  test('getAyahsByJuz returns rows only for that juz', () async {
    final rows = await database.getAyahsByJuz(1);
    expect(rows, isNotEmpty);
    expect(rows.every((r) => r.juz == 1), isTrue);
  });

  test('getSurahAyahCounts returns per-surah counts', () async {
    final counts = await database.getSurahAyahCounts();
    expect(counts.length, 114);
    expect(counts[1], 7);
    expect(counts[2], 285);
    final sum = counts.values.fold<int>(0, (a, b) => a + b);
    expect(sum, 6213);
  });
}
