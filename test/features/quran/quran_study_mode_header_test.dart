import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ahl_jannah/core/di/injection.dart';
import 'package:ahl_jannah/features/quran/domain/entities/quran_entities.dart';
import 'package:ahl_jannah/features/quran/presentation/cubit/quran_cubit.dart';
import 'package:ahl_jannah/features/quran/presentation/widgets/quran_inline_headers.dart';
import 'package:ahl_jannah/features/quran/presentation/widgets/quran_mushaf_page_view.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

class _FakeQuranCubit extends Fake implements QuranCubit {
  final List<AyahEntity> ayahs;

  _FakeQuranCubit(this.ayahs);

  @override
  Future<List<AyahEntity>> getAyahsByPage(int page) async => ayahs;

  @override
  Future<List<AyahEntity>> getWarshAyahsByPage(int page) async => ayahs;

  @override
  Future<Map<int, int>> getWarshSurahAyahCounts() async => {};
}

void main() {
  const dummySurahs = [
    SurahEntity(
      id: 1,
      nameAr: 'الفاتحة',
      nameEn: 'Al-Fatihah',
      revelation: 'Meccan',
      ayahCount: 7,
    ),
    SurahEntity(
      id: 2,
      nameAr: 'البقرة',
      nameEn: 'Al-Baqarah',
      revelation: 'Medinan',
      ayahCount: 286,
    ),
    SurahEntity(
      id: 9,
      nameAr: 'التوبة',
      nameEn: 'At-Tawbah',
      revelation: 'Medinan',
      ayahCount: 129,
    ),
    SurahEntity(
      id: 112,
      nameAr: 'الإخلاص',
      nameEn: 'Al-Ikhlas',
      revelation: 'Meccan',
      ayahCount: 4,
    ),
    SurahEntity(
      id: 113,
      nameAr: 'الفلق',
      nameEn: 'Al-Falaq',
      revelation: 'Meccan',
      ayahCount: 5,
    ),
  ];

  Widget buildTestWidget(List<AyahEntity> pageAyahs, int pageNumber) {
    if (getIt.isRegistered<QuranCubit>()) {
      getIt.unregister<QuranCubit>();
    }
    getIt.registerSingleton<QuranCubit>(_FakeQuranCubit(pageAyahs));

    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      locale: const Locale('en'),
      home: Scaffold(
        body: QuranMushafPageView(
          pageNumber: pageNumber,
          fontSize: 22,
          showTranslation: true,
          translationLang: 'en',
          readerMode: 'study',
          showTajweed: false,
          selectedAyah: null,
          allSurahs: dummySurahs,
          onAyahTapped: (_) {},
          onPageMetadataLoaded: (_, __, ___, ____) {},
          bookmarkedAyahKeys: const {},
        ),
      ),
    );
  }

  tearDown(() {
    if (getIt.isRegistered<QuranCubit>()) {
      getIt.unregister<QuranCubit>();
    }
  });

  testWidgets('renders surah header and basmala before card 1 in study mode', (tester) async {
    final ayahs = [
      const AyahEntity(
        id: 1,
        surahId: 1,
        number: 1,
        textAr: 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ',
        translationEn: 'In the name of Allah',
        juz: 1,
        page: 1,
        hizb: 1,
      ),
      const AyahEntity(
        id: 2,
        surahId: 1,
        number: 2,
        textAr: 'ٱلْحَمْدُ لِلَّهِ رَبِّ ٱلْعَٰلَمِينَ',
        translationEn: 'Praise be to Allah',
        juz: 1,
        page: 1,
        hizb: 1,
      ),
    ];

    await tester.pumpWidget(buildTestWidget(ayahs, 1));
    await tester.pumpAndSettle();

    expect(find.byType(QuranInlineSurahHeader), findsOneWidget);
    expect(find.byType(QuranInlineBismillah), findsOneWidget);
    expect(find.text('الفاتحة'), findsOneWidget);
  });

  testWidgets('omits basmala for Surah At-Tawbah (9) in study mode', (tester) async {
    final ayahs = [
      const AyahEntity(
        id: 1200,
        surahId: 9,
        number: 1,
        textAr: 'بَرَآءَةٌ مِّنَ ٱللَّهِ وَرَسُولِهِۦٓ',
        translationEn: 'Freedom from obligation from Allah',
        juz: 10,
        page: 187,
        hizb: 19,
      ),
    ];

    await tester.pumpWidget(buildTestWidget(ayahs, 187));
    await tester.pumpAndSettle();

    expect(find.byType(QuranInlineSurahHeader), findsOneWidget);
    expect(find.text('التوبة'), findsOneWidget);
    expect(find.byType(QuranInlineBismillah), findsNothing);
  });

  testWidgets('renders separation, new surah name, and basmala between surahs on same page', (tester) async {
    final ayahs = [
      const AyahEntity(
        id: 6200,
        surahId: 112,
        number: 4,
        textAr: 'وَلَمْ يَكُن لَّهُۥ كُفُوًا أَحَدٌۢ',
        translationEn: 'Nor is there to Him any equivalent.',
        juz: 30,
        page: 604,
        hizb: 60,
      ),
      const AyahEntity(
        id: 6201,
        surahId: 113,
        number: 1,
        textAr: 'قُلْ أَعُوذُ بِرَبِّ ٱلْفَلَقِ',
        translationEn: 'Say, "I seek refuge in the Lord of daybreak"',
        juz: 30,
        page: 604,
        hizb: 60,
      ),
    ];

    await tester.pumpWidget(buildTestWidget(ayahs, 604));
    await tester.pumpAndSettle();

    expect(find.byType(QuranInlineSurahHeader), findsOneWidget);
    expect(find.text('الفلق'), findsOneWidget);
    expect(find.byType(QuranInlineBismillah), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });

  testWidgets('renders separation divider after last ayah of a surah when at end of page', (tester) async {
    final ayahs = [
      const AyahEntity(
        id: 7,
        surahId: 1,
        number: 7,
        textAr: 'صِرَٰطَ ٱلَّذِينَ أَنْعَمْتَ عَلَيْهِمْ غَيْرِ ٱلْمَغْضُوبِ عَلَيْهِمْ وَلَا ٱلضَّآلِّينَ',
        translationEn: 'The path of those upon whom You have bestowed favor...',
        juz: 1,
        page: 1,
        hizb: 1,
      ),
    ];

    await tester.pumpWidget(buildTestWidget(ayahs, 1));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byType(QuranInlineSurahHeader), findsNothing);
  });
}
