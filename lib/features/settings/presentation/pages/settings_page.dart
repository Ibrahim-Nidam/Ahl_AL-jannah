import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:share_plus/share_plus.dart';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/debug_access.dart';
import '../../../prayer/data/repositories/prayer_notification_service.dart';
import '../../../prayer/data/repositories/adhan_audio_player.dart';
import '../../../prayer/domain/entities/prayer_entities.dart';
import '../../../prayer/domain/usecases/prayer_usecases.dart';
import '../../../prayer/presentation/bloc/prayer_cubit.dart';
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
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    DebugAccess.loadUnlock().then((_) {
      if (mounted) setState(() {});
    });
  }

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
          final debugToolsUnlocked = DebugAccess.isUnlocked;

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
                onTap: () => context.read<SettingsCubit>().setLanguage(
                  AppLanguage.system,
                ),
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
                  quranFont: quranFontForRiwaya(settings.quranRiwaya),
                  arabicFontSize: settings.arabicFontSize,
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
                onTap: () => context.read<SettingsCubit>().setThemeMode(
                  AppThemeMode.system,
                ),
              ),
              _SelectableOptionTile(
                leadingIcon: Icons.light_mode_rounded,
                label: l10n.themeModeLightOption,
                selected: settings.themeMode == AppThemeMode.light,
                onTap: () => context.read<SettingsCubit>().setThemeMode(
                  AppThemeMode.light,
                ),
              ),
              _SelectableOptionTile(
                leadingIcon: Icons.dark_mode_rounded,
                label: l10n.themeModeDarkOption,
                selected: settings.themeMode == AppThemeMode.dark,
                onTap: () => context.read<SettingsCubit>().setThemeMode(
                  AppThemeMode.dark,
                ),
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

              // Quran riwaya (recitation)
              _SubsectionLabel(
                text: l10n.quranRiwayaSectionTitle,
                description: l10n.quranRiwayaSectionDescription,
              ),
              const SizedBox(height: 4),
              for (final riwaya in QuranRiwaya.values)
                _SelectableOptionTile(
                  label: _quranRiwayaDisplayName(l10n, riwaya),
                  selected: settings.quranRiwaya == riwaya,
                  onTap: () =>
                      context.read<SettingsCubit>().setQuranRiwaya(riwaya),
                ),

              const SizedBox(height: 20),

              // Arabic reading font size (Quran, Hadith, Adhkar)
              _SubsectionLabel(
                text: l10n.arabicFontSizeSectionTitle,
                description: l10n.arabicFontSizeSectionDescription,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: settings.arabicFontSize,
                        min: AppConstants.minArabicFontSize,
                        max: AppConstants.maxArabicFontSize,
                        divisions:
                            (AppConstants.maxArabicFontSize -
                                    AppConstants.minArabicFontSize)
                                .round(),
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(50),
                        onChanged: (value) => context
                            .read<SettingsCubit>()
                            .setArabicFontSize(value),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        l10n.quranArabicFontSize(
                          settings.arabicFontSize.round(),
                        ),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
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
                  context.read<SettingsCubit>().setMorningAdhkarReminderEnabled(
                    enabled,
                  );
                  if (!enabled) {
                    getIt<PrayerNotificationService>().cancelAdhkarReminder(
                      AdhkarReminderKind.morning,
                    );
                  }
                },
              ),
              SwitchListTile(
                title: Text(l10n.eveningAdhkarReminderOption),
                value: settings.eveningAdhkarReminderEnabled,
                onChanged: (enabled) {
                  context.read<SettingsCubit>().setEveningAdhkarReminderEnabled(
                    enabled,
                  );
                  if (!enabled) {
                    getIt<PrayerNotificationService>().cancelAdhkarReminder(
                      AdhkarReminderKind.evening,
                    );
                  }
                },
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(height: 32),
              ),

              // ── Prayer Alerts (notifications vs sound are independent) ──
              _SectionHeader(
                title: l10n.prayerAlertsSectionTitle,
                description: l10n.prayerAlertsSectionDescription,
              ),
              const SizedBox(height: 8),
              const _PrayerAlertsSection(),

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
                        action:
                            'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
                      );
                      await intent.launch();
                    } catch (e) {
                      debugPrint(
                        'Failed to open battery optimization settings: $e',
                      );
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

              // ── Debug Tools (hidden; unlock via the About dialog) ──
              if (debugToolsUnlocked) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 32),
                ),
                _SectionHeader(
                  title: 'Debug Tools',
                  description:
                      'Test adhan sound and view logs for troubleshooting',
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.volume_up_rounded),
                  title: const Text('Test Adhan Sound'),
                  subtitle: const Text('Play adhan to test audio playback'),
                  trailing: const Icon(Icons.play_arrow_rounded),
                  onTap: () async {
                    try {
                      final audioPlayer = getIt<AdhanAudioPlayer>();
                      AppLogger.info(
                        'Manual adhan test triggered from settings',
                      );
                      await audioPlayer.playAdhan('fajr', settings.adhanType);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Playing adhan...')),
                        );
                      }
                    } catch (e) {
                      AppLogger.error('Failed to play test adhan', error: e);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded),
                  title: const Text('Test Scheduled Notification (5s)'),
                  subtitle: const Text(
                    'Triggers real system notification in 5s',
                  ),
                  trailing: const Icon(Icons.alarm_rounded),
                  onTap: () async {
                    try {
                      final notifService = getIt<PrayerNotificationService>();
                      await notifService.scheduleTestAdhanNotification(
                        settings.adhanType,
                        secondsDelay: 5,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Test Adhan notification scheduled in 5 seconds! Lock your screen or wait...',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      AppLogger.error(
                        'Failed to schedule test adhan notification',
                        error: e,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report_rounded),
                  title: const Text('View Logs'),
                  subtitle: const Text('View recent app logs for debugging'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const _LogViewerPage(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.share_rounded),
                  title: const Text('Share Logs'),
                  subtitle: const Text('Export and share logs for support'),
                  trailing: const Icon(Icons.ios_share),
                  onTap: () async {
                    try {
                      final logPath = await AppLogger.exportLogsToFile();
                      if (logPath != null && context.mounted) {
                        await Share.shareXFiles([
                          XFile(logPath),
                        ], text: 'Ahl Jannah Debug Logs');
                        AppLogger.info('Logs shared successfully');
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Failed to export logs'),
                          ),
                        );
                      }
                    } catch (e) {
                      AppLogger.error('Failed to share logs', error: e);
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_rounded),
                  title: const Text('Clear Logs'),
                  subtitle: const Text('Clear all stored logs'),
                  trailing: const Icon(Icons.clear),
                  onTap: () async {
                    await AppLogger.clearLogs();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logs cleared')),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.visibility_off_rounded),
                  title: const Text('Hide Debug Tools'),
                  subtitle: const Text('Hide the debug tools again'),
                  trailing: const Icon(Icons.lock_outline_rounded),
                  onTap: () async {
                    await DebugAccess.resetUnlock();
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 8),
              ],
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

  static String _quranRiwayaDisplayName(
    AppLocalizations l10n,
    QuranRiwaya riwaya,
  ) {
    switch (riwaya) {
      case QuranRiwaya.hafsAnAsim:
        return l10n.quranRiwayaHafsName;
      case QuranRiwaya.warsh:
        return l10n.quranRiwayaWarshName;
    }
  }
}

/// Prayer notification vs sound controls for the Settings page.
///
/// These mirror the toggles in the Prayer tab's bottom sheet: notifications
/// and adhan sound are fully independent, so a user can keep getting prayer
/// alerts without any sound. Changes persist via [PrayerCubit] (which
/// reschedules immediately) so they work whether or not the Prayer tab has
/// been opened yet.
class _PrayerAlertsSection extends StatefulWidget {
  const _PrayerAlertsSection();

  @override
  State<_PrayerAlertsSection> createState() => _PrayerAlertsSectionState();
}

class _PrayerAlertsSectionState extends State<_PrayerAlertsSection> {
  PrayerTimesSettings? _settings;
  bool _loading = true;
  bool? _exactAlarmsEnabled;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await getIt<GetPrayerSettingsUseCase>()();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _loading = false;
    });
    await _updateExactAlarmStatus();
  }

  Future<void> _updateExactAlarmStatus() async {
    if (!Platform.isAndroid || !mounted) return;
    final enabled = await getIt<PrayerNotificationService>()
        .canScheduleExactAlarms();
    if (!mounted) return;
    setState(() => _exactAlarmsEnabled = enabled);
  }

  Future<void> _apply(PrayerTimesSettings newSettings) async {
    setState(() => _settings = newSettings);
    await getIt<PrayerCubit>().applyPrayerSettings(newSettings);
  }

  Future<void> _openExactAlarmSettings() async {
    if (!Platform.isAndroid || !mounted) return;
    try {
      final intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
        data: 'package:${AppConstants.orgName}',
      );
      await intent.launch();
      // Re-check after the user returns from the system settings screen.
      await _updateExactAlarmStatus();
    } catch (e) {
      debugPrint('Failed to open exact alarm settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final settings = _settings ?? PrayerTimesSettings.defaultSettings();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: Text(l10n.prayerEnableNotifications),
          subtitle: Text(l10n.prayerEnableNotificationsSubtitle),
          value: settings.notificationsEnabled,
          onChanged: (enabled) =>
              _apply(settings.copyWith(notificationsEnabled: enabled)),
        ),
        SwitchListTile(
          title: Text(l10n.prayerAdhanSoundToggle),
          subtitle: Text(l10n.prayerAdhanSoundToggleSubtitle),
          value: settings.adhanSoundEnabled,
          onChanged: (enabled) =>
              _apply(settings.copyWith(adhanSoundEnabled: enabled)),
        ),
        _SubsectionLabel(text: l10n.prayerReminderBefore),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 5, label: Text(l10n.prayerReminder5Min)),
              ButtonSegment(value: 15, label: Text(l10n.prayerReminder15Min)),
            ],
            selected: {settings.reminderInterval},
            onSelectionChanged: (selection) =>
                _apply(settings.copyWith(reminderInterval: selection.first)),
          ),
        ),
        const SizedBox(height: 8),
        if (Platform.isAndroid) ...[
          ListTile(
            leading: Icon(
              _exactAlarmsEnabled == true
                  ? Icons.verified_rounded
                  : Icons.warning_amber_rounded,
              color: _exactAlarmsEnabled == true
                  ? colorScheme.primary
                  : colorScheme.error,
            ),
            title: Text(l10n.prayerExactAlarmTileTitle),
            subtitle: Text(
              _exactAlarmsEnabled == true
                  ? l10n.prayerExactAlarmEnabled
                  : l10n.prayerExactAlarmDisabled,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _openExactAlarmSettings,
          ),
        ],
      ],
    );
  }
}

