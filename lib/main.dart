/// Entry point for Ahl Jannah.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/utils/app_logger.dart';
import 'core/utils/app_timezone.dart';
import 'features/prayer/data/repositories/prayer_background_executor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logger first to capture all startup events
  await AppLogger.initialize();
  AppLogger.info("App starting up");

  await AppTimeZone.ensureInitialized();
  AppLogger.debug("Timezone database initialized");

  // Initialize localized date formatting for Arabic, English, and French.
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('fr', null);
  AppLogger.debug("Date formatting initialized");

  // Lock to portrait orientation for consistent Islamic text layout.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure dependency injection.
  configureDependencies();
  AppLogger.debug("Dependency injection configured");

  // Initialize background prayer rescheduler.
  await PrayerBackgroundExecutor.initialize();
  await PrayerBackgroundExecutor.scheduleDailyAdhanTask();
  AppLogger.info("Background prayer executor initialized");

  // Arm next prayer alarms immediately so they do not depend on opening
  // the Prayer tab. Failures here must never block the UI.
  // ignore: unawaited_futures
  PrayerBackgroundExecutor.syncAlarms().then(
    (_) {},
    onError: (Object e, StackTrace st) {
      AppLogger.error('Startup prayer alarm sync failed', error: e, stackTrace: st);
    },
  );

  runApp(const AhlJannahApp());
}
