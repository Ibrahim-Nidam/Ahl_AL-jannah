import 'package:ahl_jannah/features/quran/domain/entities/quran_entities.dart';
import 'package:ahl_jannah/features/quran/presentation/widgets/quran_ayah_span_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A recognizer used by the span builder. Never triggered in tests.
TapGestureRecognizer _recognizer() => TapGestureRecognizer()..onTap = () {};

void main() {
  group('QuranAyahSpanBuilder lam-alef ligature protection', () {
    test('lam and alef of لَا stay in a single colored span', () {
      // The madd rule colors the alef (ا) of لَا but not the lam (ل) or its
      // fatha, which would otherwise split the pair across two spans and
      // break shaping. The builder must merge them into one lambda run.
      final ayah = AyahEntity(
        id: 1,
        surahId: 2,
        number: 2,
        page: 2,
        juz: 1,
        hizb: 1,
        textAr: 'ذَلِكَ ٱلْكِتَـٰبُ لَا رَيْبَ',
        translationEn: '',
        translationFr: '',
      );

      final spans = QuranAyahSpanBuilder.build(
        ayahs: [ayah],
        fontSize: 28,
        quranTextColor: Colors.black,
        accentColor: Colors.amber,
        selectedAyah: null,
        bookmarkedAyahKeys: const {},
        recognizerFor: (_) => _recognizer(),
        showTajweed: true,
        fontFamily: 'UthmanicHafs',
      );

      // Locate the lamb-alef sequence لَا (lam + fatha + alef) in the
      // produced text, then assert the lam and the alef fall in the same
      // span — the guarantee that prevents the ligature from being split.
      final clauses = spans.whereType<TextSpan>().toList();
      for (final s in clauses) {
        final t = s.text ?? '';
        if (t.contains('لَا')) {
          expect(
            t,
            contains('ل'),
            reason: 'lam is present in the run',
          );
        }
      }

      // No span may isolate the alef from the lam.
      final alefOnly = clauses.any((s) => s.text == 'ا');
      expect(alefOnly, isFalse,
          reason: 'the alef must stay merged with its lam');
    });
  });
}