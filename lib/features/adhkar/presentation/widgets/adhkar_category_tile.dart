import 'package:flutter/material.dart';

import 'package:ahl_jannah/core/theme/app_colors.dart';
import 'package:ahl_jannah/core/theme/app_text_styles.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../domain/entities/adhkar_entities.dart';

/// Compact category row for the main Adhkar catalog list.
class AdhkarCategoryTile extends StatelessWidget {
  final AdhkarCategory category;
  final String languageCode;
  final int index;
  final VoidCallback onTap;

  const AdhkarCategoryTile({
    super.key,
    required this.category,
    required this.languageCode,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = category.displayName(languageCode);
    final isArabicUi = languageCode == 'ar';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  textAlign: isArabicUi ? TextAlign.right : TextAlign.left,
                  textDirection:
                      isArabicUi ? TextDirection.rtl : TextDirection.ltr,
                  style: isArabicUi
                      ? AppTextStyles.arabicHeading(fontSize: 17).copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                          fontWeight: FontWeight.w600,
                        )
                      : AppTextStyles.bodyLarge.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                          fontWeight: FontWeight.w600,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${category.itemCount}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDarkVariant
                      : AppColors.onSurfaceLightVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large Morning / Evening entry points at the top of the catalog.
class AdhkarFeaturedCategoryCard extends StatelessWidget {
  final AdhkarCategory category;
  final String languageCode;
  final bool isEvening;
  final VoidCallback onTap;

  const AdhkarFeaturedCategoryCard({
    super.key,
    required this.category,
    required this.languageCode,
    required this.isEvening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = category.displayName(languageCode);
    final colors = isEvening
        ? [AppColors.teal, AppColors.primaryGreenDark]
        : const [AppColors.primaryGreen, AppColors.primaryGreenDark];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Icon(
                  isEvening
                      ? Icons.nights_stay_rounded
                      : Icons.wb_sunny_rounded,
                  color: Colors.white.withValues(alpha: 0.95),
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: languageCode == 'ar'
                            ? AppTextStyles.arabicHeading(fontSize: 18).copyWith(
                                color: Colors.white,
                              )
                            : AppTextStyles.headingSmall.copyWith(
                                color: Colors.white,
                              ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.adhkarCountInCategory(category.itemCount),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.85),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
