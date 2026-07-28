/// Prayer notification scheduling, Adhan playback (via native notification
/// sound), Adhkar reminder scheduling, and notification action/tap handling
/// for Ahl Jannah.
///
/// This file is the single source of truth for:
/// - Notification IDs (via [PrayerNotificationIds]) — scheduling and
///   cancellation always go through here so they can never drift apart.
/// - Which Adhan sound file plays for a given prayer + [AdhanType].
/// - Morning/Evening Adhkar reminder scheduling (Fajr+1h / Asr+1h).
/// - Notification action-button handling and tap-to-navigate routing,
///   shared by every notification kind this service schedules.
library;

import 'dart:io';
import 'dart:ui' show Locale, PlatformDispatcher;
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:injectable/injectable.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../domain/entities/prayer_entities.dart';

/// Action identifiers used by the reminder / adhan notification buttons.
const String _actionCancelAdhan = 'cancel_adhan';
const String _actionStopAdhan = 'stop_adhan';

/// iOS notification category identifiers, matching the action ids above.
const String _categoryReminder = 'prayer_reminder_category';
const String _categoryAdhanPlaying = 'adhan_playing_category';

/// Notification payload values used for Adhkar reminders. Prayer/Adhan
/// notifications use the raw prayer key (e.g. `'fajr'`) as their payload,
/// so these are namespaced to avoid ever colliding with a prayer key.
const String _payloadMorningAdhkar = 'morning_adhkar';
const String _payloadEveningAdhkar = 'evening_adhkar';

/// Category identifiers exactly as stored in `assets/adhkar.json`'s
/// `"category"` field. `_categoryMorningAdhkar` is confirmed from the
/// asset; `_categoryEveningAdhkar` follows the same dataset's standard
/// naming and should be double-checked against the actual asset file.
const String _categoryMorningAdhkar = 'أذكار الصباح';
const String _categoryEveningAdhkar = 'أذكار المساء';

/// Ordered list of prayer keys that receive a reminder notification.
/// `sunrise` gets a reminder (matching prior behavior) but is excluded
/// from [_adhanPrayerKeys] below — there is no Adhan for sunrise, it is
/// only a reference marker for when the Duha period begins.
const List<String> _allPrayerKeys = [
  'fajr',
  'sunrise',
  'dhuhr',
  'asr',
  'maghrib',
  'isha',
];

/// Prayer keys that get an actual Adhan.
const List<String> _adhanPrayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// Which Adhkar reminder is being scheduled/cancelled.
enum AdhkarReminderKind { morning, evening }

/// Deterministic, collision-free notification IDs for every
/// prayer/notification-kind combination. Scheduling and cancellation
/// both derive IDs from here, so they can never fall out of sync.
class PrayerNotificationIds {
  const PrayerNotificationIds._();

  static int _baseFor(String prayerKey) {
    final index = _allPrayerKeys.indexOf(prayerKey);
    assert(index != -1, 'Unknown prayer key: $prayerKey');
    return 1000 + (index * 10);
  }

  /// The "N minutes before" reminder notification id.
  static int reminderId(String prayerKey) => _baseFor(prayerKey) + 1;

  /// The sound-producing "It's time for X" Adhan notification id.
  static int adhanId(String prayerKey) => _baseFor(prayerKey) + 2;

  /// The ongoing "Adhan is playing — Stop Adhan" banner notification id.
  static int stopBannerId(String prayerKey) => _baseFor(prayerKey) + 3;

  /// IDs for the two Adhkar reminders — a separate, non-overlapping
  /// range (2001/2002) so they can never collide with the prayer IDs
  /// above (which top out well under 2000).
  static int adhkarReminderId(AdhkarReminderKind kind) {
    switch (kind) {
      case AdhkarReminderKind.morning:
        return 2001;
      case AdhkarReminderKind.evening:
        return 2002;
    }
  }

