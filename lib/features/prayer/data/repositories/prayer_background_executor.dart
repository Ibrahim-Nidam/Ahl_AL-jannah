import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../domain/usecases/prayer_usecases.dart';
import 'prayer_notification_service.dart';

@pragma('vm:entry-point')
void prayerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    AppLogger.info("Workmanager background task started: $taskName");
    try {
      // CRITICAL: Initialize timezone database in background isolate
      // This is required because background tasks run in a separate context
      tz.initializeTimeZones();
      AppLogger.debug("Timezone database initialized in background task");
      
      // 1. Initialize DI so we can retrieve dependencies
      AppLogger.debug("Initializing dependency injection");
      configureDependencies();

      // 2. Fetch location, prayer-calculation settings, and the app-wide
      //    settings (Adhan Type + Adhkar reminder toggles + language),
      //    which live in the Settings feature, not Prayer's own settings
      //    object.
      final getLocation = getIt<GetUserLocationUseCase>();
      final getPrayerSettings = getIt<GetPrayerSettingsUseCase>();
      final getAppSettings = getIt<GetSettingsUseCase>();
      final calculateTimes = getIt<CalculatePrayerTimesUseCase>();
      final notificationService = getIt<PrayerNotificationService>();

      AppLogger.debug("Fetching location and settings");
      final location = await getLocation();
      final prayerSettings = await getPrayerSettings();
      final appSettings = await getAppSettings();

      AppLogger.info("Location: ${location.cityName}, Notifications enabled: ${prayerSettings.notificationsEnabled}");

      // 3. Calculate today + tomorrow so past prayers fall through to
      //    tomorrow's times (covers overnight Fajr without waiting for
      //    the next Workmanager tick).
      final now = DateTime.now();
      AppLogger.debug("Calculating prayer times for $now");
      
      final todayTimes = await calculateTimes(
        location: location,
        date: now,
        settings: prayerSettings,
      );
      final nextDayTimes = await calculateTimes(
        location: location,
        date: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
        settings: prayerSettings,
      );

      AppLogger.info("Today's prayer times: Fajr: ${todayTimes.fajr}, Dhuhr: ${todayTimes.dhuhr}, Asr: ${todayTimes.asr}, Maghrib: ${todayTimes.maghrib}, Isha: ${todayTimes.isha}");

      // 4. Schedule prayer/adhan notifications, then Adhkar reminders.
      //    Adhkar scheduling must come after prayer scheduling — the
      //    latter does a full `cancelAllNotifications()` first, which
      //    would otherwise wipe out freshly-scheduled Adhkar reminders.
      AppLogger.debug("Initializing notification service");
      await notificationService.initialize();
      
      AppLogger.debug("Scheduling prayer notifications");
      await notificationService.schedulePrayerNotifications(
        todayTimes,
        prayerSettings,
        appSettings.adhanType,
        language: appSettings.language,
        nextDayTimes: nextDayTimes,
      );
      
      AppLogger.debug("Scheduling Adhkar reminders");
      await notificationService.scheduleAdhkarReminders(
        todayTimes,
        morningEnabled: appSettings.morningAdhkarReminderEnabled,
        eveningEnabled: appSettings.eveningAdhkarReminderEnabled,
        language: appSettings.language,
        nextDayTimes: nextDayTimes,
      );

      // Schedule a best-effort rollover task a few minutes after tomorrow's
      // Fajr, so the schedule deterministically advances to the next day
      // even if the OS delays the daily periodic task. This is purely a
      // safety net — the exact-alarm notifications themselves already cover
      // today + tomorrow and survive app kill / reboot.
      try {
        final now = DateTime.now();
        var rolloverDelay = nextDayTimes.fajr.difference(now) + const Duration(minutes: 3);
        if (rolloverDelay < const Duration(minutes: 2)) {
          rolloverDelay = const Duration(minutes: 2);
        }
        await Workmanager().registerOneOffTask(
          "daily_rollover",
          "dailyAdhanRescheduleTask",
          initialDelay: rolloverDelay,
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(
            requiresBatteryNotLow: false,
            requiresCharging: false,
            requiresDeviceIdle: false,
            requiresStorageNotLow: false,
          ),
        );
        AppLogger.info('Daily rollover task scheduled in $rolloverDelay');
      } catch (e, st) {
        AppLogger.error('Failed to register daily rollover task', error: e, stackTrace: st);
      }

      AppLogger.info("Workmanager background task completed successfully.");
      return true;
    } catch (e, stackTrace) {
      AppLogger.error("Error in Workmanager background task", error: e, stackTrace: stackTrace);
      return false;
    }
  });
}

/// Helper class to initialize and manage background work scheduling.
class PrayerBackgroundExecutor {
  /// Initializes Workmanager for scheduling notifications.
  static Future<void> initialize() async {
    AppLogger.info('PrayerBackgroundExecutor.initialize called');
    try {
      await Workmanager().initialize(
        prayerCallbackDispatcher,
      );
      AppLogger.info('Workmanager initialized successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to initialize Workmanager', error: e, stackTrace: stackTrace);
    }
  }

  /// Registers the daily safety-net task that re-establishes the prayer
  /// notifications.
  ///
  /// Intentionally DAILY (not every 15 minutes). Exact-alarm notifications
  /// are scheduled ~24h ahead, persist across app kill and reboot (via the
  /// boot receiver), and are re-scheduled on every app open — so a daily
  /// periodic re-check is all that is needed to recover from any lost
  /// alarms. Scheduling every 15 minutes instead cancels and re-creates
  /// every exact alarm constantly, which triggers Android's exact-alarm
  /// throttling and is a primary cause of alerts firing LATE.
  static Future<void> scheduleDailyAdhanTask() async {
    AppLogger.info('PrayerBackgroundExecutor.scheduleDailyAdhanTask called');
    try {
      await Workmanager().registerPeriodicTask(
        "daily_adhan_rescheduler",
        "dailyAdhanRescheduleTask",
        frequency: const Duration(hours: 24),
        initialDelay: const Duration(minutes: 1),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      AppLogger.info('Background prayer safety-net task registered (daily)');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to register periodic task', error: e, stackTrace: stackTrace);
    }
  }
}
