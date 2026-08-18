import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:ahl_jannah/features/quran/data/datasources/quran_database.dart';

/// Hafs ('an Asim) vs Warsh ('an Nafi') whole-Quran text comparison.
///
/// Both riwayat are bundled in the app (Hafs: `assets/quran.db`, Warsh:
/// `assets/quran_warsh.db`). This suite normalizes every ayah on both sides
/// down to its base-letter skeleton and, for every surah, lines up the two
/// editions by ayah number (Warsh splits/merges some ayahs, so the counts
/// differ in ~57 surahs). For each ayah where the skeletons are not
/// identical it writes a human-readable report — both raw texts plus the
/// normalized skeletons with every differing character wrapped in 【】 — to
/// `build/reports/warsh_vs_hafs_diff.txt` and prints a summary.
///
/// The test only asserts structural sanity (all 114 surahs processed, all
/// rows accounted for, the report file written); the differences themselves
/// are the deliverable, not a failure condition.
void main() {
  late QuranDatabase hafs;
  late Database warsh;

  late List<({int surah, int number, String text})> hafsAyahs;
  late List<({int surah, int number, String text})> warshAyahs;

  setUpAll(() {
    final hafsFile = File('assets/quran.db');
    if (!hafsFile.existsSync()) {
      throw StateError('assets/quran.db not found. Run from the ahl_jannah project root.');
    }
    final warshFile = File('assets/quran_warsh.db');
    if (!warshFile.existsSync()) {
      throw StateError(
        'assets/quran_warsh.db not found. Run scripts/build_warsh_db.py first.',
      );
    }
    hafs = QuranDatabase.forTesting(NativeDatabase(hafsFile));
    warsh = sqlite3.open('assets/quran_warsh.db');
  });

  tearDownAll(() async {
    await hafs.close();
    warsh.dispose();
  });

  test('produces a Hafs-vs-Warsh difference report for every ayah', () async {
    final hafsRows = await hafs.select(hafs.ayahs).get();
    hafsAyahs = hafsRows
        .map((a) => (surah: a.surahId, number: a.number, text: a.textAr))
        .toList();
    final warshRows = warsh.select(
      'SELECT surah_id, number, text_ar FROM warsh_ayahs ORDER BY surah_id, number',
    ).toList();
    warshAyahs = warshRows
        .map(
          (r) => (
            surah: r['surah_id'] as int,
            number: r['number'] as int,
            text: r['text_ar'] as String,
          ),
        )
        .toList();

    // Index both editions by (surah, number).
    final hafsByKey = <String, String>{};
    for (final a in hafsAyahs) {
      hafsByKey['${a.surah}-${a.number}'] = a.text;
    }
    final warshByKey = <String, String>{};
    for (final a in warshAyahs) {
      warshByKey['${a.surah}-${a.number}'] = a.text;
    }

    final identical = <String>[];
    final differing = <String>[];
    final warshOnly = <String>[];
    final hafsOnly = <String>[];
    final surahCounts = <int, ({int hafs, int warsh})>{};

    // Use the union of ayah keys for surahs present in either edition.
    final keys = <String>{...hafsByKey.keys, ...warshByKey.keys};
    for (final key in keys) {
      final parts = key.split('-');
      final surah = int.parse(parts[0]);
      final number = int.parse(parts[1]);
      final h = hafsByKey[key];
      final w = warshByKey[key];

      final prev = surahCounts[surah] ?? (hafs: 0, warsh: 0);
      surahCounts[surah] = (
        hafs: prev.hafs + (h != null ? 1 : 0),
        warsh: prev.warsh + (w != null ? 1 : 0),
      );

      if (h == null) {
        warshOnly.add('$surah:$number');
        continue;
      }
      if (w == null) {
        hafsOnly.add('$surah:$number');
        continue;
      }

      final hNorm = normalizeForComparison(h);
      final wNorm = normalizeForComparison(w);
      if (hNorm == wNorm) {
        identical.add(key);
      } else {
        differing.add(key);
      }
    }

    expect(surahCounts.length, 114, reason: 'both editions must cover all 114 surahs');

    final allCompared = identical.length + differing.length;
    expect(allCompared + warshOnly.length + hafsOnly.length, keys.length,
        reason: 'every ayah key must be accounted for');

    // ── Write the report ──
    final reportDir = Directory('build/reports');
    reportDir.createSync(recursive: true);
    final reportFile = File('${reportDir.path}/warsh_vs_hafs_diff.txt');
    final buffer = StringBuffer();

    buffer.writeln('══════════════════════════════════════════════════════════');
    buffer.writeln('  HAFS (\'an Asim) vs WARSH (\'an Nafi\') — TEXT COMPARISON');
    buffer.writeln('══════════════════════════════════════════════════════════');
    buffer.writeln('Compared ayahs           : $allCompared');
    buffer.writeln('Identical (normalized)   : ${identical.length} '
        '(${allCompared == 0 ? 0 : (identical.length * 100 / allCompared).toStringAsFixed(1)}%)');
    buffer.writeln('Different (normalized)   : ${differing.length}');
    buffer.writeln('Only in Warsh            : ${warshOnly.length}');
    buffer.writeln('Only in Hafs             : ${hafsOnly.length}');
    buffer.writeln('Surahs with any diff     : ${_countDifferingSurahs(differing)}');
    buffer.writeln('');
    buffer.writeln('Differences are shown on the *normalized* skeleton '
        '(diacritics and Warsh small-alif marks removed, alef variants/ة/ى '
        'normalized), with every differing character wrapped in 【】.');
    buffer.writeln('══════════════════════════════════════════════════════════');

    // ── Per-surah differing ayah numbers ──
    final bySurah = <int, List<int>>{};
    for (final key in differing) {
      final parts = key.split('-');
      final surah = int.parse(parts[0]);
      bySurah.putIfAbsent(surah, () => []).add(int.parse(parts[1]));
    }
    if (bySurah.isEmpty) {
      buffer.writeln('No normalized differences found — both editions share the '
          'same base-letter text everywhere.');
    } else {
      buffer.writeln('Surahs whose ayahs differ, with ayah numbers:');
      final surahList = bySurah.keys.toList()..sort();
      for (final s in surahList) {
        final counts = surahCounts[s]!;
        buffer.writeln('  Surah $s (Hafs ${counts.hafs} ayahs, Warsh ${counts.warsh} ayahs): '
            '${bySurah[s]!.join(', ')}');
      }
    }

    // ── Extra / missing ayahs ──
    if (warshOnly.isNotEmpty || hafsOnly.isNotEmpty) {
      buffer.writeln('──────────────────────────────────────────────────────────────');
      buffer.writeln('Ayahs present in only one edition:');
      if (warshOnly.isNotEmpty) {
        buffer.writeln('  Only in Warsh (${warshOnly.length}):');
        for (final key in warshOnly) {
          buffer.writeln('    $key  →  ${warshByKey[key]}');
        }
      }
      if (hafsOnly.isNotEmpty) {
        buffer.writeln('  Only in Hafs (${hafsOnly.length}):');
        for (final key in hafsOnly) {
          buffer.writeln('    $key  →  ${hafsByKey[key]}');
        }
      }
    }

    // ── Detailed character-level diffs ──
    if (differing.isNotEmpty) {
      buffer.writeln('──────────────────────────────────────────────────────────────');
      buffer.writeln('DETAILED DIFFERENCES (${differing.length} ayahs)');
      buffer.writeln('──────────────────────────────────────────────────────────────');
      final sorted = List<String>.from(differing)
        ..sort((a, b) {
          final pa = a.split('-').map(int.parse).toList();
          final pb = b.split('-').map(int.parse).toList();
          return pa[0] != pb[0] ? pa[0] - pb[0] : pa[1] - pb[1];
        });
      for (final key in sorted) {
        final h = hafsByKey[key]!;
        final w = warshByKey[key]!;
        final hNorm = normalizeForComparison(h);
        final wNorm = normalizeForComparison(w);
        final (a: hMarked, b: wMarked) = _diffHighlight(hNorm, wNorm);
        buffer.writeln('');
        buffer.writeln('[$key]');
        buffer.writeln('  Hafs  skeleton : $hMarked');
        buffer.writeln('  Warsh skeleton : $wMarked');
        buffer.writeln('  Hafs  raw      : $h');
        buffer.writeln('  Warsh raw      : $w');
      }
    }

    buffer.writeln('');
    buffer.writeln('══════════════════════════════════════════════════════════');
    reportFile.writeAsStringSync(buffer.toString());

    // ── Console summary ──
    // ignore: avoid_print
    print(buffer.toString().split('\n').take(24).join('\n'));

    expect(reportFile.existsSync(), isTrue, reason: 'report must be written');
    expect(identical.length + differing.length, greaterThan(6000),
        reason: 'both editions must have been compared across the whole Quran');
    expect(warshAyahs.length + hafsOnly.length, keys.length,
        reason: 'warsh rows + hafs-only ayahs must equal the key union');
  });
}

