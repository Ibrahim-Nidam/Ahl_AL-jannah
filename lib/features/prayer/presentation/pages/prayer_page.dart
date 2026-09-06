import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/adhan_audio_player.dart';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/extensions.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../data/repositories/prayer_notification_service.dart';
import '../../domain/entities/prayer_entities.dart';
import '../../domain/usecases/prayer_usecases.dart';
import '../bloc/prayer_cubit.dart';

String _prayerDisplayName(AppLocalizations l10n, String englishName) {
  switch (englishName) {
    case 'Fajr':
      return l10n.prayerNameFajr;
    case 'Sunrise':
      return l10n.prayerNameSunrise;
    case 'Dhuhr':
      return l10n.prayerNameDhuhr;
    case 'Asr':
      return l10n.prayerNameAsr;
    case 'Maghrib':
      return l10n.prayerNameMaghrib;
    case 'Isha':
      return l10n.prayerNameIsha;
    default:
      return englishName;
  }
}

class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});

  @override
  State<PrayerPage> createState() => _PrayerPageState();
}

class _PrayerPageState extends State<PrayerPage>
    with AutomaticKeepAliveClientMixin<PrayerPage>, WidgetsBindingObserver {
  late final PrayerCubit _cubit;

  @override
  bool get wantKeepAlive => true;

  /// The prayer key whose Adhan the user manually stopped, so the "Adhan
  /// is playing" banner doesn't immediately reappear for the rest of the
  /// time window even though the window itself hasn't elapsed yet. It is
  /// restored from [PrayerNotificationService.readManualAdhanStop] so a
  /// stop made from the notification shade (or in a previous app session)
  /// is honored too.
  String? _manuallyStoppedPrayerKey;

  /// Whether the persisted manual-stop state has been loaded. The build
  /// method must not auto-play an adhan before this is known, otherwise a
  /// stale stop could be replayed on a fresh cold start.
  bool _manualStopReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = getIt<PrayerCubit>();
    _loadManualAdhanStop();
    // Force-refresh location every time the user enters the prayer page.
    _cubit.loadPrayerTimes(forceRefresh: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) {
      // A manual stop made from the notification shade is often handled in a
      // background isolate where this app's audio player can't be reached, so
      // re-check the persisted stop when the app comes back to the foreground.
      _applyPersistedManualStop();
      // Re-verify exact alarm permission and reschedule if it was revoked.
      _checkExactAlarmsAndReschedule();
    }
  }

  /// Checks whether exact alarms are still permitted. If the user revoked
  /// the permission while the app was backgrounded, reschedule immediately
  /// so the next notification gets the correct schedule mode (exact vs inexact).
  Future<void> _checkExactAlarmsAndReschedule() async {
    try {
      final notificationService = getIt<PrayerNotificationService>();
      final canExact = await notificationService.canScheduleExactAlarms();
      if (!canExact) {
        // Reschedule so the schedule mode picks up the current permission state.
        // This won't fix the missing permission, but ensures we at least use
        // inexact mode consistently rather than a stale cached value.
        AppLogger.info('[PrayerPage] Exact alarm permission revoked — rescheduling with current mode');
        _cubit.loadPrayerTimes(forceRefresh: false);
      }
    } catch (_) {}
  }

  /// Loads the persisted manual-stop state. If an adhan is currently playing
  /// for the stopped prayer, it is stopped immediately so a stop made from
  /// the notification shade (handled in a background isolate) is honored.
  Future<void> _loadManualAdhanStop() async {
    final stoppedKey = await PrayerNotificationService.readManualAdhanStop();
    if (!mounted) return;
    setState(() {
      _manuallyStoppedPrayerKey = stoppedKey;
      _manualStopReady = true;
    });
    await _applyPersistedManualStop();
  }

  /// Stops in-app audio if it is still playing for the persisted
  /// manually-stopped prayer (the player may not have been reachable from the
  /// background isolate that handled the notification button).
  Future<void> _applyPersistedManualStop() async {
    final stoppedKey = await PrayerNotificationService.readManualAdhanStop();
    if (stoppedKey == null) return;
    try {
      final player = getIt<AdhanAudioPlayer>();
      if (player.isPlaying && player.currentPrayerKey == stoppedKey) {
        await player.stopAdhan();
      }
    } catch (_) {}
  }

  /// Starts playing the adhan audio in-app using AdhanAudioPlayer.
  /// Cancels the notification first to stop its native sound, preventing
  /// two audio sources from playing simultaneously, then re-shows a silent
  /// notification with the "Stop Adhan" button.
  Future<void> _startInAppAdhan(String prayerKey) async {
    try {
      final player = getIt<AdhanAudioPlayer>();
      if (player.isPlaying && player.currentPrayerKey == prayerKey) return;

      // Respect the user's per-prayer sound choice — never play the audio
      // in-app for a prayer that has been silenced.
      final prayerState = _cubit.state;
      if (prayerState is PrayerLoadSuccess &&
          !prayerState.settings.prayerHasSound(prayerKey)) {
        return;
      }

      final l10n = AppLocalizations.of(context);
      final settingsState = context.read<SettingsCubit>().state;
      final adhanType = settingsState is SettingsLoadSuccess
          ? settingsState.settings.adhanType
          : AdhanType.full;

      // Kill the notification sound FIRST — this is the fragile one that
      // stops when the shade is pulled down. AdhanAudioPlayer will take over.
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.cancel(PrayerNotificationIds.adhanId(prayerKey));
      await plugin.cancel(9999); // test notification

      await player.playAdhan(prayerKey, adhanType);

      if (!mounted) return;

      // Re-show a SILENT ongoing notification with the "Stop Adhan" button
      // so the user can stop from the notification shade.
      final displayName = _prayerDisplayName(l10n, prayerKey[0].toUpperCase() + prayerKey.substring(1));
      const silentAndroid = AndroidNotificationDetails(
        'adhan_control_channel',
        'Adhan Control',
        channelDescription: 'Silent notification with Stop Adhan button',
        importance: Importance.max,
        priority: Priority.max,
        playSound: false,
        autoCancel: false,
        ongoing: true,
        category: AndroidNotificationCategory.alarm,
        enableVibration: false,
        actions: [
          AndroidNotificationAction(
            'stop_adhan',
            'Stop Adhan',
            cancelNotification: true,
          ),
        ],
      );
      await plugin.show(
        PrayerNotificationIds.adhanId(prayerKey),
        l10n.prayerAdhanNotificationTitle(displayName),
        l10n.prayerAdhanNotificationBody(displayName),
        const NotificationDetails(android: silentAndroid),
        payload: prayerKey,
      );
    } catch (e) {
      debugPrint('Failed to play in-app adhan: $e');
    }
  }

  /// Stops any currently-playing adhan via AdhanAudioPlayer.
  Future<void> _stopInAppAdhan() async {
    try {
      final player = getIt<AdhanAudioPlayer>();
      await player.stopAdhan();
    } catch (_) {}
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateLabel(AppLocalizations l10n, DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return l10n.commonToday;
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return l10n.commonYesterday;
    }
    if (_isSameDay(date, now.add(const Duration(days: 1)))) {
      return l10n.commonTomorrow;
    }
    return DateFormat.MMMEd(l10n.localeName).format(date);
  }

  void _navigateDate(int offset) {
    final currentState = _cubit.state;
    if (currentState is PrayerLoadSuccess) {
      final newDate = currentState.selectedDate.add(Duration(days: offset));
      _cubit.loadPrayerTimes(date: newDate);
    }
  }

  void _goToToday() {
    _cubit.loadPrayerTimes();
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${hours}h ${minutes}m ${seconds}s';
  }

  DateTime _getPreviousPrayerTime(
    PrayerTimeEntity today,
    String nextName,
    UserLocation location,
    PrayerTimesSettings settings,
  ) {
    final now = DateTime.now();
    final calcUseCase = getIt<CalculatePrayerTimesUseCase>();

    switch (nextName) {
      case 'Fajr':
        if (now.isBefore(today.fajr)) {
          final yesterday = now.subtract(const Duration(days: 1));
          final yesterdayTimes = calcUseCase.calculateLocal(
            location: location,
            date: yesterday,
            settings: settings,
          );
          if (yesterdayTimes != null) return yesterdayTimes.isha;
          // Yesterday's data isn't available — approximate so the progress
          // bar still renders; this is display-only.
          return today.fajr.subtract(const Duration(hours: 2));
        }
        return today.isha;
      case 'Sunrise':
        return today.fajr;
      case 'Dhuhr':
        return today.sunrise;
      case 'Asr':
        return today.dhuhr;
      case 'Maghrib':
        return today.asr;
      case 'Isha':
        return today.maghrib;
      default:
        return today.isha;
    }
  }

  /// Whether an Adhan is currently in its "playing" window, using the
  /// same detection the notification service uses — so the in-app banner
  /// and the actual scheduled notifications never disagree.
  bool _isAdhanPlaying(PrayerTimeEntity today, PrayerTimesSettings settings) {
    final activeKey = PrayerNotificationIds.activePrayerKey(today, settings);
    if (activeKey == null) return false;
    return activeKey != _manuallyStoppedPrayerKey;
  }

  void _showSettingsBottomSheet(BuildContext context, PrayerLoadSuccess state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.isDarkMode
          ? AppColors.surfaceDarkVariant
          : AppColors.surfaceLightVariant,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _PrayerSettingsSheet(cubit: _cubit),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.prayerPageTitle),
          titleTextStyle: AppTextStyles.arabicHeading(fontSize: 20).copyWith(
            color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
          ),
          actions: [
            BlocBuilder<PrayerCubit, PrayerState>(
              builder: (context, state) {
                if (state is PrayerLoadSuccess) {
                  return IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: () => _showSettingsBottomSheet(context, state),
                    tooltip: l10n.commonSettings,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            IconButton(
              icon: const Icon(Icons.my_location_rounded),
              onPressed: () => _cubit.loadPrayerTimes(forceRefresh: true),
              tooltip: l10n.commonRefreshLocation,
            ),
          ],
        ),
        body: BlocBuilder<PrayerCubit, PrayerState>(
          builder: (context, state) {
            if (state is PrayerLoadInProgress) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              );
            }

            if (state is PrayerLoadFailure) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_off_rounded,
                        size: 80,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        l10n.prayerFailedLoad,
                        style: AppTextStyles.headingMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        style: AppTextStyles.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _cubit.loadPrayerTimes(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (state is PrayerLoadSuccess) {
              final isToday = _isSameDay(state.selectedDate, DateTime.now());

              final prevTime = _getPreviousPrayerTime(
                state.todayTimes,
                state.nextPrayerName,
                state.location,
                state.settings,
              );

              final totalDuration = state.nextPrayerTime
                  .difference(prevTime)
                  .inSeconds;
              final elapsed = DateTime.now().difference(prevTime).inSeconds;
              final progress = totalDuration > 0
                  ? (elapsed / totalDuration).clamp(0.0, 1.0)
                  : 0.0;

              final audioPlayerIsPlaying = getIt<AdhanAudioPlayer>().isPlaying;
              final activePrayerKey = PrayerNotificationIds.activePrayerKey(state.todayTimes, state.settings);
              final adhanPlaying = (isToday && _isAdhanPlaying(state.todayTimes, state.settings)) || audioPlayerIsPlaying;
              final soundEnabled = activePrayerKey != null &&
                  state.settings.prayerHasSound(activePrayerKey);
              if (_manualStopReady && soundEnabled && adhanPlaying && !audioPlayerIsPlaying) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _startInAppAdhan(activePrayerKey);
                });
              }

              return GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity == null) return;
                  if (details.primaryVelocity! > 300) {
                    _navigateDate(-1); // Swipe right → previous day
                  } else if (details.primaryVelocity! < -300) {
                    _navigateDate(1);  // Swipe left → next day
                  }
                },
                child: Scrollbar(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header Section ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.accentGold,
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    state.location.cityName ?? l10n.prayerGpsLocation,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? AppColors.onSurfaceDark
                                          : AppColors.onSurfaceLight,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            l10n.localeName == 'ar' && state.hijriDateStrAr.isNotEmpty
                                ? state.hijriDateStrAr
                                : state.hijriDateStr,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.accentGoldDark,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Date Navigation Bar ──
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardDark
                              : AppColors.cardLight,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppColors.dividerDark
                                : AppColors.divider.withAlpha(80),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _navigateDate(-1),
                              icon: const Icon(Icons.chevron_left_rounded),
                              color: AppColors.primaryGreen,
                              tooltip: l10n.prayerPreviousDay,
                            ),
                            GestureDetector(
                              onTap: isToday ? null : _goToToday,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isToday
                                      ? AppColors.primaryGreen.withAlpha(25)
                                      : AppColors.accentGold.withAlpha(30),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isToday
                                        ? AppColors.primaryGreen.withAlpha(80)
                                        : AppColors.accentGold.withAlpha(80),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isToday
                                          ? Icons.today_rounded
                                          : Icons.calendar_today_rounded,
                                      size: 16,
                                      color: isToday
                                          ? AppColors.primaryGreen
                                          : AppColors.accentGoldDark,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDateLabel(l10n, state.selectedDate),
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isToday
                                            ? AppColors.primaryGreen
                                            : AppColors.accentGoldDark,
                                      ),
                                    ),
                                    if (!isToday) ...[
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.undo_rounded,
                                        size: 14,
                                        color: AppColors.accentGoldDark,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => _navigateDate(1),
                              icon: const Icon(Icons.chevron_right_rounded),
                              color: AppColors.primaryGreen,
                              tooltip: l10n.prayerNextDay,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Adhan Playing Banner ──
                      if (adhanPlaying) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withAlpha(40),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.redAccent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.volume_up_rounded, color: Colors.redAccent),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l10n.prayerAdhanPlaying,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final activeKey = PrayerNotificationIds.activePrayerKey(
                                    state.todayTimes,
                                    state.settings,
                                  );
                                  _cubit.stopActiveAdhan();
                                  _stopInAppAdhan();
                                  setState(() {
                                    _manuallyStoppedPrayerKey = activeKey;
                                  });
                                  if (activeKey != null) {
                                    PrayerNotificationService
                                        .persistManualAdhanStop(activeKey);
                                  }
                                },
                                icon: const Icon(Icons.stop_rounded),
                                label: Text(l10n.commonStop),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // ── Next Prayer Premium Banner Card ──
                      if (isToday) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      AppColors.primaryGreenDark,
                                      AppColors.cardDark,
                                    ]
                                  : [
                                      AppColors.primaryGreen,
                                      AppColors.primaryGreenDark,
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGreen.withAlpha(
                                  isDark ? 50 : 100,
                                ),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                l10n.prayerNextPrayer,
                                style: AppTextStyles.caption.copyWith(
                                  color: Colors.white.withAlpha(180),
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _prayerDisplayName(l10n, state.nextPrayerName).toUpperCase(),
                                style: AppTextStyles.headingLarge.copyWith(
                                  color: AppColors.accentGold,
                                  fontSize: 40,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _formatDuration(state.timeRemaining),
                                style: AppTextStyles.headingMedium.copyWith(
                                  color: Colors.white,
                                  fontFamily:
                                      'Courier', // Monospaced feel for timer
                                  fontSize: 32,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: Colors.white.withAlpha(50),
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppColors.accentGold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Daily Prayer List ──
                      Text(
                        isToday ? l10n.prayerTodaysPrayers : l10n.prayerTimesHeading,
                        style: AppTextStyles.headingMedium.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildPrayerTimeRow(
                        context,
                        l10n,
                        'Fajr',
                        state.todayTimes.fajr,
                        Icons.nights_stay_rounded,
                        state.nextPrayerName == 'Fajr',
                        state.settings,
                      ),
                      _buildPrayerTimeRow(
                        context,
                        l10n,
                        'Sunrise',
                        state.todayTimes.sunrise,
                        Icons.wb_sunny_outlined,
                        state.nextPrayerName == 'Sunrise',
                        state.settings,
                      ),
                      _buildPrayerTimeRow(
                        context,
                        l10n,
                        'Dhuhr',
                        state.todayTimes.dhuhr,
                        Icons.wb_sunny_rounded,
                        state.nextPrayerName == 'Dhuhr',
                        state.settings,
                      ),
                      _buildPrayerTimeRow(
                        context,
                        l10n,
                        'Asr',
                        state.todayTimes.asr,
                        Icons.wb_cloudy_rounded,
                        state.nextPrayerName == 'Asr',
                        state.settings,
                      ),
                      _buildPrayerTimeRow(
                        context,
                        l10n,
                        'Maghrib',
                        state.todayTimes.maghrib,
                        Icons.wb_twilight_rounded,
                        state.nextPrayerName == 'Maghrib',
                        state.settings,
                      ),
                      _buildPrayerTimeRow(
                        context,
                        l10n,
                        'Isha',
                        state.todayTimes.isha,
                        Icons.bedtime_rounded,
                        state.nextPrayerName == 'Isha',
                        state.settings,
                      ),
                    ],
                  ),
                ),
              ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildPrayerTimeRow(
    BuildContext context,
    AppLocalizations l10n,
    String name,
    DateTime time,
    IconData icon,
    bool isNext,
    PrayerTimesSettings settings,
  ) {
    final isDark = context.isDarkMode;
    final timeStr = TimeOfDay.fromDateTime(time).format(context);
    final key = name.toLowerCase();
    final isMuted = settings.mutedPrayers.contains(key);
    final hasSound = settings.prayerHasSound(key);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isNext
            ? (isDark
                  ? AppColors.primaryGreenDark.withAlpha(60)
                  : AppColors.primaryGreen.withAlpha(20))
            : (isDark ? AppColors.cardDark : AppColors.cardLight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? AppColors.primaryGreen
              : (isDark
                    ? AppColors.dividerDark
                    : AppColors.divider.withAlpha(80)),
          width: isNext ? 1.5 : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isNext
                    ? AppColors.primaryGreen
                    : (isDark ? Colors.white54 : Colors.black54),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  _prayerDisplayName(l10n, name),
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                    color: isNext
                        ? AppColors.primaryGreen
                        : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                  ),
                ),
              ),
              Text(
                timeStr,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                  color: isNext
                      ? AppColors.primaryGreen
                      : (isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isMuted ? Icons.notifications_off_rounded : Icons.notifications_active_rounded,
                  color: isMuted
                      ? (isDark ? Colors.white38 : Colors.black38)
                      : (isNext ? AppColors.primaryGreen : AppColors.accentGold),
                  size: 20,
                ),
                onPressed: () => _cubit.togglePrayerMute(key),
                tooltip: isMuted ? l10n.prayerUnmuteAdhan : l10n.prayerMuteAdhan,
              ),
              const SizedBox(width: 4),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  hasSound ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: hasSound
                      ? (isNext ? AppColors.primaryGreen : AppColors.accentGold)
                      : (isDark ? Colors.white38 : Colors.black38),
                  size: 20,
                ),
                onPressed: () => _cubit.togglePrayerSound(key),
                tooltip: hasSound
                    ? l10n.prayerMuteAdhanSound
                    : l10n.prayerUnmuteAdhanSound,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet content for the prayer settings. Height is capped so the
