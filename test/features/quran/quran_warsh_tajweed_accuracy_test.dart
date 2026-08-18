import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ahl_jannah/features/quran/data/datasources/quran_warsh_database.dart';
import 'package:ahl_jannah/features/quran/domain/tajweed/quran_tajweed_analyzer.dart';
import 'package:ahl_jannah/features/quran/domain/tajweed/quran_tajweed_rule.dart';
import 'package:ahl_jannah/features/quran/presentation/widgets/quran_ayah_span_builder.dart';

/// Whole-Quran accuracy audit for [QuranTajweedAnalyzer] on the Warsh
/// riwaya, mirroring `quran_tajweed_accuracy_test.dart` for Hafs.
///
/// The analyzer needs no riwaya flag — it reads the Maghribi orthography
/// straight off the glyphs (ے = alif maqsura, ٗ/ٞ/ٖ = tanween, اَ۬ = elided
/// hamzat al-wasl). This suite runs it over every ayah in the bundled
/// `assets/quran_warsh.db` (6,213 ayahs, formatted the same way the reader
/// feeds it) and verifies the output against the same *independent*
/// phonological model as the Hafs audit, extended for that orthography.
void main() {
  late WarshQuranDatabase database;

  setUpAll(() {
    final dbFile = File('assets/quran_warsh.db');
    if (!dbFile.existsSync()) {
      throw StateError(
        'assets/quran_warsh.db not found at ${dbFile.absolute.path}. '
        'Tests must run from the ahl_jannah project root.',
      );
    }
    database = WarshQuranDatabase.forTesting(NativeDatabase(dbFile));
  });

  tearDownAll(() async {
    await database.close();
  });

  test('tajweed analyzer is accurate across the Warsh corpus', () async {
    final ayahs = await database.getAllAyahs();
    expect(ayahs.length, 6213, reason: 'bundled Warsh DB must hold the Quran');

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
            if (!_verifyTokenRule(text, tokens, idx, m.rule)) {
              violations.add(
                '$ctx: ${_describe(tokens[idx])} painted as ${m.rule} '
                'violates its precondition (span ${m.start}..${m.end} '
                '"{${text.substring(m.start, m.end)}}")',
              );
            }
          }
        }
      }

      // Coverage (false-negative) checks — identical to the Hafs model.
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
        if (nextIdx >= tokens.length) continue;
        final next = tokens[nextIdx];
        coverageChecks++;

        if (isNoonTanween) {
          noonTanweenCases++;
          final izharLike =
              _izharLetters.contains(next.ch) ||
              // Warsh writes the hamza of أَنَّ/إِلَّا/أَوْ/أُولَٰئِكَ as a
              // plain (often voweled) alef, and tanween fath is written on
              // the word's support alef; any alef-type letter reached as
              // next-real is an elided/izhar letter, never a noon rule.
              next.ch == _alif ||
              next.ch == _alifMaqsura ||
              next.ch == _alifMaqsuraWarsh ||
              next.ch == _waslaAlef;
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

    final buffer = StringBuffer()
      ..writeln('══════════════════════════════════════════════════════')
      ..writeln('  WRSH TAJWEED ANALYZER — WHOLE-CORPUS ACCURACY AUDIT')
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
// Independent phonological verifier, re-derived from the Unicode Arabic
// orthography (never imported from the analyzer) and extended for the
// Maghribi/Warsh glyph forms used by the QPC Warsh mushaf:
//   ے (U+06D2)  alif maqsura / final ي        (madd letter)
//   ٗ (U+0657)  tanween fath (inverted damma)  (tanween mark)
//   ٞ (U+065E)  tanween damm (two-dot fatha)   (tanween mark)
//   ٖ (U+0656)  tanween kasr (subscript alif)  (tanween mark)
//   اَ۬         hamzat al-wasl = alif carrying U+06EC (elided)
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
const int _alifMaqsura = 0x0649;
const int _alifMaqsuraWarsh = 0x06D2;
const int _waslaMark = 0x06EC;
const int _waslaMarkWarsh = 0x06EA;
const int _baa = 0x0628;
const int _noon = 0x0646;
const int _meem = 0x0645;
const int _waw = 0x0648;
const int _yaa = 0x064A;

const int _tanweenFathWarsh = 0x0657;
const int _tanweenDamWarsh = 0x065E;
const int _tanweenKasrWarsh = 0x0656;
const int _smallMeemIsolated = 0x06E2;

const Set<int> _tanweenMarks = {
  0x064B,
  0x064C,
  0x064D,
  _tanweenFathWarsh,
  _tanweenDamWarsh,
  _tanweenKasrWarsh,
};
const Set<int> _sukunMarks = {_sukun, _emptyCentreSukun};
const Set<int> _vowelMarks = {_fatha, _damma, _kasra};

const Set<int> _idghamGhunnahLetters = {_yaa, _noon, _meem, _waw};
const Set<int> _idghamBilaLetters = {0x0644, 0x0631};
const Set<int> _ikhfaLetters = {
  0x062A, 0x062B, 0x062C, 0x062F, 0x0630, 0x0632, 0x0633, 0x0634, 0x0635,
  0x0636, 0x0637, 0x0638, 0x0641, 0x0642, 0x0643,
};
const Set<int> _qalqalahLetters = {0x0642, 0x0637, 0x0628, 0x062C, 0x062F};
const Set<int> _maddLetters = {
  _alif,
  _alifMaqsura,
  _yaa,
  _waw,
  _alifMaqsuraWarsh,
};
const Set<int> _hamzaLetters = {0x0621, 0x0623, 0x0624, 0x0625, 0x0626};
const Set<int> _izharLetters = {
  ..._hamzaLetters,
  0x0647,
  0x0639,
  0x062D,
  0x063A,
  0x062E,
};
const Set<int> _smallMeemMarks = {0x06E2, 0x06E3, 0x06ED};

const Set<int> _attachedMarks = {
  0x064B, 0x064C, 0x064D, 0x064E, 0x064F, 0x0650, 0x0651, 0x0652, 0x0653,
  0x0654, 0x0655, 0x0656, 0x0657, 0x065E, 0x0670, 0x0640, 0x06DF, 0x06E0,
  0x06E1, 0x06E2, 0x06E3, 0x06E4, 0x06E5, 0x06E6, 0x06E7, 0x06E8, 0x06EA,
  0x06EB, 0x06EC, 0x06ED,
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
      c == _alifMaqsuraWarsh ||
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

bool _isTanween(_Tok t) =>
    t.marks.any(_tanweenMarks.contains) ||
    // Warsh tanween written as a vowel + the small-meem sign (ۢ, U+06E2):
    // اَلِيمُۢ (damm), شَهِيداَۢ (fath on a support alef).
    (t.marks.contains(_smallMeemIsolated) && t.marks.any(_vowelMarks.contains));

bool _isTanweenFath(_Tok t) =>
    t.marks.contains(_tanweenFath) ||
    t.marks.contains(_tanweenFathWarsh) ||
    (t.ch == _alif &&
        t.marks.contains(_fatha) &&
        t.marks.contains(_smallMeemIsolated));

int? _lastVowel(_Tok t) {
  int? v;
  for (final c in t.marks) {
    if (_vowelMarks.contains(c)) v = c;
  }
  return v;
}

/// Mirrors the analyzer's elided-hamzat-al-wasl test: the Hafs wasla alef
/// (ٱ), the Warsh rounded mark (اَ۬, U+06EC) and the Warsh empty-centre
/// mark on a word-initial alef (اَ۪ / اِ۪, U+06EA). On non-alef letters ۪
/// is the waqf mark and is not elided.
bool _isWaslaAlef(_Tok t) {
  return t.marks.contains(_waslaMark) ||
      (t.ch == _alif && t.marks.contains(_waslaMarkWarsh)) ||
      t.ch == _waslaAlef;
}

/// Mirrors the analyzer's "next real letter" walk: support alifs for a
/// tanween-fath and elided wasla alefs are skipped.
int _nextRealIndex(List<_Tok> tokens, int idx, bool skipFathSupport) {
  var k = idx + 1;
  var skipSupport = skipFathSupport;
  while (k < tokens.length) {
    final t = tokens[k];
    if (skipSupport &&
        (t.ch == _alif ||
            t.ch == _alifMaqsura ||
            t.ch == _alifMaqsuraWarsh) &&
        _isSilent(t)) {
      skipSupport = false;
      k++;
      continue;
    }
    if (_isWaslaAlef(t)) {
      k++;
      continue;
    }
    break;
  }
  return k;
}

/// Next real letter for the maddah classification.
int _nextRealMadd(List<_Tok> tokens, int idx) {
  var k = idx + 1;
  while (k < tokens.length) {
    final t = tokens[k];
    if ((t.ch == _alif ||
            t.ch == _alifMaqsura ||
            t.ch == _alifMaqsuraWarsh ||
            t.ch == _waslaAlef) &&
        _isSilent(t)) {
      k++;
      continue;
    }
    if (_isWaslaAlef(t)) {
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
  }
  return true;
}

bool _verifyTokenRule(String text, List<_Tok> tokens, int idx, QuranTajweedRule rule) {
  final t = tokens[idx];
  switch (rule) {
    case QuranTajweedRule.madd:
      if (t.marks.contains(_daggerAlif)) return true;
      if (!_maddLetters.contains(t.ch) || !_isSilent(t)) return false;
      if (_isWaslaAlef(t)) return false;
      if (idx == 0) return false;
      final prev = tokens[idx - 1];
      if (_hasSpaceBetween(text, prev.end, t.index)) return false;
      final v = _lastVowel(prev);
      if (t.ch == _alif || t.ch == _alifMaqsura) return v == _fatha;
      if (t.ch == _alifMaqsuraWarsh) {
        return v == _fatha || v == _kasra;
      }
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
        return false;
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
      if (idx > 0) {
        final p = _prevNonSupport(tokens, idx);
        if (p >= 0 && (_isNoonSaakin(tokens[p]) || _isTanween(tokens[p]))) {
          return true;
        }
      }
      if (t.ch == _meem && _isMeemSaakin(t)) {
        final j = _nextRealIndex(tokens, idx, false);
        if (j < tokens.length && tokens[j].ch == _meem) return true;
      }
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
      if ((_isNoonSaakin(t) || _isTanween(t))) {
        final j = _nextRealIndex(tokens, idx, _isTanweenFath(t));
        if (j < tokens.length && _ikhfaLetters.contains(tokens[j].ch)) {
          return true;
        }
      }
      // An elided wasla alef (ٱ, اَ۬/اِ۬, اَ۪/اِ۪) or silent support alif
      // inside the painted span.
      if (_isWaslaAlef(t) ||
          (_isSilent(t) &&
              (t.ch == _alif ||
                  t.ch == _alifMaqsura ||
                  t.ch == _alifMaqsuraWarsh))) {
        return true;
      }
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
      // An elided wasla alef (ٱ, اَ۬/اِ۬, اَ۪/اِ۪) or silent support alif
      // inside the painted span.
      if (_isWaslaAlef(t) ||
          (_isSilent(t) &&
              (t.ch == _alif ||
                  t.ch == _alifMaqsura ||
                  t.ch == _alifMaqsuraWarsh))) {
        return true;
      }
      if (_idghamBilaLetters.contains(t.ch)) {
        final p = _prevNonSupport(tokens, idx);
        return p >= 0 && (_isNoonSaakin(tokens[p]) || _isTanween(tokens[p]));
      }
      return false;

    case QuranTajweedRule.ikhfaShafawi:
      if (_isMeemSaakin(t)) {
        final j = _nextRealIndex(tokens, idx, false);
        if (j < tokens.length && tokens[j].ch == _baa) return true;
      }
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

bool _isNoonRule(QuranTajweedRule? rule) {
  return rule == QuranTajweedRule.notPronounced ||
      rule == QuranTajweedRule.ikhfa ||
      rule == QuranTajweedRule.idghamBilaGhunnah;
}

bool _isShafawiRule(QuranTajweedRule? rule) {
  return rule == QuranTajweedRule.ghunnah ||
      rule == QuranTajweedRule.ikhfaShafawi;
}

bool _targetOk(
  Set<int> claimed,
  int nextIdx,
  QuranTajweedRule? actual,
  QuranTajweedRule expected,
) {
  if (claimed.contains(nextIdx)) return true;
  return actual == expected;
}

int _prevNonSupport(List<_Tok> tokens, int idx) {
  var k = idx - 1;
  while (k >= 0) {
    final t = tokens[k];
    if (_isWaslaAlef(t)) {
      k--;
      continue;
    }
    if ((t.ch == _alif ||
            t.ch == _alifMaqsura ||
            t.ch == _alifMaqsuraWarsh) &&
        _isSilent(t)) {
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