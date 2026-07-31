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
      c == '\u0671';
}

void main() {
  group('QuranTajweedAnalyzer', () {
    test('madd tabeei on alif', () {
      expect(lettersByRule('قَالَ', QuranTajweedRule.madd), {'ا'});
      expect(lettersByRule('ٱلَّذِينَ', QuranTajweedRule.madd), {'ي'});
    });

    test('madd on dagger alif colors the sign itself', () {
      final marks = QuranTajweedAnalyzer.analyze('ٱلرَّحْمَـٰنِ');
      final spans = marks
          .where((m) => m.rule == QuranTajweedRule.madd)
          .map((m) => 'ٱلرَّحْمَـٰنِ'.substring(m.start, m.end))
          .toList();
      expect(spans, contains('ـٰ'));
      expect(lettersByRule('صِرَٰطَ', QuranTajweedRule.madd), isEmpty);
      expect(
        QuranTajweedAnalyzer.analyze('صِرَٰطَ')
            .any(
              (m) =>
                  m.rule == QuranTajweedRule.madd &&
                  'صِرَٰطَ'.substring(m.start, m.end) == 'ٰ',
            ),
        isTrue,
      );
    });

    test('madd on maddah sign is classified by context', () {
      // فَلَآ إِثْمَ → word-final مaddah alif before a word-initial hamza:
      // ja'iz munfasil.
      expect(lettersByRule('فَلَآ إِثْمَ', QuranTajweedRule.maddJaiz), {'ا'});
    });

    test('madd wajib muttasil (maddah letter before hamza, same word)', () {
      expect(lettersByRule('سَوَآءٌ', QuranTajweedRule.maddWajib), {'ا'});
      expect(lettersByRule('ٱلسَّمَآءَ', QuranTajweedRule.maddWajib), {'ا'});
    });

    test('madd jaiz munfasil (maddah letter before word-initial hamza)', () {
      expect(lettersByRule('بِمَآ أُنزِلَ', QuranTajweedRule.maddJaiz), {'ا'});
      expect(lettersByRule('إِلَّآ أَنفُسُهُمْ', QuranTajweedRule.maddJaiz), {'ا'});
    });

    test('madd lazim (maddah before mushaddad, and huruf al-muqattaat)', () {
      expect(lettersByRule('ٱلضَّآلِّينَ', QuranTajweedRule.maddLazim), {'ا'});
      expect(lettersByRule('الٓمٓ', QuranTajweedRule.maddLazim), {'ل', 'م'});
    });

    test('madd sila sughra (small waw / small yeh on the heh)', () {
      expect(lettersByRule('لَهُۥ', QuranTajweedRule.maddSilaSughra), {'ه'});
      expect(lettersByRule('بِهِۦ', QuranTajweedRule.maddSilaSughra), {'ه'});
    });

    test('consonant waw/yaa with sukun or vowel are not madd', () {
      expect(lettersByRule('أَوْ', QuranTajweedRule.madd), isEmpty);
      expect(lettersByRule('غَيْرِ', QuranTajweedRule.madd), isEmpty);
    });

    test('qalqalah on sukun and ayah-final letters only', () {
      expect(lettersByRule('لَمْ يَلِدْ', QuranTajweedRule.qalqalah), {'د'});
      // Mid-ayah tanween and shadda are not qalqalah.
      expect(
        lettersByRule('قُلْ هُوَ ٱللَّهُ أَحَدٌ ثُمَّ', QuranTajweedRule.qalqalah),
        isEmpty,
      );
      expect(lettersByRule('رَبِّ ٱلْعَٰلَمِينَ', QuranTajweedRule.qalqalah), isEmpty);
      // Ayah-final qalqalah letter (kubra) is colored regardless of vowel.
      expect(lettersByRule('وَمَا خَلَقَ ذَكَرًا وَأُنثَىٰ ٱلسُّجُودِ', QuranTajweedRule.qalqalah), {'د'});
      expect(lettersByRule('قُلْ هُوَ ٱللَّهُ أَحَدٌ', QuranTajweedRule.qalqalah), {'د'});
    });

    test('ghunnah on mushaddad noon and meem', () {
      expect(lettersByRule('إِنَّ', QuranTajweedRule.ghunnah), {'ن'});
      expect(lettersByRule('فَأَمَّا', QuranTajweedRule.ghunnah), {'م'});
      expect(lettersByRule('وَمِنَ ٱلنَّاسِ', QuranTajweedRule.ghunnah), {'ن'});
    });

    test('idgham bighunnah (noon saakinah + ي ن م و) is two-part', () {
      // The noon/tanween is not pronounced (gray); the letter is green.
      expect(lettersByRule('مَن يَقُولُ', QuranTajweedRule.notPronounced), {'ن'});
      expect(lettersByRule('مَن يَقُولُ', QuranTajweedRule.ghunnah), {'ي'});
      expect(lettersByRule('مِن مُّوصٍ', QuranTajweedRule.notPronounced), {'ن'});
      expect(lettersByRule('مِن مُّوصٍ', QuranTajweedRule.ghunnah), {'م'});
    });

    test('iqlab is two-part (noon gray, following ب green)', () {
      expect(lettersByRule('مِن بَعْدِ', QuranTajweedRule.notPronounced), {'ن'});
      expect(lettersByRule('مِن بَعْدِ', QuranTajweedRule.iqlab), {'ب'});
    });

    test('idgham bila ghunnah (noon saakinah + ل ر)', () {
      expect(
        lettersByRule('يَكُن لَّهُ', QuranTajweedRule.idghamBilaGhunnah),
        {'ن', 'ل'},
      );
      expect(
        lettersByRule('مِن رَّبِّهِمْ', QuranTajweedRule.idghamBilaGhunnah),
        {'ن', 'ر'},
      );
    });

    test('ikhfa (noon saakinah + ikhfa letters)', () {
      expect(lettersByRule('أَنتُمْ', QuranTajweedRule.ikhfa), {'ن', 'ت'});
      expect(lettersByRule('إِن تَرَكَ', QuranTajweedRule.ikhfa), {'ن', 'ت'});
    });

    test('ikhfa across tanween fath support alif', () {
      expect(
        lettersByRule('إِثْمًا فَأَصْلَحَ', QuranTajweedRule.ikhfa),
        {'م', 'ا', 'ف'},
      );
    });

    test('ikhfa shafawi (meem saakinah + ب)', () {
      expect(
        lettersByRule('هُم بِمُؤْمِنِينَ', QuranTajweedRule.ikhfaShafawi),
        {'م', 'ب'},
      );
    });

    test('iqlab via small-meem marker', () {
      // Ayah-final the small-meem is tanween-at-stop: qalqalah kubra wins.
      expect(lettersByRule('أَحَدٌۢ', QuranTajweedRule.ghunnah), isEmpty);
      expect(lettersByRule('أَحَدٌۢ', QuranTajweedRule.qalqalah), {'د'});
      // Tanween + small meem before ب → two-part iqlab (gray noon, green ب).
      expect(lettersByRule('أَلِيمٌۢ بِمَا', QuranTajweedRule.notPronounced), {'م'});
      expect(lettersByRule('أَلِيمٌۢ بِمَا', QuranTajweedRule.iqlab), {'ب'});
    });

    test('izhar letters are not colored', () {
      expect(lettersByRule('أَنْعَمْتَ', QuranTajweedRule.madd), isEmpty);
      expect(lettersByRule('أَنْعَمْتَ', QuranTajweedRule.qalqalah), isEmpty);
      expect(lettersByRule('أَنْعَمْتَ', QuranTajweedRule.ikhfa), isEmpty);
      expect(lettersByRule('أَنْعَمْتَ', QuranTajweedRule.ghunnah), isEmpty);
    });

    test('idgham bila ghunnah across tanween fath support alif', () {
      expect(
        lettersByRule('خَيْرًا ٱلْوَصِيَّةُ', QuranTajweedRule.idghamBilaGhunnah),
        {'ر', 'ا', 'ٱ', 'ل'},
      );
    });

    test('empty and whitespace input is safe', () {
      expect(QuranTajweedAnalyzer.analyze(''), isEmpty);
      expect(QuranTajweedAnalyzer.analyze('   '), isEmpty);
      // Bare wasla alefs carry no tajweed rule.
      expect(QuranTajweedAnalyzer.analyze('ٱٱٱ'), isEmpty);
      expect(QuranTajweedAnalyzer.analyze('قَالَ'), isNotEmpty);
    });

    test('marks are within bounds and never on spaces', () {
      const text = 'فَمَنْ خَافَ مِن مُّوصٍ جَنَفًا أَوْ إِثْمًا فَأَصْلَحَ';
      final marks = QuranTajweedAnalyzer.analyze(text);
      for (final m in marks) {
        expect(m.start, inInclusiveRange(0, text.length - 1));
        expect(m.end, greaterThan(m.start));
        expect(m.end, lessThanOrEqualTo(text.length));
        for (var i = m.start; i < m.end; i++) {
          expect(text[i].trim(), isNotEmpty, reason: 'no space in a mark');
        }
      }
    });

    test('a combined real-ayah text detects all rules', () {
      const text = 'قَالَ لَهُۥ سَوَآءٌ عَلَيْهِمْ أَنتُمْ يَلِدْ '
          'يَكُن لَّهُ مِن مُّوصٍ هُم بِمُؤْمِنِينَ ٱلضَّآلِّينَ '
          'مِن بَعْدِ بِمَآ أُنزِلَ مَن يَقُولُ';
      final marks = QuranTajweedAnalyzer.analyze(text);
      final rules = marks.map((m) => m.rule).toSet();
      expect(rules, containsAll(QuranTajweedRule.values));
    });

    test('LRU cache survives eviction and stays correct', () {
      // More unique inputs than the cache capacity forces eviction; every
      // result must still be correct and well-bounded.
      const base = 'وَقُل رَّبِّ زِدْنِى عِلْمًا';
      for (var i = 0; i < 2500; i++) {
        final text = '$base $i';
        final marks = QuranTajweedAnalyzer.analyze(text);
        for (final m in marks) {
          expect(m.start, inInclusiveRange(0, text.length - 1));
          expect(m.end, greaterThan(m.start));
          expect(m.end, lessThanOrEqualTo(text.length));
        }
      }
      // Re-analysis of an earlier (evicted/re-added) input is still valid.
      expect(
        lettersByRule('يَكُن لَّهُ', QuranTajweedRule.idghamBilaGhunnah),
        {'ن', 'ل'},
      );
    });
  });
}