class _LogViewerPage extends StatefulWidget {
  const _LogViewerPage();

  @override
  State<_LogViewerPage> createState() => _LogViewerPageState();
}

class _LogViewerPageState extends State<_LogViewerPage> {
  final ScrollController _scrollController = ScrollController();
  List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = AppLogger.getLogs();
    setState(() {
      _logs = logs;
    });
    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs),
        ],
      ),
      body: _logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No logs available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                // Color code based on log level
                Color logColor = Colors.black87;
                if (log.contains('[ERROR]')) {
                  logColor = Colors.red;
                } else if (log.contains('[WARNING]')) {
                  logColor = Colors.orange;
                } else if (log.contains('[INFO]')) {
                  logColor = Colors.blue;
                } else if (log.contains('[DEBUG]')) {
                  logColor = Colors.grey;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: logColor,
                    ),
                  ),
                );
              },
            ),
    );
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

/// Live preview card showing the currently applied theme mode, color
/// palette, and Quran font together — updates instantly whenever any of
/// them changes, since it reads straight from the active [ThemeData] and
/// the [QuranFont] passed in from the current settings state.
class _ThemePreviewCard extends StatelessWidget {
  const _ThemePreviewCard({
    required this.title,
    required this.quranSample,
    required this.quranFont,
    required this.arabicFontSize,
  });

  final String title;
  final String quranSample;
  final QuranFont quranFont;
  final double arabicFontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paletteColors = theme.extension<AppPaletteColors>();
    final quranTextColor =
        paletteColors?.quranText ?? theme.colorScheme.onSurface;

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
                fontSize: arabicFontSize,
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
                      theme.brightness == Brightness.light ? '☀' : '☾',
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
