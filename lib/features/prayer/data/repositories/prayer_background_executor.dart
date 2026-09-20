import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/app_timezone.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../domain/entities/prayer_entities.dart';
import '../../domain/usecases/prayer_usecases.dart';
import 'prayer_notification_service.dart';

@pragma('vm:entry-point')
void prayerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    AppLogger.info("Workmanager background task started: $taskName");
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.initialize();
      await AppTimeZone.ensureInitialized();
      configureDependencies();
      await PrayerBackgroundExecutor.syncAlarms();
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

  /// Recalculates prayer times and arms native/iOS alarms for the next week.
  /// Safe to call from the UI isolate or a Workmanager isolate after DI is ready.
  static Future<void> syncAlarms() async {
    AppLogger.info('PrayerBackgroundExecutor.syncAlarms called');
    await AppTimeZone.ensureInitialized();

    final getLocation = getIt<GetUserLocationUseCase>();
    final getPrayerSettings = getIt<GetPrayerSettingsUseCase>();
    final getAppSettings = getIt<GetSettingsUseCase>();
    final calculateTimes = getIt<CalculatePrayerTimesUseCase>();
    final notificationService = getIt<PrayerNotificationService>();

    final location = await getLocation();
    final prayerSettings = await getPrayerSettings();
    final appSettings = await getAppSettings();

    AppLogger.info(
      'Location: ${location.cityName}, Notifications enabled: ${prayerSettings.notificationsEnabled}',
    );

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

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
      } catch (e) {
        AppLogger.warning('Failed to calculate times for day $dayOffset ($date): $e');
      }
    }

    if (daysData.isEmpty) {
      AppLogger.error('No prayer times calculated for any day — cannot schedule');
      return;
    }

    await notificationService.initialize();
    await notificationService.scheduleMultiDayNotifications(
      daysData,
      prayerSettings,
      appSettings.adhanType,
      language: appSettings.language,
    );

    final todayTimes = daysData.first.$2;
    final tomorrowTimes = daysData.length > 1 ? daysData[1].$2 : null;
    await notificationService.scheduleAdhkarReminders(
      todayTimes,
      morningEnabled: appSettings.morningAdhkarReminderEnabled,
      eveningEnabled: appSettings.eveningAdhkarReminderEnabled,
      language: appSettings.language,
      nextDayTimes: tomorrowTimes,
    );

    try {
      final tomorrowFajr = daysData.length > 1
          ? daysData[1].$2.fajr
          : daysData[0].$2.fajr.add(const Duration(days: 1));
      var rolloverDelay = tomorrowFajr.difference(DateTime.now()) + const Duration(minutes: 3);
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
  }

  /// Registers the daily safety-net task that re-establishes the prayer
  /// notifications.
  static Future<void> scheduleDailyAdhanTask() async {
    AppLogger.info('PrayerBackgroundExecutor.scheduleDailyAdhanTask called');
    try {
      await Workmanager().registerPeriodicTask(
        "daily_adhan_rescheduler",
        "dailyAdhanRescheduleTask",
        frequency: const Duration(hours: 12),
        initialDelay: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      AppLogger.info('Background prayer safety-net task registered (12h)');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to register periodic task', error: e, stackTrace: stackTrace);
    }
  }
}
