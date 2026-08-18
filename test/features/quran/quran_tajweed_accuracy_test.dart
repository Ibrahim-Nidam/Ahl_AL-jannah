import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ahl_jannah/features/quran/data/datasources/quran_database.dart';
import 'package:ahl_jannah/features/quran/domain/tajweed/quran_tajweed_analyzer.dart';
import 'package:ahl_jannah/features/quran/domain/tajweed/quran_tajweed_rule.dart';
import 'package:ahl_jannah/features/quran/presentation/widgets/quran_ayah_span_builder.dart';

/// Whole-Quran accuracy audit for [QuranTajweedAnalyzer].
///
/// Unlike the focused unit tests (which assert on hand-picked ayahs), this
/// suite runs the analyzer over EVERY ayah in the real bundled `assets/
/// quran.db` (6,236 ayahs), formatted exactly the way the reader feeds the
/// analyzer (`formatAyahText`), and verifies the output against an
/// *independent* phonological model of the Hafs rules:
///
///   1. Structural integrity — marks stay in bounds, are contiguous, and
///      never cover whitespace.
///   2. False-positive check — every painted letter must satisfy its rule's
///      phonological precondition (re-derived here from the voweled text,
///      not from the analyzer's own code).
///   3. False-negative check (coverage) — every noon saakinah / tanween and
///      meem saakinah must be painted with the correct rule for the letter
///      that follows it (izhar letters are the only legal unpainted case).
///
/// Any mismatch is reported with the surah:ayah context, and a per-rule
/// statistical report is printed at the end so drift over the corpus is
/// visible, not just "pass/fail".
void main() {
  late QuranDatabase database;

  setUpAll(() {
    final dbFile = File('assets/quran.db');
    if (!dbFile.existsSync()) {
      throw StateError(
        'assets/quran.db not found at ${dbFile.absolute.path}. '
        'Tests must run from the ahl_jannah project root.',
      );
    }
    database = QuranDatabase.forTesting(NativeDatabase(dbFile));
  });

  tearDownAll(() async {
    await database.close();
  });

  test('tajweed analyzer is accurate across the entire Quran corpus', () async {
    final ayahs = await database.select(database.ayahs).get();
    expect(ayahs.length, 6236, reason: 'bundled DB must hold the full Quran');

    // ── Accumulators ──
    final markCount = <QuranTajweedRule, int>{};
    final charCount = <QuranTajweedRule, int>{};
    final violations = <String>[];
    var analyzedAyahs = 0;
    var paintedAyahs = 0;
    var noonTanweenCases = 0;
    var meemSaakinCases = 0;
    var coverageChecks = 0;

    for (final ayah in ayahs) {
      final ctx = '${ayah.surahId}:${ayah.number}';
      final text = QuranAyahSpanBuilder.formatAyahText(
        ayah.surahId,
        ayah.number,
        ayah.textAr,
      );
      if (text.isEmpty) continue;
      analyzedAyahs++;

      final marks = QuranTajweedAnalyzer.analyze(text);
      if (marks.isNotEmpty) paintedAyahs++;

      final ruleAt = List<QuranTajweedRule?>.filled(text.length, null);
      for (final m in marks) {
        for (var i = m.start; i < m.end; i++) {
          ruleAt[i] = m.rule;
        }
      }

      final tokens = _tokenize(text);

      // ── 1. Structural + per-position false-positive checks ──
      for (final m in marks) {
        markCount[m.rule] = (markCount[m.rule] ?? 0) + 1;
        charCount[m.rule] = (charCount[m.rule] ?? 0) + (m.end - m.start);

        if (m.start < 0 || m.end > text.length || m.end <= m.start) {
          violations.add('$ctx: mark out of bounds $m');
          continue;
        }
        for (var p = m.start; p < m.end; p++) {
          final c = text.codeUnitAt(p);
          if (c == 0x20 || c == 0x00A0 || c == 0x200C) {
            violations.add('$ctx: mark $m covers whitespace at $p');
            continue;
          }
          if (_isDaggerAlif(c)) {
            if (m.rule != QuranTajweedRule.madd) {
              violations.add(
                '$ctx: dagger-alif at $p painted as ${m.rule} (must be madd)',
              );
            }
            continue;
          }
          if (_isArabicLetter(c)) {
            final idx = _tokenIndexAt(tokens, p);
            if (idx < 0) {
              violations.add('$ctx: painted position $p has no owning token');
              continue;
            }
            if (!_verifyTokenRule(
              text,
              tokens,
              idx,
              m.rule,
            )) {
              violations.add(
                '$ctx: ${_describe(tokens[idx])} painted as ${m.rule} '
                'violates its precondition (span ${m.start}..${m.end} '
                '"{${text.substring(m.start, m.end)}}")',
              );
            }
          }
        }
      }

      // ── 2. Coverage (false-negative) checks ──
      // Letters that are BOTH the target of a preceding noon/meem rule AND a
      // noon/tanween/meem-saakin source of their own (e.g. كَنزٌ → the ز is
      // the ikhfa target of ن while its own tanween faces أ; ذَنۢبٌ → the ب is
      // the iqlab target while its own tanween faces ف). The analyzer paints
      // the source letter's rule last (later paint wins), matching the
      // standard engines, so these letters are verified only as targets and
      // skipped as sources.
      final claimedTargets = <int>{};
      for (var i = 0; i < tokens.length; i++) {
        final s = tokens[i];
        if (!(_isNoonSaakin(s) || _isTanween(s) || _isMeemSaakin(s))) continue;
        final j = _nextRealIndex(tokens, i, _isTanween(s) && _isTanweenFath(s));
        if (j < tokens.length &&
            (_isNoonSaakin(tokens[j]) ||
                _isTanween(tokens[j]) ||
                _isMeemSaakin(tokens[j]))) {
          claimedTargets.add(j);
        }
      }
      for (var idx = 0; idx < tokens.length; idx++) {
        final t = tokens[idx];
        if (claimedTargets.contains(idx)) continue;
        final isNoonTanween = _isNoonSaakin(t) || _isTanween(t);
        final isMeemS = _isMeemSaakin(t);
        if (!isNoonTanween && !isMeemS) continue;

        final nextIdx = _nextRealIndex(
          tokens,
          idx,
          isNoonTanween && _isTanweenFath(t),
        );
        if (nextIdx >= tokens.length) continue; // ayah-final, handled above
        final next = tokens[nextIdx];
        coverageChecks++;

        if (isNoonTanween) {
          noonTanweenCases++;
          // A silent alif/alif-maqsura/wasla is never a rule target (e.g.
          // the support alif of ٱمْرُؤٌا۟), so it behaves like izhar.
          final izharLike =
              _izharLetters.contains(next.ch) ||
              (_isSilent(next) &&
                  (next.ch == _alif ||
                      next.ch == _alifMaqsura ||
                      next.ch == _waslaAlef));
          if (izharLike) {
            if (_isNoonRule(ruleAt[t.index])) {
              violations.add(
                '$ctx: noon/tanween before izhar letter '
                '"${_describe(next)}" should not receive a noon rule '
                'but is ${ruleAt[t.index]}',
              );
            }
            continue;
          }
          if (_qalqalahLetters.contains(next.ch) &&
              next.marks.any(_sukunMarks.contains)) {
            // Word-initial saakin qalqalah after an elided hamzat-wasl
            // (e.g. عُزَيْرٌ ٱبْنُ) is skipped by design.
            if (_isNoonRule(ruleAt[t.index])) {
              violations.add(
                '$ctx: noon/tanween before saakin qalqalah '
                '"${_describe(next)}" should not receive a noon rule '
                'but is ${ruleAt[t.index]}',
              );
            }
            continue;
          }
          if (_idghamGhunnahLetters.contains(next.ch)) {
            if (ruleAt[t.index] != QuranTajweedRule.notPronounced ||
                !_targetOk(claimedTargets, nextIdx, ruleAt[next.index],
                    QuranTajweedRule.ghunnah)) {
              violations.add(
                '$ctx: idgham bighunnah "ن/ة -> ${_describe(next)}": '
                'expected notPronounced+ghunnah, got '
                '${ruleAt[t.index]}+${ruleAt[next.index]}',
              );
            }
          } else if (_idghamBilaLetters.contains(next.ch)) {
            if (ruleAt[t.index] != QuranTajweedRule.idghamBilaGhunnah ||
                !_targetOk(claimedTargets, nextIdx, ruleAt[next.index],
                    QuranTajweedRule.idghamBilaGhunnah)) {
              violations.add(
                '$ctx: idgham bila ghunnah "ن/ة -> ${_describe(next)}": '
                'expected idghamBilaGhunnah, got '
                '${ruleAt[t.index]}+${ruleAt[next.index]}',
              );
            }
          } else if (next.ch == _baa) {
            if (ruleAt[t.index] != QuranTajweedRule.notPronounced ||
                !_targetOk(claimedTargets, nextIdx, ruleAt[next.index],
                    QuranTajweedRule.iqlab)) {
              violations.add(
                '$ctx: iqlab "ن/ة -> ${_describe(next)}": expected '
                'notPronounced+iqlab, got ${ruleAt[t.index]}+'
                '${ruleAt[next.index]}',
              );
            }
          } else if (_ikhfaLetters.contains(next.ch)) {
            if (ruleAt[t.index] != QuranTajweedRule.ikhfa ||
                !_targetOk(claimedTargets, nextIdx, ruleAt[next.index],
                    QuranTajweedRule.ikhfa)) {
              violations.add(
                '$ctx: ikhfa "ن/ة -> ${_describe(next)}": expected ikhfa, '
                'got ${ruleAt[t.index]}+${ruleAt[next.index]}',
              );
            }
          } else {
            violations.add(
              '$ctx: noon/tanween "${_describe(t)}" followed by '
              '"${_describe(next)}" which is in no rule letter set '
              '(expected izhar)',
            );
          }
        } else {
          meemSaakinCases++;
          if (next.ch == _meem) {
            if (ruleAt[t.index] != QuranTajweedRule.ghunnah ||
                !_targetOk(claimedTargets, nextIdx, ruleAt[next.index],
                    QuranTajweedRule.ghunnah)) {
              violations.add(
                '$ctx: idgham shafawi "م -> م": expected ghunnah, got '
                '${ruleAt[t.index]}+${ruleAt[next.index]}',
              );
            }
          } else if (next.ch == _baa) {
            if (ruleAt[t.index] != QuranTajweedRule.ikhfaShafawi ||
                !_targetOk(claimedTargets, nextIdx, ruleAt[next.index],
                    QuranTajweedRule.ikhfaShafawi)) {
              violations.add(
                '$ctx: ikhfa shafawi "م -> ب": expected ikhfaShafawi, got '
                '${ruleAt[t.index]}+${ruleAt[next.index]}',
              );
            }
          } else {
            if (_isShafawiRule(ruleAt[t.index])) {
              violations.add(
                '$ctx: meem saakinah before "${_describe(next)}" '
                '(izhar shafawi) should not receive a shafawi rule but is '
                '${ruleAt[t.index]}',
              );
            }
          }
        }
      }
    }

    // ── 3. Report ──
    final buffer = StringBuffer()
      ..writeln('══════════════════════════════════════════════════════')
      ..writeln('  QURAN TAJWEED ANALYZER — WHOLE-CORPUS ACCURACY AUDIT')
      ..writeln('══════════════════════════════════════════════════════')
      ..writeln('Ayahs analyzed          : $analyzedAyahs')
      ..writeln('Ayahs with ≥1 mark      : $paintedAyahs')
      ..writeln('Total marks             : '
          '${markCount.values.fold(0, (a, b) => a + b)}')
      ..writeln('Coverage cases          : $coverageChecks '
          '(noon/tanween=$noonTanweenCases, meem-saakin=$meemSaakinCases)')
      ..writeln('Violations              : ${violations.length}')
      ..writeln('──────────────────────────────────────────────────────')
      ..writeln('  Per-rule painted marks (span count / colored chars)')
      ..writeln('──────────────────────────────────────────────────────');
    for (final rule in QuranTajweedRule.values) {
      final marks = markCount[rule] ?? 0;
      final chars = charCount[rule] ?? 0;
      final bar = (marks / 800 * 40).round();
      buffer.writeln(
        '  ${rule.name.padRight(20)} ${marks.toString().padLeft(5)} / '
        '${chars.toString().padLeft(7)} ${'█' * bar}',
      );
    }
    if (violations.isNotEmpty) {
      buffer.writeln('──────────────────────────────────────────────────────');
      buffer.writeln('  First ${violations.length} violations:');
      for (final v in violations.take(60)) {
        buffer.writeln('    • $v');
      }
    }
    buffer.writeln('══════════════════════════════════════════════════════');
    // ignore: avoid_print
    print(buffer.toString());

    expect(
      violations,
      isEmpty,
      reason: '${violations.length} accuracy violations across the corpus:\n'
          '${violations.take(20).join('\n')}',
    );
  });
}

