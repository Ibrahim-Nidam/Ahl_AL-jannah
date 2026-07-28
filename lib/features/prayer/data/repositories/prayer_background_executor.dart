import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';

import '../../../../core/di/injection.dart';
import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../domain/usecases/prayer_usecases.dart';
import 'prayer_notification_service.dart';

@pragma('vm:entry-point')
void prayerCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint("Workmanager background task started: $taskName");
    try {
      // 1. Initialize DI so we can retrieve dependencies
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

      final location = await getLocation();
      final prayerSettings = await getPrayerSettings();
      final appSettings = await getAppSettings();

      // 3. Calculate today + tomorrow so past prayers fall through to
      //    tomorrow's times (covers overnight Fajr without waiting for
      //    the next Workmanager tick).
      final now = DateTime.now();
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

      // 4. Schedule prayer/adhan notifications, then Adhkar reminders.
      //    Adhkar scheduling must come after prayer scheduling — the
      //    latter does a full `cancelAllNotifications()` first, which
      //    would otherwise wipe out freshly-scheduled Adhkar reminders.
      await notificationService.initialize();
      await notificationService.schedulePrayerNotifications(
        todayTimes,
        prayerSettings,
        appSettings.adhanType,
        language: appSettings.language,
        nextDayTimes: nextDayTimes,
      );
      await notificationService.scheduleAdhkarReminders(
        todayTimes,
        morningEnabled: appSettings.morningAdhkarReminderEnabled,
        eveningEnabled: appSettings.eveningAdhkarReminderEnabled,
        language: appSettings.language,
        nextDayTimes: nextDayTimes,
      );

      debugPrint("Workmanager background task completed successfully.");
      return true;
    } catch (e) {
      debugPrint("Error in Workmanager background task: $e");
      return false;
    }
  });
}

/// Helper class to initialize and manage background work scheduling.
class PrayerBackgroundExecutor {
  /// Initializes Workmanager for scheduling notifications.
  static Future<void> initialize() async {
    await Workmanager().initialize(
      prayerCallbackDispatcher,
    );
  }

  /// Schedules the background adhan scheduler task to run daily.
  static Future<void> scheduleDailyAdhanTask() async {
    final delay = _calculateDelayUntilMidnight();
    debugPrint("Scheduling daily background prayer task. Initial delay: ${delay.inMinutes} minutes");

    await Workmanager().registerPeriodicTask(
      "daily_adhan_rescheduler",
      "dailyAdhanRescheduleTask",
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  static Duration _calculateDelayUntilMidnight() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    return midnight.difference(now);
  }
}