/// Entry point for Ahl Jannah.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'app.dart';
import 'core/di/injection.dart';
import 'features/prayer/data/repositories/prayer_background_executor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize timezone database early — required by prayer time parsing.
  tz.initializeTimeZones();

  // Initialize localized date formatting for Arabic, English, and French.
  await initializeDateFormatting('ar', null);
  await initializeDateFormatting('en', null);
  await initializeDateFormatting('fr', null);

  // Lock to portrait orientation for consistent Islamic text layout.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure dependency injection.
  configureDependencies();

  // Initialize background prayer rescheduler.
  await PrayerBackgroundExecutor.initialize();
  await PrayerBackgroundExecutor.scheduleDailyAdhanTask();

  runApp(const AhlJannahApp());
}