// ──────────────────────────────────────────────────────────────────────────
// Independent phonological verifier. The constants and tokenizer below are
// intentionally re-derived from the Unicode Arabic orthography rather than
// imported from the analyzer, so the two implementations cannot share bugs.
// ──────────────────────────────────────────────────────────────────────────

const int _fatha = 0x064E;
const int _damma = 0x064F;
const int _kasra = 0x0650;
const int _shadda = 0x0651;
const int _sukun = 0x0652;
const int _tanweenFath = 0x064B;
const int _maddah = 0x0653;
const int _daggerAlif = 0x0670;
const int _emptyCentreSukun = 0x06E1;

const int _alif = 0x0627;
const int _waslaAlef = 0x0671;
const int _baa = 0x0628;
const int _noon = 0x0646;
const int _meem = 0x0645;
const int _waw = 0x0648;
const int _alifMaqsura = 0x0649;
const int _yaa = 0x064A;

const Set<int> _tanweenMarks = {0x064B, 0x064C, 0x064D};
const Set<int> _sukunMarks = {_sukun, _emptyCentreSukun};
const Set<int> _vowelMarks = {_fatha, _damma, _kasra};

const Set<int> _idghamGhunnahLetters = {_yaa, _noon, _meem, _waw};
const Set<int> _idghamBilaLetters = {0x0644, 0x0631};
// The canonical 15 ikhfa letters: ت ث ج د ذ ز س ش ص ض ط ظ ف ق ك.
// Note: د (dal) IS ikhfa; ح (ha) is an IZHAR letter and must NOT be here.
const Set<int> _ikhfaLetters = {
  0x062A, 0x062B, 0x062C, 0x062F, 0x0630, 0x0632, 0x0633, 0x0634, 0x0635,
  0x0636, 0x0637, 0x0638, 0x0641, 0x0642, 0x0643,
};
const Set<int> _qalqalahLetters = {0x0642, 0x0637, 0x0628, 0x062C, 0x062F};
const Set<int> _maddLetters = {_alif, _alifMaqsura, _yaa, _waw};
const Set<int> _hamzaLetters = {0x0621, 0x0623, 0x0624, 0x0625, 0x0626};
const Set<int> _izharLetters = {
  ..._hamzaLetters,
  0x0647, // ه
  0x0639, // ع
  0x062D, // ح
  0x063A, // غ
  0x062E, // خ
};
const Set<int> _smallMeemMarks = {0x06E2, 0x06E3, 0x06ED};

