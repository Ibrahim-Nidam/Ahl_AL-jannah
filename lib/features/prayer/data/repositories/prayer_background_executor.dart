import 'package:timezone/data/latest_all.dart' as tz;
import 'package:workmanager/workmanager.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../domain/entities/prayer_entities.dart';
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

      // 3. Calculate today + 6 days ahead so notifications are pre-scheduled
      //    in AlarmManager. This provides a buffer against delayed Workmanager
      //    resync tasks — even if the daily periodic job is late by hours,
      //    the exact-alarm notifications for the next week are already sitting
      //    in AlarmManager.
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      AppLogger.debug("Calculating prayer times for $now + 6 days ahead");

      final daysData = <(DateTime, PrayerTimeEntity)>[];
      for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
        final date = todayStart.add(Duration(days: dayOffset));
        try {
          final times = await calculateTimes(
            location: location,
            date: date,
            settings: prayerSettings,
          );
          daysData.add((date, times));
          AppLogger.debug("Day $dayOffset ($date): Fajr=${times.fajr}, Dhuhr=${times.dhuhr}, Asr=${times.asr}, Maghrib=${times.maghrib}, Isha=${times.isha}");
        } catch (e) {
          AppLogger.warning("Failed to calculate times for day $dayOffset ($date): $e");
        }
      }

      if (daysData.isEmpty) {
        AppLogger.error("No prayer times calculated for any day — cannot schedule");
        return false;
      }

      // 4. Schedule prayer/adhan notifications for all 7 days, then
      //    Adhkar reminders. The multi-day approach means even if the next
      //    Workmanager resync is delayed, alarms for the coming week are
      //    already in AlarmManager.
      AppLogger.debug("Initializing notification service");
      await notificationService.initialize();

      AppLogger.debug("Scheduling multi-day prayer notifications (${daysData.length} days)");
      await notificationService.scheduleMultiDayNotifications(
        daysData,
        prayerSettings,
        appSettings.adhanType,
        language: appSettings.language,
      );

      // Adhkar reminders use only today + tomorrow (fixed IDs 2001/2002).
      final todayTimes = daysData.first.$2;
      final tomorrowTimes = daysData.length > 1 ? daysData[1].$2 : null;
      AppLogger.debug("Scheduling Adhkar reminders");
      await notificationService.scheduleAdhkarReminders(
        todayTimes,
        morningEnabled: appSettings.morningAdhkarReminderEnabled,
        eveningEnabled: appSettings.eveningAdhkarReminderEnabled,
        language: appSettings.language,
        nextDayTimes: tomorrowTimes,
      );

      // Schedule a best-effort rollover task a few minutes after tomorrow's
      // Fajr, so the schedule deterministically advances to the next day
      // even if the OS delays the daily periodic task. This is purely a
      // safety net — the 7-day exact-alarm notifications already cover
      // the coming week.
      try {
        final now = DateTime.now();
        // Use tomorrow's Fajr from the pre-computed daysData
        final tomorrowFajr = daysData.length > 1
            ? daysData[1].$2.fajr
            : daysData[0].$2.fajr.add(const Duration(days: 1));
        var rolloverDelay = tomorrowFajr.difference(now) + const Duration(minutes: 3);
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
  /// Uses `ExistingPeriodicWorkPolicy.keep` so an already-registered task
  /// is not replaced (which would cancel any pending execution). The task
  /// only gets a fresh registration on first install or after a Workmanager
  /// schema change.
  static Future<void> scheduleDailyAdhanTask() async {
    AppLogger.info('PrayerBackgroundExecutor.scheduleDailyAdhanTask called');
    try {
      await Workmanager().registerPeriodicTask(
        "daily_adhan_rescheduler",
        "dailyAdhanRescheduleTask",
        frequency: const Duration(hours: 24),
        initialDelay: const Duration(minutes: 1),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
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
