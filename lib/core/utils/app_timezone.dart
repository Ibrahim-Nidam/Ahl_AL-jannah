import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_logger.dart';

/// Initializes the timezone database and `tz.local` in any isolate.
class AppTimeZone {
  AppTimeZone._();

  static bool _initialized = false;

  static Future<void> ensureInitialized() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      AppLogger.debug('Local timezone set to $timeZoneName');
    } catch (e) {
      AppLogger.warning('Could not resolve device timezone, using tz.local fallback: $e');
    }
    _initialized = true;
  }

  static Future<void> refreshTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      AppLogger.debug('Local timezone refreshed to $timeZoneName');
    } catch (e) {
      AppLogger.warning('Could not resolve device timezone on refresh: $e');
    }
  }

  static bool get isInitialized => _initialized;
}