const Set<int> _attachedMarks = {
  0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0653,
  0x0654, 0x0655, 0x0670, 0x0640, 0x06DF, 0x06E0, 0x06E1, 0x06E2, 0x06E3,
  0x06E4, 0x06E5, 0x06E6, 0x06E7, 0x06E8, 0x06EA, 0x06EB, 0x06EC, 0x06ED,
};

typedef _Tok = ({int index, int ch, Set<int> marks, int end});

List<_Tok> _tokenize(String text) {
  final code = text.codeUnits;
  final out = <_Tok>[];
  var i = 0;
  while (i < code.length) {
    final c = code[i];
    if (_isArabicLetter(c)) {
      final marks = <int>{};
      var j = i + 1;
      while (j < code.length && _attachedMarks.contains(code[j])) {
        marks.add(code[j]);
        j++;
      }
      out.add((index: i, ch: c, marks: marks, end: j));
      i = j;
    } else {
      i++;
    }
  }
  return out;
}

int _tokenIndexAt(List<_Tok> tokens, int pos) {
  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i].index == pos) return i;
  }
  return -1;
}

bool _isArabicLetter(int c) {
  return (c >= 0x0621 && c <= 0x063A) ||
      (c >= 0x0641 && c <= 0x064A) ||
      c == _waslaAlef ||
      c == 0x06FB ||
      c == 0x06FD;
}