  /// The prayer key whose Adhan window is currently active (i.e. would
  /// currently be sounding), or `null` if none is. Shared by
  /// [PrayerNotificationService.stopActiveAdhan] and the Prayer page's
  /// "Adhan is playing" banner so the two never disagree.
  static String? activePrayerKey(
    PrayerTimeEntity today,
    PrayerTimesSettings settings, {
    Duration window = const Duration(minutes: 3),
  }) {
    if (!settings.notificationsEnabled) return null;
    final now = DateTime.now();
    final times = <String, DateTime>{
      'fajr': today.fajr,
      'dhuhr': today.dhuhr,
      'asr': today.asr,
      'maghrib': today.maghrib,
      'isha': today.isha,
    };

    for (final key in _adhanPrayerKeys) {
      if (settings.mutedPrayers.contains(key)) continue;
      final time = times[key]!;
      if (now.isAfter(time) && now.isBefore(time.add(window))) {
        return key;
      }
    }
    return null;
  }
}

/// Resolves a notification's [payload] to a destination route and
/// navigates there. Shared by the foreground tap handler and the
/// cold-start launch handler so there is exactly one place that knows
/// "which payload goes where".
void _navigateForPayload(String? payload) {
  try {
    if (payload == _payloadMorningAdhkar) {
      appRouter.go(
        AppRoutes.adhkar,
        extra: {'initialCategory': _categoryMorningAdhkar},
      );
    } else if (payload == _payloadEveningAdhkar) {
      appRouter.go(
        AppRoutes.adhkar,
        extra: {'initialCategory': _categoryEveningAdhkar},
      );
    } else {
      // Prayer-key payload (fajr/dhuhr/...) or unknown — Prayer page,
      // matching the app's prior default behavior.
      appRouter.go(AppRoutes.prayer);
    }
  } catch (e) {
    debugPrint('Failed to navigate for notification payload "$payload": $e');
  }
}

/// Handles notification responses while the app process is alive
/// (foreground or backgrounded-but-running). Runs in the main isolate, so
/// it can safely navigate via [appRouter].
Future<void> _onForegroundNotificationResponse(NotificationResponse response) async {
  if (response.actionId != null) {
    await _handleAction(response);
    return;
  }
  // Plain tap on the notification body.
  _navigateForPayload(response.payload);
}

/// Handles notification action-button taps while the app process is fully
/// terminated. Must be a top-level/static function annotated with
/// `@pragma('vm:entry-point')` so the Android background isolate can find
/// it. Only handles action buttons — a plain body tap while the app is
/// killed is handled by the OS launching the app directly, which is then
/// picked up via `getNotificationAppLaunchDetails()` in [initialize].
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) {
  _handleAction(response);
}

/// Shared action handling used by both the foreground and background
/// response handlers, so this logic exists in exactly one place.
Future<void> _handleAction(NotificationResponse response) async {
  final prayerKey = response.payload;
  if (prayerKey == null) return;

  final actionId = response.actionId;
  if (actionId != _actionCancelAdhan && actionId != _actionStopAdhan) return;

  // Both actions resolve to the same effect: the upcoming/currently
  // playing Adhan for that prayer (and its "Stop Adhan" banner, if
  // showing) should not sound / should stop immediately. The next
  // prayers are untouched since IDs are per-prayer.
  final plugin = FlutterLocalNotificationsPlugin();
  try {
    await plugin.cancel(PrayerNotificationIds.adhanId(prayerKey));
    await plugin.cancel(PrayerNotificationIds.stopBannerId(prayerKey));
    debugPrint('Handled "$actionId" for $prayerKey');
  } catch (e) {
    debugPrint('Failed to handle notification action "$actionId": $e');
  }
}

