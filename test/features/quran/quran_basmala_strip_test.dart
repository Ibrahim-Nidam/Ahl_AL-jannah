import 'package:ahl_jannah/features/quran/presentation/widgets/quran_ayah_span_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuranAyahSpanBuilder.formatAyahText basmala stripping', () {
    test('Al-Fatihah (1) strips the embedded basmala', () {
      final text = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
      expect(QuranAyahSpanBuilder.formatAyahText(1, 1, text), isEmpty);
    });

    test('strips basmala before the actual first ayah text', () {
      // Real DB strings — contain tatweel (ـ, U+0640) inside الله and الرحمن.
      final text = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ الٓمٓ';
      final result = QuranAyahSpanBuilder.formatAyahText(2, 1, text);
      expect(result, 'الٓمٓ');
      expect(result.contains('بِسْمِ'), isFalse);
    });

    test('strips basmala from a full-word surah opening', () {
      final text =
          'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ يَـٰٓأَيُّهَا ٱلنَّاسُ ٱتَّقُو';
      final result = QuranAyahSpanBuilder.formatAyahText(4, 1, text);
      expect(
        result.startsWith(
          QuranAyahSpanBuilder.stripUnnaturalTajweedMarks('يَـٰٓأَيُّهَا'),
        ),
        isTrue,
      );
      expect(result.contains('بِسْمِ'), isFalse);
    });

    test('At-Tawbah (9) is never stripped', () {
      final text = 'بَرَآءَةٌ مِّنَ ٱللَّهِ وَرَسُولِهِۦٓ';
      final result = QuranAyahSpanBuilder.formatAyahText(9, 1, text);
      expect(result, text);
    });

    test('non-first ayahs are never touched', () {
      final text = 'ٱلَّذِينَ يُؤْمِنُونَ بِٱلْغَيْبِ';
      expect(QuranAyahSpanBuilder.formatAyahText(2, 3, text), text);
    });

    test(
      'Warsh preserves the orthographic rounded-zero mark in Yusuf 12:90',
      () {
        const text =
            'قَالُوٓاْ أَ۟نَّكَ لَأَنتَ يُوسُفُۖ قَالَ أَنَا يُوسُفُ '
            'وَهَٰذَآ أَخِےۖ قَدْ مَنَّ اَ۬للَّهُ عَلَيْنَآۖ إِنَّهُۥ '
            'مَنْ يَّتَّقِ وَيَصْبِرْ فَإِنَّ اَ۬للَّهَ لَا يُضِيعُ أَجْرَ '
            'اَ۬لْمُحْسِنِينَۖ';

        expect(
          QuranAyahSpanBuilder.formatAyahText(12, 90, text, warsh: true),
          text,
        );
        expect(
          QuranAyahSpanBuilder.formatAyahText(12, 90, text),
          text.replaceAll('۟', ''),
        );
      },
    );
  });
}
