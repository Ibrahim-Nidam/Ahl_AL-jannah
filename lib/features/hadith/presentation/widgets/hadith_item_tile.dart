import 'package:ahl_jannah/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../quran/presentation/widgets/quran_ayah_span_builder.dart';
import '../../domain/entities/hadith_entities.dart';

/// Renders a single hadith as a card: the Arabic text is always visible;
/// the English translation stays hidden until the user taps the "Show
/// translation" button (per hadith). The Arabic is rendered in the
/// user's selected [QuranFont].
class HadithItemTile extends StatefulWidget {
  const HadithItemTile({super.key, required this.hadith});

  final HadithItem hadith;

  @override
  State<HadithItemTile> createState() => _HadithItemTileState();
}

class _HadithItemTileState extends State<HadithItemTile> {
  bool _showTranslation = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final settingsState = context.watch<SettingsCubit>().state;
    final arabicFontSize = settingsState is SettingsLoadSuccess
        ? settingsState.settings.arabicFontSize
        : 28.0;

    final hadith = widget.hadith;
    final grade = hadith.grade.trim();

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
              if (grade.isNotEmpty)
                Expanded(
                  child: Text(
                    grade,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              else
                const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withAlpha(35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  l10n.hadithNumberLabel(hadith.id),
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
              QuranAyahSpanBuilder.stripUnnaturalTajweedMarks(hadith.arabic),
              textAlign: TextAlign.justify,
              style:
                  AppTextStyles.arabicBody(
                    fontSize: arabicFontSize,
                  ).copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurfaceLight,
                    height: 1.9,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  setState(() => _showTranslation = !_showTranslation),
              icon: Icon(
                _showTranslation
                    ? Icons.visibility_off_rounded
                    : Icons.translate_rounded,
                size: 18,
              ),
              label: Text(
                _showTranslation
                    ? l10n.hadithHideTranslation
                    : l10n.hadithShowTranslation,
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: colorScheme.primary,
              ),
            ),
          ),
          if (_showTranslation) ...[
            const Divider(height: 12),
            Text(
              hadith.english,
              style: AppTextStyles.bodyMedium.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
