import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_logger.dart';

/// Android-only bridge to AlarmManager.setAlarmClock + the Adhan foreground
/// service. Flutter writes the full upcoming alarm list to a JSON file that
/// native code can read even after a reboot, then asks native to arm the
/// next few clock alarms.
class NativePrayerAlarms {
  NativePrayerAlarms._();

  static const MethodChannel _channel =
      MethodChannel('com.ibrahimnidam.ahljannah/prayer_alarms');
  static const String _fileName = 'prayer_alarms.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<List<Map<String, dynamic>>> readAll() async {
    try {
      final file = await _file();
      if (!await file.exists()) return [];
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to read native prayer alarms', error: e);
      return [];
    }
  }

  /// Replaces every alarm in [group] (`prayer`, `adhkar`, or `test`) and
  /// re-arms AlarmManager from the merged list.
  static Future<void> upsert(
    List<Map<String, dynamic>> alarms, {
    required String group,
  }) async {
    if (!Platform.isAndroid) return;
    final existing = await readAll();
    existing.removeWhere((item) => item['group'] == group);
    existing.addAll(alarms.map((item) => {...item, 'group': group}));
    existing.sort((a, b) {
      final aMs = (a['triggerAtMillis'] as num?)?.toInt() ?? 0;
      final bMs = (b['triggerAtMillis'] as num?)?.toInt() ?? 0;
      return aMs.compareTo(bMs);
    });
    final file = await _file();
    await file.writeAsString(jsonEncode(existing));
    AppLogger.info(
      'Wrote ${existing.length} native alarms (${alarms.length} in group "$group")',
    );
    await notifyNative();
  }

  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    final file = await _file();
    await file.writeAsString('[]');
    try {
      await _channel.invokeMethod('cancelAll');
    } catch (_) {
      await notifyNative();
    }
  }

  static Future<void> notifyNative() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('applySchedule');
      return;
    } catch (_) {
      // Background isolate (Workmanager) has no MainActivity channel.
    }
    try {
      const intent = AndroidIntent(
        action: 'com.ibrahimnidam.ahljannah.RESCHEDULE_PRAYER_ALARMS',
        package: AppConstants.orgName,
        componentName: 'com.ibrahimnidam.ahljannah.PrayerAlarmRescheduleReceiver',
      );
      await intent.sendBroadcast();
    } catch (e) {
      debugPrint('Failed to notify native prayer scheduler: $e');
    }
  }

  static Future<void> stopAdhan() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopAdhan');
    } catch (_) {
      try {
        const intent = AndroidIntent(
          action: 'com.ibrahimnidam.ahljannah.STOP_ADHAN',
          package: AppConstants.orgName,
          componentName: 'com.ibrahimnidam.ahljannah.PrayerAlarmReceiver',
        );
        await intent.sendBroadcast();
      } catch (e) {
        debugPrint('Failed to stop native adhan: $e');
      }
    }
  }

  static Future<bool> isAdhanPlaying() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isAdhanPlaying') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) return true;
    try {
      return await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;
    } catch (_) {
      return false;
    }
  }
}
