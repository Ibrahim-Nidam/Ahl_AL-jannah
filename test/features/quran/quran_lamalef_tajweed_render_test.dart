import 'dart:io';

import 'package:ahl_jannah/features/quran/domain/entities/quran_entities.dart';
import 'package:ahl_jannah/features/quran/presentation/widgets/quran_ayah_span_builder.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

TapGestureRecognizer _recognizer() => TapGestureRecognizer()..onTap = () {};

AyahEntity _ayah(String text) => AyahEntity(
      id: 22,
      surahId: 2,
      number: 2,
      page: 2,
      juz: 1,
      hizb: 1,
      textAr: text,
      translationEn: '',
      translationFr: '',
    );

/// Renders traced ink pixels (any alpha, thresholded to drop antialiased
/// fringes) for the given ayah spans with the real Uthmani Hafs v2 font.
Future<int> _inkCount(WidgetTester tester, String keyName,
    List<InlineSpan> spans) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: RepaintBoundary(
          key: Key(keyName),
          child: SizedBox(
            width: 1500,
            height: 150,
            child: Text.rich(
              TextSpan(children: spans),
              textAlign: TextAlign.right,
            ),
          ),
        ),
      ),
    ),
  );
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(Key(keyName)),
  );
  final image = await tester.runAsync(() => boundary.toImage());
  final bytes = (await tester.runAsync(() => image!.toByteData()))!;
  var ink = 0;
  for (var i = 0; i < bytes.lengthInBytes; i += 4) {
    if (bytes.getUint8(i + 3) > 40 &&
        bytes.getUint8(i) * 0.3 +
                bytes.getUint8(i + 1) * 0.59 +
                bytes.getUint8(i + 2) * 0.11 <
            220) {
      ink++;
    }
  }
  image?.dispose();
  return ink;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final bytes = File('assets/fonts/uthmanic-hafs-v22.ttf').readAsBytesSync();
    final loader = FontLoader('UthmanicHafs')
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
  });

  const txt = 'ذَلِكَ ٱلْكِتَـٰبُ لَا رَيْبَ ۛ فِيهِ ۛ هُدًى لِّلْمُتَّقِينَ';

  testWidgets('tajweed must not drop lam-alef ink', (tester) async {
    List<InlineSpan> build(bool tajweed) => QuranAyahSpanBuilder.build(
          ayahs: [_ayah(txt)],
          fontSize: 40,
          quranTextColor: Colors.black,
          accentColor: Colors.amber,
          selectedAyah: null,
          bookmarkedAyahKeys: const {},
          recognizerFor: (_) => _recognizer(),
          showTajweed: tajweed,
          fontFamily: 'UthmanicHafs',
          fontFamilyFallback: const ['Arial'],
        );

    final off = await _inkCount(tester, 'off', build(false));
    final on = await _inkCount(tester, 'on', build(true));

    // Tajweed only recolors letters; it must not remove glyph ink. A
    // broken lam-alef ligature (split across colored spans) drops the lam,
    // which shows up as an obvious ink loss vs the non-tajweed reference.
    expect(
      on,
      greaterThanOrEqualTo(off - 40),
      reason: 'tajweed lost lam/alef ink (off=$off on=$on)',
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}