/// panel never fills the screen, it always shows a visible close button and
/// a pinned "Done" button, and it dismisses itself automatically when the
/// user navigates away from the prayer tab.
class _PrayerSettingsSheet extends StatefulWidget {
  const _PrayerSettingsSheet({required this.cubit});

  final PrayerCubit cubit;

  @override
  State<_PrayerSettingsSheet> createState() => _PrayerSettingsSheetState();
}

class _PrayerSettingsSheetState extends State<_PrayerSettingsSheet> {
  @override
  void initState() {
    super.initState();
    // Dismiss the sheet whenever the user leaves the prayer tab, so the
    // panel never lingers over another screen.
    GoRouter.of(context).routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    GoRouter.of(context).routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  void _onRouteChanged() {
    final location = GoRouter.of(context).state.matchedLocation;
    if (!location.startsWith(AppRoutes.prayer) && mounted) {
      Navigator.of(context).pop();
    }
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerCubit, PrayerState>(
      bloc: widget.cubit,
      builder: (context, cubitState) {
        if (cubitState is! PrayerLoadSuccess) return const SizedBox.shrink();
        final settings = cubitState.settings;
        final l10n = AppLocalizations.of(context);
        final isDark = context.isDarkMode;
        final maxHeight = MediaQuery.sizeOf(context).height * 0.85;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header: drag handle + title + close button ──
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.withAlpha(100),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.prayerSettingsTitle,
                            style: AppTextStyles.headingMedium.copyWith(
                              color: isDark
                                  ? AppColors.onSurfaceDark
                                  : AppColors.onSurfaceLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.close_rounded),
                      color: isDark
                          ? AppColors.onSurfaceDark
                          : AppColors.onSurfaceLight,
                      tooltip: l10n.commonClose,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Scrollable settings body ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.prayerEnableNotifications,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        subtitle: Text(
                          l10n.prayerEnableNotificationsSubtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.onSurfaceDarkVariant
                                : AppColors.onSurfaceLightVariant,
                          ),
                        ),
                        value: settings.notificationsEnabled,
                        activeThumbColor: AppColors.primaryGreen,
                        activeTrackColor: AppColors.primaryGreen.withAlpha(80),
                        onChanged: (val) {
                          widget.cubit.toggleNotifications(val);
                        },
                      ),

                      const Divider(height: 24),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.prayerAdhanSoundToggle,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        subtitle: Text(
                          l10n.prayerAdhanSoundToggleSubtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.onSurfaceDarkVariant
                                : AppColors.onSurfaceLightVariant,
                          ),
                        ),
                        value: settings.adhanSoundEnabled,
                        activeThumbColor: AppColors.primaryGreen,
                        activeTrackColor: AppColors.primaryGreen.withAlpha(80),
                        onChanged: (val) {
                          widget.cubit.toggleAdhanSound(val);
                        },
                      ),

