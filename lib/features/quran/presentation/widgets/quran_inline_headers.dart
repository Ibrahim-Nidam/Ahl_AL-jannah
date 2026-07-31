/// Inline (non-boxed) Surah header and Bismillah widgets used at the
/// start of a new Surah — shared by both the portrait "real Mushaf" page
/// and the landscape infinite-scroll reader, so the visual treatment of a
/// new Surah's opening is defined in exactly one place.
library;

import 'package:flutter/material.dart';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/quran_entities.dart';

String quranRevelationLabel(AppLocalizations l10n, String revelation) {
  switch (revelation.toLowerCase()) {
    case 'meccan':
      return l10n.quranRevelationMeccan;
    case 'medinan':
      return l10n.quranRevelationMedinan;
    default:
      return revelation;
  }
}

class QuranInlineSurahHeader extends StatelessWidget {
  final SurahEntity surah;
  final Color accent;
  final String fontFamily;
  final List<String> fontFamilyFallback;

  const QuranInlineSurahHeader({
    super.key,
    required this.surah,
    required this.accent,
    this.fontFamily = 'Lateef',
    this.fontFamilyFallback = const ['Noto Naskh Arabic', 'Scheherazade New', 'Arial'],
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            surah.nameAr,
            style: AppTextStyles.arabicHeading(
              fontSize: 26,
              fontFamily: fontFamily,
              fontFamilyFallback: fontFamilyFallback,
            ).copyWith(color: accent),
          ),
          const SizedBox(height: 4),
          Text(
            '${surah.nameEn} • ${quranRevelationLabel(l10n, surah.revelation)}',
            style: AppTextStyles.caption.copyWith(color: accent, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Container(height: 1, width: 60, color: accent.withAlpha(150)),
        ],
      ),
    );
  }
}

class QuranInlineBismillah extends StatelessWidget {
  final Color color;
  final String fontFamily;
  final List<String> fontFamilyFallback;

  const QuranInlineBismillah({
    super.key,
    required this.color,
    this.fontFamily = 'Lateef',
    this.fontFamilyFallback = const ['Noto Naskh Arabic', 'Scheherazade New', 'Arial'],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
        style: AppTextStyles.arabicQuran(
          fontSize: 30,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
        ).copyWith(color: color),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        locale: const Locale('ar'),
      ),
    );
  }
}