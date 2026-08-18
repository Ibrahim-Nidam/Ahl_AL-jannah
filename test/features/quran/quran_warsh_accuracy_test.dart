import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// Whole-corpus accuracy audit for the bundled Warsh Quran database
/// (`assets/quran_warsh.db`).
///
/// The database is built from the QPC (QuranPedia) Warsh bundle
/// (`test/fixtures/warsh/quran.json`, 6,213 ayahs). This suite verifies:
///
///   1. Import fidelity — every single ayah in the bundled database is
///      character-for-character identical to the source bundle (after
///      removing the basmala that the build step embeds into each surah's
///      ayah 1 to mirror the Hafs database layout).
///   2. Structural integrity — 604 pages (1..604) all present, per-surah
///      ayah counts match the source, ayah numbering is contiguous, juz is
///      always 1..30 (the 26 source rows that shipped juz=0 must be fixed),
///      hizb is always 1..60, and no row has empty text.
///
/// Any mismatch is reported with the surah:ayah context so failures are
/// immediately actionable.
void main() {
  // Exact basmala as stored in assets/quran.db (surah 1:1), written as escape
  // sequences so the combining-mark order (shadda before fatha) is explicit:
  //   بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ
  const basmala = '\u0628\u0650\u0633\u0652\u0645\u0650 '
      '\u0671\u0644\u0644\u0651\u064e\u0647\u0650 '
      '\u0671\u0644\u0631\u0651\u064e\u062d\u0652\u0645\u064e\u0640\u0670\u0646\u0650 '
      '\u0671\u0644\u0631\u0651\u064e\u062d\u0650\u064a\u0645\u0650';

  late Database db;
  late List<Row> rows;
  late Map<String, dynamic> source;

  setUpAll(() {
    final dbFile = File('assets/quran_warsh.db');
    if (!dbFile.existsSync()) {
      throw StateError(
        'assets/quran_warsh.db not found at ${dbFile.absolute.path}. '
        'Run scripts/build_warsh_db.py first, and run tests from the '
        'ahl_jannah project root.',
      );
    }
    final sourceFile = File('test/fixtures/warsh/quran.json');
    if (!sourceFile.existsSync()) {
      throw StateError(
        'test/fixtures/warsh/quran.json not found — the QPC Warsh source '
        'bundle is required for the fidelity check.',
      );
    }
    db = sqlite3.open('assets/quran_warsh.db');
    source = jsonDecode(sourceFile.readAsStringSync()) as Map<String, dynamic>;
  });

  tearDownAll(() {
    db.dispose();
  });

  test('Warsh database is a faithful, structurally sound copy of the source', () async {
    // ── Load all rows once ──
    rows = db.select(
      'SELECT id, surah_id, number, text_ar, juz, page, hizb '
      'FROM warsh_ayahs',
    ).toList();
    final byKey = <String, Row>{};
    for (final row in rows) {
      byKey['${row['surah_id']}-${row['number']}'] = row;
    }

    final sourceAyat = (source['ayat'] as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();
    final sourceTotal = source['total'] as int;

    // ── Accumulators ──
    final mismatches = <String>[];
    final perSurahCount = <int, int>{};
    final pagesPresent = <int>{};
    final juzValues = <int>{};
    final hizbValues = <int>{};
    var fidelityChecks = 0;
    var basmalaChecked = 0;
    var juzRepaired = 0;

    // ── 1. Import fidelity ──
    for (final item in sourceAyat) {
      final surah = item['surah'] as int;
      final number = item['ayah'] as int;
      final srcText = item['text'] as String;
      final srcPage = item['page'] as int;
      final srcJuz = item['juz'] as int;

      final ctx = '$surah:$number';
      final dbRow = byKey['$surah-$number'];
      if (dbRow == null) {
        mismatches.add('$ctx: missing from bundled database');
        continue;
      }

      final dbText = dbRow['text_ar'] as String;
      final dbPage = dbRow['page'] as int;
      final dbJuz = dbRow['juz'] as int;

      final embedBasmala = surah != 9 && number == 1;
      final expected = embedBasmala ? '$basmala $srcText' : srcText;

      if (embedBasmala) {
        basmalaChecked++;
        if (!dbText.startsWith(basmala)) {
          mismatches.add(
            '$ctx: ayah 1 is missing the embedded basmala '
            '"{${dbText.substring(0, dbText.length > 30 ? 30 : dbText.length)}}…"',
          );
        }
      }

      if (dbText != expected) {
        mismatches.add(
          '$ctx: text differs from source\n'
          '      source: $srcText\n'
          '      db    : $dbText',
        );
      }
      if (dbPage != srcPage) {
        mismatches.add('$ctx: page differs (db=$dbPage, source=$srcPage)');
      }

      // juz must be valid even where the source shipped 0.
      if (srcJuz == 0) {
        juzRepaired++;
        if (dbJuz < 1 || dbJuz > 30) {
          mismatches.add('$ctx: juz still invalid after repair (juz=$dbJuz)');
        }
      } else if (dbJuz != srcJuz) {
        mismatches.add('$ctx: juz differs (db=$dbJuz, source=$srcJuz)');
      }

      fidelityChecks++;
      perSurahCount[surah] = (perSurahCount[surah] ?? 0) + 1;
      pagesPresent.add(dbPage);
      juzValues.add(dbJuz);
      hizbValues.add(dbRow['hizb'] as int);
    }

    // ── 2. Structural integrity ──
    final structural = <String>[];

    // Total: source rows (basmala is embedded in-place into the 113 ayah-1
    // rows, not inserted as separate rows, mirroring the Hafs DB layout).
    final expectedTotal = sourceTotal;
    if (rows.length != expectedTotal) {
      structural.add(
        'row count = ${rows.length}, expected $expectedTotal '
        '(source $sourceTotal, basmala embedded in-place)',
      );
    }

    // Every page 1..604 must have at least one ayah.
    for (var p = 1; p <= 604; p++) {
      if (!pagesPresent.contains(p)) {
        structural.add('missing page $p');
      }
    }

    // Per-surah counts must match the source bundle.
    final sourcePerSurah = <int, int>{};
    for (final item in sourceAyat) {
      final surah = item['surah'] as int;
      sourcePerSurah[surah] = (sourcePerSurah[surah] ?? 0) + 1;
    }
    if (sourcePerSurah.length != 114) {
      structural.add('source has ${sourcePerSurah.length} surahs, expected 114');
    }
    for (var s = 1; s <= 114; s++) {
      final expected = sourcePerSurah[s] ?? 0;
      final actual = perSurahCount[s] ?? 0;
      if (actual != expected) {
        structural.add(
          'surah $s count = $actual, source = $expected',
        );
      }
    }

    // Ayah numbering must be contiguous within every surah.
    for (final entry in perSurahCount.entries) {
      for (var n = 1; n <= entry.value; n++) {
        if (!byKey.containsKey('${entry.key}-$n')) {
          structural.add(
            'surah ${entry.key}: ayah $n missing (count=${entry.value})',
          );
          break;
        }
      }
    }

    // Global bounds.
    if (juzValues.any((j) => j < 1 || j > 30)) {
      structural.add('juz outside 1..30: ${juzValues.toList()..sort()}');
    }
    if (hizbValues.any((h) => h < 1 || h > 60)) {
      structural.add('hizb outside 1..60');
    }
    for (final row in rows) {
      final text = row['text_ar'] as String;
      if (text.trim().isEmpty) {
        structural.add('empty text at ${row['surah_id']}:${row['number']}');
      }
    }

    // ── 3. Report ──
    final buffer = StringBuffer()
      ..writeln('══════════════════════════════════════════════════════')
      ..writeln('  WARSH DATABASE — IMPORT ACCURACY AUDIT')
      ..writeln('══════════════════════════════════════════════════════')
      ..writeln('Source bundle   : ${source['source']} (riwaya=${source['riwaya']})')
      ..writeln('Source total    : $sourceTotal')
      ..writeln('Bundled rows    : ${rows.length} '
          '(expected $expectedTotal = source; basmala embedded in-place)')
      ..writeln('Fidelity checks : $fidelityChecks')
      ..writeln('Basmala checked : $basmalaChecked')
      ..writeln('juz=0 repaired  : $juzRepaired')
      ..writeln('Pages (1..604)  : ${pagesPresent.length}/604 present')
      ..writeln('Text mismatches : ${mismatches.length}')
      ..writeln('Structural issues: ${structural.length}')
      ..writeln('──────────────────────────────────────────────────────');

    if (mismatches.isNotEmpty) {
      buffer.writeln('First text/fidelity mismatches:');
      for (final m in mismatches.take(40)) {
        buffer.writeln('  • $m');
      }
    }
    if (structural.isNotEmpty) {
      buffer.writeln('Structural issues:');
      for (final s in structural.take(40)) {
        buffer.writeln('  • $s');
      }
    }
    buffer.writeln('══════════════════════════════════════════════════════');
    // ignore: avoid_print
    print(buffer.toString());

    expect(
      mismatches,
      isEmpty,
      reason: '${mismatches.length} Warsh import mismatches:\n'
          '${mismatches.take(20).join('\n')}',
    );
    expect(
      structural,
      isEmpty,
      reason: '${structural.length} Warsh structural issues:\n'
          '${structural.take(20).join('\n')}',
    );
  });
}