                      if (settings.notificationsEnabled) ...[
                        const Divider(height: 24),
                        Text(
                          l10n.prayerReminderBefore,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<int>(
                          segments: [
                            ButtonSegment(
                              value: 5,
                              label: Text(l10n.prayerReminder5Min),
                            ),
                            ButtonSegment(
                              value: 15,
                              label: Text(l10n.prayerReminder15Min),
                            ),
                          ],
                          selected: {settings.reminderInterval},
                          onSelectionChanged: (newSelection) {
                            widget.cubit
                                .setReminderInterval(newSelection.first);
                          },
                          style: ButtonStyle(
                            backgroundColor:
                                WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AppColors.primaryGreen;
                                }
                                return Colors.transparent;
                              },
                            ),
                            foregroundColor:
                                WidgetStateProperty.resolveWith<Color>(
                              (states) {
                                if (states.contains(WidgetState.selected)) {
                                  return Colors.white;
                                }
                                return isDark ? Colors.white70 : Colors.black87;
                              },
                            ),
                          ),
                        ),
                      ],

                      const Divider(height: 32),

                      Text(
                        l10n.prayerAdhanSound,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.prayerFajrAdhanHint,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDarkVariant
                              : AppColors.onSurfaceLightVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      BlocBuilder<SettingsCubit, SettingsState>(
                        builder: (context, settingsState) {
                          final adhanType = settingsState is SettingsLoadSuccess
                              ? settingsState.settings.adhanType
                              : AdhanType.full;

                          return SegmentedButton<AdhanType>(
                            segments: [
                              ButtonSegment(
                                value: AdhanType.full,
                                label: Text(l10n.prayerFullAdhan),
                              ),
                              ButtonSegment(
                                value: AdhanType.short,
                                label: Text(l10n.prayerShortAdhan),
                              ),
                            ],
                            selected: {adhanType},
                            onSelectionChanged: (newSelection) async {
                              await context
                                  .read<SettingsCubit>()
                                  .setAdhanType(newSelection.first);
                              await widget.cubit.loadPrayerTimes(
                                date: cubitState.selectedDate,
                              );
                            },
                            style: ButtonStyle(
                              backgroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return AppColors.primaryGreen;
                                  }
                                  return Colors.transparent;
                                },
                              ),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith<Color>(
                                (states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return Colors.white;
                                  }
                                  return isDark
                                      ? Colors.white70
                                      : Colors.black87;
                                },
                              ),
                            ),
                          );
                        },
                      ),

                      const Divider(height: 32),

                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.prayerAutomaticMethod,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        subtitle: Text(
                          l10n.prayerAutomaticMethodSubtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.onSurfaceDarkVariant
                                : AppColors.onSurfaceLightVariant,
                          ),
                        ),
                        value: settings.useAutomaticMethod,
                        activeThumbColor: AppColors.primaryGreen,
                        activeTrackColor: AppColors.primaryGreen.withAlpha(80),
                        onChanged: (val) {
                          final newSettings = settings.copyWith(
                            useAutomaticMethod: val,
                            manualMethodId: val ? null : 3,
                          );
                          widget.cubit.updateSettings(newSettings);
                        },
                      ),

                      if (!settings.useAutomaticMethod) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.prayerCalculationMethod,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.onSurfaceDark
                                : AppColors.onSurfaceLight,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.cardDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.divider.withAlpha(100),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? AppColors.surfaceDarkVariant
                                  : AppColors.surfaceLightVariant,
                              value: settings.manualMethodId ?? 3,
                              items: aladhanMethods.map((method) {
                                return DropdownMenuItem(
                                  value: method.id,
                                  child: Text(
                                    method.name,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: isDark
                                          ? AppColors.onSurfaceDark
                                          : AppColors.onSurfaceLight,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newMethodId) {
                                if (newMethodId != null) {
                                  final newSettings = settings.copyWith(
                                    useAutomaticMethod: false,
                                    manualMethodId: newMethodId,
                                  );
                                  widget.cubit.updateSettings(newSettings);
                                }
                              },
                            ),
                          ),
                        ),
                      ],

                      const Divider(height: 32),

                      Text(
                        l10n.prayerMadhab,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppColors.onSurfaceDark
                              : AppColors.onSurfaceLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 0,
                            label: Text(l10n.prayerMadhabStandard),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text(l10n.prayerMadhabHanafi),
                          ),
                        ],
                        selected: {settings.madhab},
                        onSelectionChanged: (newSelection) {
                          final newSettings = settings.copyWith(
                            madhab: newSelection.first,
                          );
                          widget.cubit.updateSettings(newSettings);
                        },
                        style: ButtonStyle(
                          backgroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                            (states) {
                              if (states.contains(WidgetState.selected)) {
                                return AppColors.primaryGreen;
                              }
                              return Colors.transparent;
                            },
                          ),
                          foregroundColor:
                              WidgetStateProperty.resolveWith<Color>(
                            (states) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return isDark ? Colors.white70 : Colors.black87;
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),

              // ── Pinned "Done" button ──
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                  child: FilledButton(
                    onPressed: _close,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      l10n.commonDone,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}