// ──────────────────────────────────────────────────────────────────────────
// Normalization + diff helpers (independent of the app's own text handling).
// ──────────────────────────────────────────────────────────────────────────

final RegExp _markRe = RegExp(
  '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC'
  '\u06DF-\u06E8\u06EA-\u06ED\u0640]',
);

const Map<int, int> _alefNormalization = {
  0x0671: 0x0627, // ٱ wasla → ا
  0x0622: 0x0627, // آ → ا
  0x0623: 0x0627, // أ → ا
  0x0625: 0x0627, // إ → ا
  0x0629: 0x0647, // ة → ه
  0x0649: 0x064A, // ى → ي
};

String normalizeForComparison(String text) {
  final stripped = text.replaceAll(_markRe, '');
  final sb = StringBuffer();
  for (final rune in stripped.runes) {
    sb.writeCharCode(_alefNormalization[rune] ?? rune);
  }
  return sb.toString();
}

int _countDifferingSurahs(List<String> differing) {
  return differing.map((k) => int.parse(k.split('-').first)).toSet().length;
}

/// Character-level diff via LCS on the normalized skeletons. Returns two
/// strings where characters present in only one side are wrapped in 【】.
({String a, String b}) _diffHighlight(String a, String b) {
  final n = a.runes.length;
  final m = b.runes.length;

  // Cap the DP for very long ayahs (n*m beyond ~400k cells).
  if (n * m > 400000 || n == 0 || m == 0) {
    return (
      a: _markAll(a),
      b: _markAll(b),
    );
  }

  final ar = a.runes.toList();
  final br = b.runes.toList();

  final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      dp[i][j] = ar[i] == br[j]
          ? dp[i + 1][j + 1] + 1
          : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
    }
  }

  final sa = StringBuffer();
  final sb = StringBuffer();
  var i = 0;
  var j = 0;
  while (i < n && j < m) {
    if (ar[i] == br[j]) {
      sa.writeCharCode(ar[i]);
      sb.writeCharCode(br[j]);
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      sa.write('【${String.fromCharCode(ar[i])}】');
      i++;
    } else {
      sb.write('【${String.fromCharCode(br[j])}】');
      j++;
    }
  }
  while (i < n) {
    sa.write('【${String.fromCharCode(ar[i])}】');
    i++;
  }
  while (j < m) {
    sb.write('【${String.fromCharCode(br[j])}】');
    j++;
  }
  return (a: sa.toString(), b: sb.toString());
}

String _markAll(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    sb.write('【${String.fromCharCode(r)}】');
  }
  return sb.toString();
}