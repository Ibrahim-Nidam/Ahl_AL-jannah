import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_intent_plus/android_intent.dart';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../prayer/data/repositories/prayer_notification_service.dart';
import '../../domain/entities/settings_entities.dart';
import '../bloc/settings_cubit.dart';


/// Settings page.
///
/// Exposes language selection plus the app-wide design system: theme
/// mode, color palette, and Quran font — each with a live preview, and
/// each applying instantly across the app via [SettingsCubit] since every
/// screen (see `app.dart`) rebuilds from the same persisted settings.
///
/// Also exposes the Adhkar Reminders toggles. These reuse
/// [PrayerNotificationService] (the app's single shared notification
/// engine) directly for instant cancellation when a toggle is switched
/// off; re-enabling takes effect on the next natural reschedule (opening
/// the Prayer tab, or the daily background task), since computing the
/// actual reminder time requires today's prayer times, which this page
/// does not load.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsPageTitle)),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          if (state is! SettingsLoadSuccess) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = state.settings;
          final currentLanguage = settings.language;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // ── Language ──
              _SectionHeader(
                title: l10n.languageSectionTitle,
                description: l10n.languageSectionDescription,
              ),
              const SizedBox(height: 8),
              _SelectableOptionTile(
                label: l10n.languageSystemOption,
                selected: currentLanguage == AppLanguage.system,
                onTap: () => context
                    .read<SettingsCubit>()
                    .setLanguage(AppLanguage.system),
              ),
              _SelectableOptionTile(
                // Language names are shown in each language's own native
                // form (standard language-picker convention), not
                // translated through the localization system.
                label: 'English',
                selected: currentLanguage == AppLanguage.en,
                onTap: () =>
                    context.read<SettingsCubit>().setLanguage(AppLanguage.en),
              ),
              _SelectableOptionTile(
                label: 'العربية',
                selected: currentLanguage == AppLanguage.ar,
                onTap: () =>
                    context.read<SettingsCubit>().setLanguage(AppLanguage.ar),
              ),
              _SelectableOptionTile(
                label: 'Français',
                selected: currentLanguage == AppLanguage.fr,
                onTap: () =>
                    context.read<SettingsCubit>().setLanguage(AppLanguage.fr),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 32),
              ),

              // ── Appearance ──
              _SectionHeader(
                title: l10n.appearanceSectionTitle,
                description: l10n.appearanceSectionDescription,
              ),
              const SizedBox(height: 12),

              // Live theme preview — reflects the current theme mode,
              // color palette, and Quran font all at once, and updates
              // immediately as any of them changes below.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ThemePreviewCard(
                  title: l10n.themePreviewTitle,
                  quranSample: l10n.basmala,
                  quranFont: settings.quranFont,
                ),
              ),
              const SizedBox(height: 20),

              // Theme mode
              _SubsectionLabel(text: l10n.themeModeSectionTitle),
              const SizedBox(height: 4),
              _SelectableOptionTile(
                leadingIcon: Icons.brightness_auto_rounded,
                label: l10n.themeModeSystemOption,
                selected: settings.themeMode == AppThemeMode.system,
                onTap: () => context
                    .read<SettingsCubit>()
                    .setThemeMode(AppThemeMode.system),
              ),
              _SelectableOptionTile(
                leadingIcon: Icons.light_mode_rounded,
                label: l10n.themeModeLightOption,
                selected: settings.themeMode == AppThemeMode.light,
                onTap: () => context
                    .read<SettingsCubit>()
                    .setThemeMode(AppThemeMode.light),
              ),
              _SelectableOptionTile(
                leadingIcon: Icons.dark_mode_rounded,
                label: l10n.themeModeDarkOption,
                selected: settings.themeMode == AppThemeMode.dark,
                onTap: () => context
                    .read<SettingsCubit>()
                    .setThemeMode(AppThemeMode.dark),
              ),

              const SizedBox(height: 20),

              // Color palette
              _SubsectionLabel(
                text: l10n.colorPaletteSectionTitle,
                description: l10n.colorPaletteSectionDescription,
              ),
              const SizedBox(height: 4),
              for (final palette in AppColorPalette.values)
                _PaletteOptionTile(
                  label: _paletteDisplayName(l10n, palette),
                  palette: palette,
                  selected: settings.colorPalette == palette,
                  onTap: () =>
                      context.read<SettingsCubit>().setColorPalette(palette),
                ),

              const SizedBox(height: 20),

              // Quran font
              _SubsectionLabel(
                text: l10n.quranFontSectionTitle,
                description: l10n.quranFontSectionDescription,
              ),
              const SizedBox(height: 4),
              for (final font in QuranFont.values)
                _QuranFontOptionTile(
                  label: _quranFontDisplayName(l10n, font),
                  font: font,
                  sampleText: l10n.basmala,
                  selected: settings.quranFont == font,
                  onTap: () => context.read<SettingsCubit>().setQuranFont(font),
                ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 32),
              ),

              // ── Adhkar Reminders ──
              _SectionHeader(
                title: l10n.adhkarRemindersSectionTitle,
                description: l10n.adhkarRemindersSectionDescription,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.morningAdhkarReminderOption),
                value: settings.morningAdhkarReminderEnabled,
                onChanged: (enabled) {
                  context
                      .read<SettingsCubit>()
                      .setMorningAdhkarReminderEnabled(enabled);
                  if (!enabled) {
                    getIt<PrayerNotificationService>()
                        .cancelAdhkarReminder(AdhkarReminderKind.morning);
                  }
                },
              ),
              SwitchListTile(
                title: Text(l10n.eveningAdhkarReminderOption),
                value: settings.eveningAdhkarReminderEnabled,
                onChanged: (enabled) {
                  context
                      .read<SettingsCubit>()
                      .setEveningAdhkarReminderEnabled(enabled);
                  if (!enabled) {
                    getIt<PrayerNotificationService>()
                        .cancelAdhkarReminder(AdhkarReminderKind.evening);
                  }
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 32),
              ),

              // ── Battery Optimization ──
              if (Platform.isAndroid) ...[
                _SectionHeader(
                  title: l10n.batteryOptimizationSectionTitle,
                  description: l10n.batteryOptimizationSectionDescription,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(l10n.batteryOptimizationDisableOption),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    try {
                      final intent = AndroidIntent(
                        action: 'android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS',
                        data: 'package:${AppConstants.orgName}',
                      );
                      await intent.launch();
                    } catch (e) {
                      debugPrint('Failed to open battery optimization settings: $e');
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 32),
              ),

              // ── Tasbeeh Feedback ──
              _SectionHeader(
                title: l10n.tasbeehSettingsSectionTitle,
                description: l10n.tasbeehSettingsSectionDescription,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: Text(l10n.tasbeehVibrateOnTapOption),
                subtitle: Text(l10n.tasbeehVibrateOnTapSubtitle),
                value: settings.tasbeehVibrateOnTap,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setTasbeehVibrateOnTap(enabled),
              ),
              SwitchListTile(
                title: Text(l10n.tasbeehStrongVibrateOption),
                subtitle: Text(l10n.tasbeehStrongVibrateSubtitle),
                value: settings.tasbeehStrongVibrateOnComplete,
                onChanged: (enabled) => context
                    .read<SettingsCubit>()
                    .setTasbeehStrongVibrateOnComplete(enabled),
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  static String _paletteDisplayName(
    AppLocalizations l10n,
    AppColorPalette palette,
  ) {
    switch (palette) {
      case AppColorPalette.classic:
        return l10n.paletteClassicName;
      case AppColorPalette.ocean:
        return l10n.paletteOceanName;
      case AppColorPalette.desert:
        return l10n.paletteDesertName;
    }
  }

  static String _quranFontDisplayName(AppLocalizations l10n, QuranFont font) {
    switch (font) {
      case QuranFont.uthmanic:
        return l10n.quranFontUthmanicName;
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SubsectionLabel extends StatelessWidget {
  const _SubsectionLabel({required this.text, this.description});

  final String text;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: Theme.of(context).textTheme.titleSmall),
          if (description != null) ...[
            const SizedBox(height: 2),
            Text(
              description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Generic single-select list tile used for language and theme-mode
/// options.
class _SelectableOptionTile extends StatelessWidget {
  const _SelectableOptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingIcon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: leadingIcon != null
          ? Icon(leadingIcon, color: colorScheme.onSurfaceVariant)
          : null,
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}

/// Color-palette option — shows a small swatch preview (primary / accent
/// / tertiary) built from the palette's *actual* resolved colors, so the
/// preview is always accurate even if palette values change later.
class _PaletteOptionTile extends StatelessWidget {
  const _PaletteOptionTile({
    required this.label,
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final AppColorPalette palette;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final swatch = AppPalettes.resolve(palette, brightness);

    return ListTile(
      leading: _PaletteSwatch(colors: swatch),
      title: Text(label),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  const _PaletteSwatch({required this.colors});

  final AppPaletteColors colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 32,
      child: Stack(
        children: [
          _dot(colors.primary, 0),
          _dot(colors.accent, 16),
          _dot(colors.tertiary, 32),
        ],
      ),
    );
  }

  Widget _dot(Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }
}

/// Quran font option — renders the sample text directly in that font so
/// the person can preview it before selecting it.
class _QuranFontOptionTile extends StatelessWidget {
  const _QuranFontOptionTile({
    required this.label,
    required this.font,
    required this.sampleText,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final QuranFont font;
  final String sampleText;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final paletteColors = Theme.of(context).extension<AppPaletteColors>();
    final quranTextColor = paletteColors?.quranText ?? colorScheme.onSurface;

    return ListTile(
      title: Text(label),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          sampleText,
          style: AppTextStyles.arabicBody(
            fontSize: 20,
            fontFamily: font.fontFamily,
            fontFamilyFallback: font.fontFamilyFallback,
          ).copyWith(color: quranTextColor),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
        ),
      ),
      trailing: selected
          ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
          : const Icon(Icons.circle_outlined),
      onTap: onTap,
    );
  }
}

/// Live preview card showing the currently applied theme mode, color
/// palette, and Quran font together — updates instantly whenever any of
/// them changes, since it reads straight from the active [ThemeData] and
/// the [QuranFont] passed in from the current settings state.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.title,
    required this.quranSample,
    required this.quranFont,
  });

  final String title;
  final String quranSample;
  final QuranFont quranFont;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paletteColors = theme.extension<AppPaletteColors>();
    final quranTextColor = paletteColors?.quranText ?? theme.colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            Text(
              quranSample,
              style: AppTextStyles.arabicQuran(
                fontSize: 24,
                fontFamily: quranFont.fontFamily,
                fontFamilyFallback: quranFont.fontFamilyFallback,
              ).copyWith(color: quranTextColor),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {},
                    child: Text(
                      theme.brightness == Brightness.light
                          ? '☀'
                          : '☾',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}