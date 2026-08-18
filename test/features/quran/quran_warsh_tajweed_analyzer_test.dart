import 'package:ahl_jannah/features/quran/domain/tajweed/quran_tajweed_analyzer.dart';
import 'package:ahl_jannah/features/quran/domain/tajweed/quran_tajweed_rule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Collects every Arabic letter that falls inside a [rule]'s colored range.
Set<String> lettersByRule(String text, QuranTajweedRule rule) {
  final letters = <String>{};
  for (final mark in QuranTajweedAnalyzer.analyze(text)) {
    if (mark.rule != rule) continue;
    for (var i = mark.start; i < mark.end; i++) {
      if (_isArabicLetter(text[i])) letters.add(text[i]);
    }
  }
  return letters;
}

bool _isArabicLetter(String c) {
  final code = c.codeUnitAt(0);
  return (code >= 0x0621 && code <= 0x063A) ||
      (code >= 0x0641 && code <= 0x064A) ||
      c == '\u0671' ||
      c == '\u06D2';
}

/// Warsh-riwaya orthography checks. All test strings are taken verbatim
/// from the bundled `assets/quran_warsh.db` (surah:ayah noted inline), so
/// they reflect exactly how the QPC Warsh mushaf is encoded.
void main() {
  group('QuranTajweedAnalyzer (Warsh orthography)', () {
    test('Warsh ے is a madd letter after kasra (final ي) and fatha', () {
      // 10:9 تَجْرِے
      expect(lettersByRule('تَجْرِے', QuranTajweedRule.madd), {'ے'});
      // alif maqsura form (fatha + ے)
      expect(lettersByRule('بَلَے', QuranTajweedRule.madd), {'ے'});
    });

    test('Warsh ے with maddah before a word-initial hamza is madd jaiz', () {
      // 10:21 فِےٓ ءَايَاتِنَا
      expect(lettersByRule('فِےٓ ءَايَاتِنَا', QuranTajweedRule.maddJaiz), {'ے'});
    });

    test('Maghribi tanween fath (ٗ) triggers idgham bighunnah', () {
      // 10:45 سَاعَةٗ مِّنَ
      expect(
        lettersByRule('سَاعَةٗ مِّنَ', QuranTajweedRule.notPronounced),
        {'ة'},
      );
      expect(lettersByRule('سَاعَةٗ مِّنَ', QuranTajweedRule.ghunnah), {'م'});
    });

    test('Maghribi tanween damm (ٞ) triggers idgham bighunnah', () {
      // 10:2 لَسِحْرٞ مُّبِينٌ
      expect(
        lettersByRule('لَسِحْرٞ مُّبِينٌ', QuranTajweedRule.notPronounced),
        {'ر'},
      );
      expect(
        lettersByRule('لَسِحْرٞ مُّبِينٌ', QuranTajweedRule.ghunnah),
        {'م'},
      );
    });

    test('Maghribi tanween damm (ٞ) triggers ikhfa', () {
      // 10:21 لَهُم مَّكْرٞ فِےٓ
      expect(lettersByRule('مَكْرٞ فِےٓ', QuranTajweedRule.ikhfa), {'ر', 'ف'});
    });

    test('Maghribi tanween kasr (ٖ) triggers idgham bighunnah', () {
      // 10:2 رَجُلٖ مِّنْهُمُۥٓ
      expect(
        lettersByRule('رَجُلٖ مُّبِينٌ', QuranTajweedRule.notPronounced),
        {'ل'},
      );
      expect(lettersByRule('رَجُلٖ مُّبِينٌ', QuranTajweedRule.ghunnah), {'م'});
    });

    test('Warsh wasla alif (اِ۬, U+06EC) is elided before idgham bila', () {
      // 26:160 لُوطٍ اِ۬لْمُرْسَلِ — the tanween meets ل, not the wasla alif.
      // The wasla alif is painted as part of the same span, exactly as the
      // Hafs engine paints ٱ in خَيْرًا ٱلْوَصِيَّةُ.
      expect(
        lettersByRule('لُوطٍ اِ۬لْمُرْسَلِ', QuranTajweedRule.idghamBilaGhunnah),
        {'ط', 'ا', 'ل'},
      );
    });

    test('Warsh kasra-wasla alif (اِ۪, U+06EA) is elided before ikhfa', () {
      // 14:21 رَمَادٍ اِ۪شْتَدَّ — the tanween kasr meets ش, not the wasla.
      expect(
        lettersByRule('رَمَادٍ اِ۪شْتَدَّ', QuranTajweedRule.ikhfa),
        {'د', 'ا', 'ش'},
      );
    });

    test('Warsh small-meem tanween damm (ۢ) is an iqlab source before ب', () {
      // 10:4 عَذَابٌ أَلِيمٌ بِمَا — م with dammah + U+06E2 = tanween damm.
      expect(
        lettersByRule('اَلِيمُۢ بِمَا', QuranTajweedRule.notPronounced),
        {'م'},
      );
      expect(lettersByRule('اَلِيمُۢ بِمَا', QuranTajweedRule.iqlab), {'ب'});
    });

    test('Warsh small-meem tanween fath on a support alef is iqlab before ب',
        () {
      // 10:29 شَهِيدًا بَيْنَكُمْ
      expect(
        lettersByRule('شَهِيداَۢ بَيْنَ', QuranTajweedRule.notPronounced),
        {'ا'},
      );
      expect(lettersByRule('شَهِيداَۢ بَيْنَ', QuranTajweedRule.iqlab), {'ب'});
    });

    test('Warsh small-meem tanween at the end of an ayah carries no color', () {
      // 4:136 سَبِيلًا (ayah-final) — a tanween-at-stop, not an iqlab.
      expect(
        lettersByRule('سَبِيلاَۢۖ', QuranTajweedRule.ghunnah),
        isEmpty,
      );
      expect(lettersByRule('سَبِيلاَۢۖ', QuranTajweedRule.iqlab), isEmpty);
      expect(
        lettersByRule('سَبِيلاَۢۖ', QuranTajweedRule.notPronounced),
        isEmpty,
      );
    });

    test('Warsh word-initial silent alef (dropped hamza) is not a madd', () {
      // 4:5 أَمْوَٰلَكُمُ — the bare alef opens the word even though the
      // previous word ends in fatha, so it is not an elongating madd (the
      // fatha+dagger of وَٰ is a sign-only madd, not a letter).
      expect(
        lettersByRule('يَرَى اَمْوَٰلَكُمُ', QuranTajweedRule.madd),
        {'ى'},
      );
    });

    test('Warsh fatha-wasla alif (اَ۬) is elided before idgham bila', () {
      // مِنْ اَ۬للَّهِ — the saakin noon meets لّ (shadda), not the wasla.
      expect(
        lettersByRule('مِنْ اَ۬للَّهِ', QuranTajweedRule.idghamBilaGhunnah),
        {'ن', 'ا', 'ل'},
      );
    });

    test('Hafs behaviour is unchanged by the Warsh additions', () {
      expect(lettersByRule('قَالَ', QuranTajweedRule.madd), {'ا'});
      expect(lettersByRule('ٱلضَّآلِّينَ', QuranTajweedRule.maddLazim), {'ا'});
      expect(lettersByRule('لَهُۥ', QuranTajweedRule.maddSilaSughra), {'ه'});
      expect(
        lettersByRule('كِتَٰبٌ مُّبِينٌ', QuranTajweedRule.notPronounced),
        {'ب'},
      );
    });
  });
}