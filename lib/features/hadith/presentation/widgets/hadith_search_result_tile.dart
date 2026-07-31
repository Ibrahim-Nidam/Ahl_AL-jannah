import 'package:ahl_jannah/features/settings/domain/entities/settings_entities.dart';
import 'package:ahl_jannah/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../quran/presentation/widgets/quran_ayah_span_builder.dart';
import '../../domain/entities/hadith_entities.dart';

/// One match from the global "search everything" query. Shows a short
/// preview of the hadith plus the collection/book it lives in.
class HadithSearchResultTile extends StatelessWidget {
  const HadithSearchResultTile({
    super.key,
    required this.result,
    required this.languageCode,
    required this.onTap,
  });

  final HadithSearchResult result;
  final String languageCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settingsState = context.watch<SettingsCubit>().state;
    final quranFont = settingsState is SettingsLoadSuccess
        ? settingsState.settings.quranFont
        : QuranFont.uthmanic;

    final item = result.item;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(60),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withAlpha(70)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(
                  QuranAyahSpanBuilder.stripUnnaturalTajweedMarks(item.arabic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      AppTextStyles.arabicBody(
                        fontSize: 18,
                        fontFamily: quranFont.fontFamily,
                        fontFamilyFallback: quranFont.fontFamilyFallback,
                      ).copyWith(
                        color: isDark
                            ? AppColors.onSurfaceDark
                            : AppColors.onSurfaceLight,
                        height: 1.7,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.english,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.library_books_rounded,
                    size: 14,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${result.author.titleFor(languageCode)} — '
                      '${result.book.titleFor(languageCode)} · '
                      '${l10n.hadithNumberLabel(item.id)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
