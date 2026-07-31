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

  /// Schedules the background adhan scheduler task to run every 15 minutes.
  static Future<void> scheduleDailyAdhanTask() async {
    AppLogger.info('PrayerBackgroundExecutor.scheduleDailyAdhanTask called');
    try {
      await Workmanager().registerPeriodicTask(
        "daily_adhan_rescheduler",
        "dailyAdhanRescheduleTask",
        frequency: const Duration(minutes: 15),
        initialDelay: const Duration(minutes: 1),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        constraints: Constraints(
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      AppLogger.info('Background prayer task registered successfully (every 15 minutes)');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to register periodic task', error: e, stackTrace: stackTrace);
    }
  }
}
