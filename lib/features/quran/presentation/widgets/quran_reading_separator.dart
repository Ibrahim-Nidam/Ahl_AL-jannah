/// Elegant, unobtrusive separators shown in the Quran reader when
/// crossing a Surah, Juz, or Hizb boundary. Used by both the portrait
/// (inline surah header only, via [QuranInlineSurahHeader] in the sibling
/// file) and landscape infinite-scroll readers, so there is exactly one
/// definition of what these markers look like.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/app_text_styles.dart';

enum QuranSeparatorKind { surah, juz, hizb }

class QuranReadingSeparator extends StatelessWidget {
  final QuranSeparatorKind kind;
  final String label;
  final String? arabicLabel;

  const QuranReadingSeparator({
    super.key,
    required this.kind,
    required this.label,
    this.arabicLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<AppPaletteColors>();
    final accent = palette?.accent ?? AppColors.accentGold;
    final divider = palette?.divider ?? AppColors.divider;

    final IconData icon;
    switch (kind) {
      case QuranSeparatorKind.surah:
        icon = Icons.menu_book_rounded;
        break;
      case QuranSeparatorKind.juz:
        icon = Icons.bookmark_border_rounded;
        break;
      case QuranSeparatorKind.hizb:
        icon = Icons.fiber_manual_record_outlined;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
      child: Row(
        children: [
          Expanded(child: Divider(color: divider, thickness: 0.8)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: accent),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: accent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
                if (arabicLabel != null && arabicLabel!.isNotEmpty)
                  Text(
                    arabicLabel!,
                    style: AppTextStyles.arabicBody(fontSize: 13).copyWith(
                      color: accent,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: Divider(color: divider, thickness: 0.8)),
        ],
      ),
    );
  }
}