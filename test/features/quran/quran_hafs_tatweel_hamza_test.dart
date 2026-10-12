import 'package:ahl_jannah/features/quran/presentation/widgets/quran_ayah_span_builder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('stripUnnaturalTajweedMarks preserves Tatweel carrier before Hamza in Hafs text', () {
    // 1) Test known Hafs words containing Tatweel before Hamza
    const sampleWord = 'شَيْـًٔا'; // U+0634 U+064E U+064A U+0652 U+0640 U+0654 U+064B U+0627
    final cleanedWord = QuranAyahSpanBuilder.stripUnnaturalTajweedMarks(sampleWord, warsh: false);
    
    expect(
      cleanedWord,
      contains('\u0640\u0654'),
      reason: 'Tatweel carrier before Hamza (\u0640\u0654) must be preserved so Yae is not destroyed during font rendering',
    );

    // 2) Verify across whole Hafs database
    final db = sqlite3.open('assets/quran.db');
    final rows = db.select('SELECT text_ar FROM ayahs');

    var totalWithTatweelHamza = 0;
    var totalPreserved = 0;

    for (final row in rows) {
      final text = row['text_ar'] as String;
      if (text.contains('\u0640\u0654') || text.contains('\u0640\u0655')) {
        totalWithTatweelHamza++;
        final stripped = QuranAyahSpanBuilder.stripUnnaturalTajweedMarks(text, warsh: false);
        if (stripped.contains('\u0640\u0654') || stripped.contains('\u0640\u0655')) {
          totalPreserved++;
        }
      }
    }

    expect(totalWithTatweelHamza, greaterThan(700));
    expect(totalPreserved, equals(totalWithTatweelHamza));

    db.dispose();
  });
}