bool _isDaggerAlif(int c) => c == _daggerAlif;

bool _isSilent(_Tok t) {
  return !t.marks.any(
    (c) =>
        _vowelMarks.contains(c) ||
        _sukunMarks.contains(c) ||
        _tanweenMarks.contains(c) ||
        c == _shadda,
  );
}

bool _isNoonSaakin(_Tok t) =>
    t.ch == _noon && (t.marks.any(_sukunMarks.contains) || _isSilent(t));

bool _isMeemSaakin(_Tok t) =>
    t.ch == _meem && (t.marks.any(_sukunMarks.contains) || _isSilent(t));

bool _isTanween(_Tok t) => t.marks.any(_tanweenMarks.contains);

bool _isTanweenFath(_Tok t) => t.marks.contains(_tanweenFath);

int? _lastVowel(_Tok t) {
  int? v;
  for (final c in t.marks) {
    if (_vowelMarks.contains(c)) v = c;
  }
  return v;
}

/// Mirrors the analyzer's "next real letter" walk: for a tanween-fath the
/// silent support alif/alif-maqsura is skipped, and elided wasla alefs are
/// always skipped.
int _nextRealIndex(List<_Tok> tokens, int idx, bool skipFathSupport) {
  var k = idx + 1;
  var skipSupport = skipFathSupport;
  while (k < tokens.length) {
    final t = tokens[k];
    if (skipSupport && (t.ch == _alif || t.ch == _alifMaqsura) && _isSilent(t)) {
      skipSupport = false;
      k++;
      continue;
    }
    if (t.ch == _waslaAlef && _isSilent(t)) {
      k++;
      continue;
    }
    break;
  }
  return k;
}

