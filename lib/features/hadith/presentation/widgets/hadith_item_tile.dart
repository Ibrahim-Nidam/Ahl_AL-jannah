import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/hadith_entities.dart';

/// Renders a single hadith as a card: Arabic text (RTL, justified) with a
/// number badge, and — when [collectionTitle] is provided (global search
/// results) — a small source-collection label above the text.
class HadithItemTile extends StatelessWidget {
  const HadithItemTile({
    super.key,
    required this.hadith,
    required this.isDark,
    this.collectionTitle,
  });

  final HadithEntity hadith;
  final bool isDark;
  final String? collectionTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(60),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (collectionTitle != null)
                Expanded(
                  child: Text(
                    collectionTitle!,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withAlpha(35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.hadithNumberLabel(hadith.number),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentGoldDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Text(
              hadith.text,
              textAlign: TextAlign.justify,
              style: AppTextStyles.arabicBody(fontSize: 20).copyWith(
                color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                height: 1.9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}