@singleton
class PrayerNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initializes timezone and local notification plugin.
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Failed to resolve local timezone: $e');
    }


    final l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _categoryReminder,
          actions: [
            DarwinNotificationAction.plain(
              _actionCancelAdhan,
              l10n.prayerCancelAdhan,
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
        DarwinNotificationCategory(
          _categoryAdhanPlaying,
          actions: [
            DarwinNotificationAction.plain(
              _actionStopAdhan,
              l10n.prayerStopAdhan,
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onForegroundNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
      );

      // Cold start via a plain notification-body tap (app was fully
      // killed) — the OS already launched the app; route to the correct
      // destination once the widget tree (and router) is up. The short
      // delay gives MaterialApp.router time to attach to `appRouter`.
      final launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        final payload = launchDetails?.notificationResponse?.payload;
        // ignore: unawaited_futures
        Future.delayed(const Duration(milliseconds: 300), () {
          _navigateForPayload(payload);
        });
      }
    } catch (e, st) {
      // Don't let a plugin-level init failure block the rest of the app
      // (e.g. prayer times, Qibla, Quran) from working.
      debugPrint('Notification plugin failed to initialize: $e\n$st');
    }

    _isInitialized = true;
  }

  /// Requests permissions on iOS/Android.
  Future<bool> requestPermissions() async {

    try {
      if (Platform.isIOS) {
        final iosImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
        return await iosImpl?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
      } else if (Platform.isAndroid) {
        final androidImpl = _notificationsPlugin
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final notificationsGranted = await androidImpl?.requestNotificationsPermission() ?? false;
        final exactAlarmsGranted = await androidImpl?.requestExactAlarmsPermission();
        return notificationsGranted && (exactAlarmsGranted ?? true);
      }
    } catch (e) {
      debugPrint('Failed to request notification permissions: $e');
    }
    return false;
  }

  /// Cancels all scheduled prayer alerts. Called before every reschedule
  /// so notifications never get duplicated.
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e, st) {
      debugPrint('cancelAllNotifications failed: $e\n$st');
    }
  }

  /// Schedules reminder + Adhan (+ Stop Adhan banner) notifications for
  /// today's prayer times. When a prayer time has already passed, the
  /// matching time from [nextDayTimes] is used instead so overnight
  /// Fajr (and the rest of tomorrow) stay covered without relying on
  /// Workmanager alone. Always cancels previously scheduled
  /// notifications first, so calling this repeatedly never duplicates.
  Future<void> schedulePrayerNotifications(
    PrayerTimeEntity prayerTimes,
    PrayerTimesSettings settings,
    AdhanType adhanType, {
    required AppLanguage language,
    PrayerTimeEntity? nextDayTimes,
  }) async {
    await initialize();

    // Keep stale prayer alarms from firing after the user turns
    // notifications off. Callers that still need Adhkar should
    // reschedule them after this returns.
    if (!settings.notificationsEnabled) {
      await cancelAllNotifications();
      return;
    }

    final l10n = lookupAppLocalizations(_resolveNotificationLocale(language));

    await cancelAllNotifications();

    final scheduleMode = await _resolveAndroidScheduleMode();

    final todayTimes = <String, DateTime>{
      'fajr': prayerTimes.fajr,
      'sunrise': prayerTimes.sunrise,
      'dhuhr': prayerTimes.dhuhr,
      'asr': prayerTimes.asr,
      'maghrib': prayerTimes.maghrib,
      'isha': prayerTimes.isha,
    };
    final tomorrowTimes = nextDayTimes == null
        ? null
        : <String, DateTime>{
            'fajr': nextDayTimes.fajr,
            'sunrise': nextDayTimes.sunrise,
            'dhuhr': nextDayTimes.dhuhr,
            'asr': nextDayTimes.asr,
            'maghrib': nextDayTimes.maghrib,
            'isha': nextDayTimes.isha,
          };

    final now = DateTime.now();

    for (final key in _allPrayerKeys) {
      if (settings.mutedPrayers.contains(key)) continue;
      final time = _resolveUpcomingTime(
        today: todayTimes[key]!,
        tomorrow: tomorrowTimes?[key],
        now: now,
      );
      final title = _displayName(l10n, key);

      await _scheduleReminder(
        l10n: l10n,
        prayerKey: key,
        title: title,
        prayerTime: time,
        now: now,
        reminderMinutes: settings.reminderInterval,
        scheduleMode: scheduleMode,
      );

      if (_adhanPrayerKeys.contains(key)) {
        await _scheduleAdhan(
          l10n: l10n,
          prayerKey: key,
          title: title,
          prayerTime: time,
          now: now,
          adhanType: adhanType,
          scheduleMode: scheduleMode,
        );
      }
    }
  }

  /// Schedules the Morning (Fajr + 1h) and Evening (Asr + 1h) Adhkar
  /// reminders, honoring each toggle independently. Does **not** call
  /// [cancelAllNotifications] — it only ever touches its own two
  /// deterministic IDs (see [PrayerNotificationIds.adhkarReminderId]),
  /// so it's safe to call this after [schedulePrayerNotifications]
  /// without wiping out the prayer/adhan notifications just scheduled.
  ///
  /// Each reminder is always cancelled before being (re)scheduled, which
  /// both prevents duplicates and is exactly what "disabled → cancel
  /// that reminder" requires. When today's slot has passed,
  /// [nextDayTimes] is used so the overnight gap is covered.
  Future<void> scheduleAdhkarReminders(
    PrayerTimeEntity todayTimes, {
    required bool morningEnabled,
    required bool eveningEnabled,
    required AppLanguage language,
    PrayerTimeEntity? nextDayTimes,
  }) async {
    await initialize();

    final locale = _resolveNotificationLocale(language);
    final l10n = lookupAppLocalizations(locale);
    final now = DateTime.now();
    final scheduleMode = await _resolveAndroidScheduleMode();

    final morningTime = _resolveUpcomingTime(
      today: todayTimes.fajr.add(const Duration(hours: 1)),
      tomorrow: nextDayTimes?.fajr.add(const Duration(hours: 1)),
      now: now,
    );
    final eveningTime = _resolveUpcomingTime(
      today: todayTimes.asr.add(const Duration(hours: 1)),
      tomorrow: nextDayTimes?.asr.add(const Duration(hours: 1)),
      now: now,
    );

    await _scheduleOrCancelAdhkarReminder(
      kind: AdhkarReminderKind.morning,
      enabled: morningEnabled,
      reminderTime: morningTime,
      now: now,
      title: l10n.morningAdhkarNotificationTitle,
      body: l10n.morningAdhkarNotificationBody,
      payload: _payloadMorningAdhkar,
      scheduleMode: scheduleMode,
      l10n: l10n,
    );

    await _scheduleOrCancelAdhkarReminder(
      kind: AdhkarReminderKind.evening,
      enabled: eveningEnabled,
      reminderTime: eveningTime,
      now: now,
      title: l10n.eveningAdhkarNotificationTitle,
      body: l10n.eveningAdhkarNotificationBody,
      payload: _payloadEveningAdhkar,
      scheduleMode: scheduleMode,
      l10n: l10n,
    );
  }

  /// Cancels a single Adhkar reminder immediately — used when a toggle is
  /// switched off in Settings, so cancellation is instant rather than
  /// waiting for the next full reschedule cycle.
  Future<void> cancelAdhkarReminder(AdhkarReminderKind kind) async {
    try {
      await _notificationsPlugin.cancel(PrayerNotificationIds.adhkarReminderId(kind));
    } catch (e) {
      debugPrint('Failed to cancel $kind adhkar reminder: $e');
    }
  }

  /// Stops whichever Adhan is currently playing (if any), by cancelling
  /// its sound notification and its "Stop Adhan" banner. Uses the same
  /// active-prayer detection as the Prayer page's "Adhan is playing"
  /// banner, so both always agree on what's currently active. Prayers
  /// other than the currently active one are never touched.
  Future<void> stopActiveAdhan(PrayerTimeEntity today, PrayerTimesSettings settings) async {

    final activeKey = PrayerNotificationIds.activePrayerKey(today, settings);
    if (activeKey == null) return;

    try {
      await _notificationsPlugin.cancel(PrayerNotificationIds.adhanId(activeKey));
      await _notificationsPlugin.cancel(PrayerNotificationIds.stopBannerId(activeKey));
      debugPrint('Stopped active adhan for $activeKey');
    } catch (e) {
      debugPrint('Failed to stop active adhan: $e');
    }
  }

  // ── Internal helpers ──

  /// Picks [today] when it is still in the future, otherwise [tomorrow]
  /// (or today + 1 day as a last-resort approximation).
  static DateTime _resolveUpcomingTime({
    required DateTime today,
    required DateTime? tomorrow,
    required DateTime now,
  }) {
    if (today.isAfter(now)) return today;
    if (tomorrow != null && tomorrow.isAfter(now)) return tomorrow;
    return today.add(const Duration(days: 1));
  }

  Future<void> _scheduleReminder({
    required AppLocalizations l10n,
    required String prayerKey,
    required String title,
    required DateTime prayerTime,
    required DateTime now,
    required int reminderMinutes,
    required AndroidScheduleMode scheduleMode,
  }) async {
    final reminderTime = prayerTime.subtract(Duration(minutes: reminderMinutes));
    if (!reminderTime.isAfter(now)) return;

    final hasAdhan = _adhanPrayerKeys.contains(prayerKey);
    final reminderText = l10n.prayerReminderNotificationBody(title, reminderMinutes);

    final androidDetails = AndroidNotificationDetails(
      'prayer_reminder_channel',
      l10n.prayerNotificationChannelName,
      channelDescription: l10n.prayerReminderChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      actions: hasAdhan
          ? [
              AndroidNotificationAction(
                _actionCancelAdhan,
                l10n.prayerCancelAdhan,
                cancelNotification: true,
              ),
            ]
          : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: true,
      categoryIdentifier: hasAdhan ? _categoryReminder : null,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        PrayerNotificationIds.reminderId(prayerKey),
        reminderText,
        reminderText,
        tz.TZDateTime.from(reminderTime, tz.local),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: prayerKey,
      );
      debugPrint('Scheduled reminder for $title at $reminderTime');
    } catch (e) {
      debugPrint('Failed to schedule reminder for $title: $e');
    }
  }

  Future<void> _scheduleAdhan({
    required AppLocalizations l10n,
    required String prayerKey,
    required String title,
    required DateTime prayerTime,
    required DateTime now,
    required AdhanType adhanType,
    required AndroidScheduleMode scheduleMode,
  }) async {
    if (!prayerTime.isAfter(now)) return;

    final soundName = _soundResourceFor(prayerKey, adhanType);
    // iOS custom notification sounds are capped (~30s). Full Adhan files
    // exceed that, so Darwin always uses the short clip while Android
    // still plays the selected full/short/Fajr resource from res/raw.
    final iosSoundName = Platform.isIOS ? 'adhan_short' : soundName;

    // The channel id is keyed to the sound variant. Android notification
    // channels are immutable once created — reusing one fixed channel id
    // for every Adhan sound would mean the sound could never actually
    // change after the first schedule. Keying by sound name sidesteps
    // that by giving each variant its own channel.
    final adhanAndroid = AndroidNotificationDetails(
      'adhan_channel_${soundName}_v2',
      l10n.prayerAdhanChannelName,
      channelDescription: l10n.prayerAdhanChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound(soundName),
      playSound: true,
      autoCancel: true,
      category: AndroidNotificationCategory.alarm,
      enableVibration: true,
      fullScreenIntent: true,
    );

    final adhanIos = DarwinNotificationDetails(
      sound: '$iosSoundName.mp3',
      presentSound: true,
      presentAlert: true,
      presentBadge: true,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        PrayerNotificationIds.adhanId(prayerKey),
        l10n.prayerAdhanNotificationTitle(title),
        l10n.prayerAdhanNotificationBody(title),
        tz.TZDateTime.from(prayerTime, tz.local),
        NotificationDetails(android: adhanAndroid, iOS: adhanIos),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: prayerKey,
        matchDateTimeComponents: DateTimeComponents.time,
      );
      debugPrint('Scheduled adhan for $title at $prayerTime ($soundName)');
    } catch (e) {
      debugPrint('Failed to schedule adhan for $title: $e');
    }

    // A second, silent, ongoing notification carrying the "Stop Adhan"
    // action — fires alongside the sound-producing notification above
    // and stays pinned for the duration of the Adhan.
    final stopAndroid = AndroidNotificationDetails(
      'adhan_stop_control_channel',
      l10n.prayerAdhanPlayingChannelName,
      channelDescription: l10n.prayerAdhanPlayingChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      ongoing: true,
      autoCancel: false,
      actions: [
        AndroidNotificationAction(
          _actionStopAdhan,
          l10n.prayerStopAdhan,
          cancelNotification: true,
        ),
      ],
    );

    final stopIos = DarwinNotificationDetails(
      presentSound: false,
      categoryIdentifier: _categoryAdhanPlaying,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        PrayerNotificationIds.stopBannerId(prayerKey),
        l10n.prayerAdhanPlaying,
        l10n.prayerStopAdhan,
        tz.TZDateTime.from(prayerTime, tz.local),
        NotificationDetails(android: stopAndroid, iOS: stopIos),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: prayerKey,
      );
    } catch (e) {
      debugPrint('Failed to schedule "Stop Adhan" banner for $title: $e');
    }
  }

  Future<void> _scheduleOrCancelAdhkarReminder({
    required AdhkarReminderKind kind,
    required bool enabled,
    required DateTime reminderTime,
    required DateTime now,
    required String title,
    required String body,
    required String payload,
    required AndroidScheduleMode scheduleMode,
    required AppLocalizations l10n,
  }) async {
    final id = PrayerNotificationIds.adhkarReminderId(kind);

    // Always cancel first — this makes rescheduling idempotent (never
    // duplicates) and is also exactly what "disabled → cancel that
    // reminder" requires.
    try {
      await _notificationsPlugin.cancel(id);
    } catch (e) {
      debugPrint('Failed to cancel existing $kind adhkar reminder: $e');
    }

    if (!enabled) return;
    if (!reminderTime.isAfter(now)) return;

    final androidDetails = AndroidNotificationDetails(
      'adhkar_reminder_channel',
      l10n.adhkarNotificationChannelName,
      channelDescription: l10n.adhkarNotificationChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(presentSound: true);

    try {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(reminderTime, tz.local),
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: scheduleMode,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      debugPrint('Scheduled $kind adhkar reminder at $reminderTime');
    } catch (e) {
      debugPrint('Failed to schedule $kind adhkar reminder: $e');
    }
  }

  /// Checks whether exact alarms are actually permitted on this device
  /// and falls back to inexact scheduling when they're not — this is
  /// the fix for notifications silently failing to schedule at all.
  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final canExact = await androidImpl?.canScheduleExactNotifications() ?? false;
      if (!canExact) {
        debugPrint(
          'Exact alarms not permitted — falling back to inexact scheduling. '
          'Prayer notifications may fire a few minutes late.',
        );
      }
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (e) {
      debugPrint('Failed to check exact-alarm permission: $e');
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// Resolves the raw-resource (Android) / bundle filename-without-
  /// extension (iOS) to use for [prayerKey] given the user's [adhanType].
  ///
  /// Fajr always uses the dedicated Fajr Adhan unless the user has
  /// selected Short Adhan, in which case every prayer (including Fajr)
  /// uses the short "Allahu Akbar" clip.
  static String _soundResourceFor(String prayerKey, AdhanType adhanType) {
    if (adhanType == AdhanType.short) return 'adhan_short';
    if (prayerKey == 'fajr') return 'adhan_alfajr';
    return 'adhan';
  }

  /// Maps the app's [AppLanguage] setting to a concrete [Locale] for
  /// looking up notification strings, mirroring the fallback used by
  /// `app.dart`'s `localeResolutionCallback` (unsupported/system → 'en').
  static Locale _resolveNotificationLocale(AppLanguage language) {
    switch (language) {
      case AppLanguage.en:
        return const Locale('en');
      case AppLanguage.ar:
        return const Locale('ar');
      case AppLanguage.fr:
        return const Locale('fr');
      case AppLanguage.system:
        return const Locale('en');
    }
  }

  static String _displayName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'fajr':
        return l10n.prayerNameFajr;
      case 'sunrise':
        return l10n.prayerNameSunrise;
      case 'dhuhr':
        return l10n.prayerNameDhuhr;
      case 'asr':
        return l10n.prayerNameAsr;
      case 'maghrib':
        return l10n.prayerNameMaghrib;
      case 'isha':
        return l10n.prayerNameIsha;
      default:
        return key;
    }
  }
}