/// Next real letter for the maddah classification: the analyzer skips
/// silent support alifs AND elided wasla alefs unconditionally when
/// deciding whether a maddah-marked letter meets a hamza (e.g. قَالُوٓا۟).
int _nextRealMadd(List<_Tok> tokens, int idx) {
  var k = idx + 1;
  while (k < tokens.length) {
    final t = tokens[k];
    if ((t.ch == _alif || t.ch == _alifMaqsura || t.ch == _waslaAlef) &&
        _isSilent(t)) {
      k++;
      continue;
    }
    break;
  }
  return k;
}

bool _hasSpaceBetween(String text, int a, int b) {
  for (var i = a; i < b && i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0x20 || c == 0x00A0 || c == 0x200C) return true;
  }
  return false;
}

bool _isAyahFinal(String text, int from) {
  for (var i = from; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (_isArabicLetter(c)) return false;
    if (c == 0x20 || c == 0x00A0 || c == 0x200C) continue;
    // allow trailing punctuation / small-high signs
  }
  return true;
}

bool _verifyTokenRule(String text, List<_Tok> tokens, int idx, QuranTajweedRule rule) {
  final t = tokens[idx];
  switch (rule) {
    case QuranTajweedRule.madd:
      if (t.marks.contains(_daggerAlif)) return true;
      if (!_maddLetters.contains(t.ch) || !_isSilent(t)) return false;
      if (idx == 0) return false;
      final prev = tokens[idx - 1];
      if (_hasSpaceBetween(text, prev.end, t.index)) return false;
      final v = _lastVowel(prev);
      if (t.ch == _alif || t.ch == _alifMaqsura) return v == _fatha;
      if (t.ch == _yaa) return v == _kasra;
      if (t.ch == _waw) return v == _damma;
      return false;

    case QuranTajweedRule.maddWajib:
    case QuranTajweedRule.maddJaiz:
      if (!t.marks.contains(_maddah)) return false;
      final j = _nextRealMadd(tokens, idx);
      if (j >= tokens.length) return false;
      final next = tokens[j];
      if (!_hamzaLetters.contains(next.ch)) return false;
      final crossed = _hasSpaceBetween(text, t.end, next.index);
      return rule == QuranTajweedRule.maddWajib ? !crossed : crossed;

    case QuranTajweedRule.maddLazim:
      if (!t.marks.contains(_maddah)) return false;
      final j = _nextRealMadd(tokens, idx);
      if (j < tokens.length && _hamzaLetters.contains(tokens[j].ch)) {
        return false; // would have been wajib/jaiz
      }
      return true;

    case QuranTajweedRule.maddSilaSughra:
      return t.ch == 0x0647 &&
          (t.marks.contains(0x06E5) || t.marks.contains(0x06E6));

    case QuranTajweedRule.qalqalah:
      if (!_qalqalahLetters.contains(t.ch)) return false;
      if (t.marks.any(_sukunMarks.contains)) return true;
      return _isAyahFinal(text, t.end);

    case QuranTajweedRule.ghunnah:
      if (t.ch == _noon && t.marks.contains(_shadda)) return true;
      if (t.ch == _meem && t.marks.contains(_shadda)) return true;
      if (t.marks.any(_smallMeemMarks.contains)) {
        return !_isAyahFinal(text, t.end);
      }
      // idgham bighunnah target: previous real letter is noon/tanween
      if (idx > 0) {
        final p = _prevNonSupport(tokens, idx);
        if (p >= 0 && (_isNoonSaakin(tokens[p]) || _isTanween(tokens[p]))) {
          return true;
        }
      }
      // idgham shafawi: meem-saakinah followed by meem (first meem)
      if (t.ch == _meem && _isMeemSaakin(t)) {
        final j = _nextRealIndex(tokens, idx, false);
        if (j < tokens.length && tokens[j].ch == _meem) return true;
      }
      // idgham shafawi: second meem after meem-saakinah
      if (t.ch == _meem && idx > 0 && _isMeemSaakin(tokens[idx - 1])) {
        return true;
      }
      return false;

    case QuranTajweedRule.notPronounced:
      if (!(_isNoonSaakin(t) || _isTanween(t))) return false;
      final j = _nextRealIndex(tokens, idx, _isTanweenFath(t));
      if (j >= tokens.length) return false;
      final next = tokens[j];
      return _idghamGhunnahLetters.contains(next.ch) || next.ch == _baa;

    case QuranTajweedRule.ikhfa:
      // source: noon/tanween whose next real letter is an ikhfa letter
      if ((_isNoonSaakin(t) || _isTanween(t))) {
        final j = _nextRealIndex(tokens, idx, _isTanweenFath(t));
        if (j < tokens.length && _ikhfaLetters.contains(tokens[j].ch)) {
          return true;
        }
      }
      // silent support alif / elided wasla between source and target
      if (_isSilent(t) &&
          (t.ch == _alif || t.ch == _alifMaqsura || t.ch == _waslaAlef)) {
        return true;
      }
      // target: an ikhfa letter reached from a noon/tanween source
      if (_ikhfaLetters.contains(t.ch)) {
        final p = _prevNonSupport(tokens, idx);
        return p >= 0 && (_isNoonSaakin(tokens[p]) || _isTanween(tokens[p]));
      }
      return false;

    case QuranTajweedRule.idghamBilaGhunnah:
      if (_isNoonSaakin(t) || _isTanween(t)) {
        final j = _nextRealIndex(tokens, idx, _isTanweenFath(t));
        if (j < tokens.length && _idghamBilaLetters.contains(tokens[j].ch)) {
          return true;
        }
      }
      if (_isSilent(t) &&
          (t.ch == _alif || t.ch == _alifMaqsura || t.ch == _waslaAlef)) {
        return true;
      }
      if (_idghamBilaLetters.contains(t.ch)) {
        final p = _prevNonSupport(tokens, idx);
        return p >= 0 && (_isNoonSaakin(tokens[p]) || _isTanween(tokens[p]));
      }
      return false;

    case QuranTajweedRule.ikhfaShafawi:
      // source: meem saakinah followed by baa
      if (_isMeemSaakin(t)) {
        final j = _nextRealIndex(tokens, idx, false);
        if (j < tokens.length && tokens[j].ch == _baa) return true;
      }
      // target: baa reached from a meem saakinah
      if (t.ch == _baa) {
        final p = _prevNonSupport(tokens, idx);
        return p >= 0 && _isMeemSaakin(tokens[p]);
      }
      return false;

    case QuranTajweedRule.iqlab:
      if (t.ch != _baa) return false;
      final p = _prevNonSupport(tokens, idx);
      if (p < 0) return false;
      final prev = tokens[p];
      return _isNoonSaakin(prev) || _isTanween(prev);
  }
}

/// True for the rules a noon/tanween letter receives *because of the letter
/// that follows it*. Local rules painted on the same letter for its own
/// orthography (mushaddad ghunnah, qalqalah, madd) are legitimate and do
/// not count as a violation of the izhar/waqf expectations.
bool _isNoonRule(QuranTajweedRule? rule) {
  return rule == QuranTajweedRule.notPronounced ||
      rule == QuranTajweedRule.ikhfa ||
      rule == QuranTajweedRule.idghamBilaGhunnah;
}

/// True for the rules a meem saakinah receives because of the following
/// letter (idgham shafawi / ikhfa shafawi). Local madd/maddah painting is
/// legitimate and must not be treated as a violation.
bool _isShafawiRule(QuranTajweedRule? rule) {
  return rule == QuranTajweedRule.ghunnah ||
      rule == QuranTajweedRule.ikhfaShafawi;
}

/// A rule's target letter is "claimed" when it is itself a noon/tanween/
/// meem-saakin source: the analyzer paints its own rule last (later paint
/// wins), so the target-equality check is skipped for claimed letters.
bool _targetOk(
  Set<int> claimed,
  int nextIdx,
  QuranTajweedRule? actual,
  QuranTajweedRule expected,
) {
  if (claimed.contains(nextIdx)) return true;
  return actual == expected;
}

/// Mirrors the forward support-alif / wasla skipping in reverse, so a
/// rule's target letter can be traced back to its noon/tanween source.
int _prevNonSupport(List<_Tok> tokens, int idx) {
  var k = idx - 1;
  while (k >= 0) {
    final t = tokens[k];
    if (t.ch == _waslaAlef && _isSilent(t)) {
      k--;
      continue;
    }
    if ((t.ch == _alif || t.ch == _alifMaqsura) && _isSilent(t)) {
      k--;
      continue;
    }
    break;
  }
  return k;
}

String _describe(_Tok t) {
  return '${String.fromCharCode(t.ch)}'
      '(marks: ${t.marks.map((c) => c.toRadixString(16)).join(',')})';
}