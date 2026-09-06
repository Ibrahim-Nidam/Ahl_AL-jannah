import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/utils/app_logger.dart';

/// Cross-isolate lock that prevents concurrent notification scheduling.
///
/// Uses SharedPreferences as the backing store so both the main isolate
/// and Workmanager background isolate can coordinate. The lock has a short
/// TTL (30 seconds) to auto-recover from crashed holders.
class SchedulingLock {
  static const String _lockKey = '_notification_scheduling_lock';
  static const String _lockTimestampKey = '_notification_scheduling_lock_ts';
  static const Duration _lockTtl = Duration(seconds: 30);
  static const Duration _acquireTimeout = Duration(seconds: 10);
  static const Duration _pollInterval = Duration(milliseconds: 200);

  /// Acquires the scheduling lock. Returns true if acquired, false if
  /// timed out waiting. SharedPreferences-backed so it works across isolates.
  static Future<bool> acquire() async {
    final deadline = DateTime.now().add(_acquireTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final currentlyLocked = prefs.getBool(_lockKey) ?? false;
        final lockTs = prefs.getString(_lockTimestampKey);

        // Auto-expire stale locks (holder crashed or isolate was killed)
        if (currentlyLocked && lockTs != null) {
          final ts = DateTime.tryParse(lockTs);
          if (ts != null && DateTime.now().difference(ts) > _lockTtl) {
            AppLogger.warning('[SchedulingLock] Stale lock detected (age: ${DateTime.now().difference(ts)}), force-releasing');
            await _forceRelease(prefs);
            currentlyLocked; // re-evaluate
          }
        }

        if (!currentlyLocked) {
          // Attempt atomic acquire via setBool (returns false if another
          // isolate wrote between our read and write — acceptable race)
          await prefs.setString(_lockTimestampKey, DateTime.now().toIso8601String());
          final acquired = await prefs.setBool(_lockKey, true);
          if (acquired) {
            AppLogger.debug('[SchedulingLock] Lock acquired');
            return true;
          }
        }
      } catch (e) {
        AppLogger.error('[SchedulingLock] Error acquiring lock', error: e);
      }
      await Future<void>.delayed(_pollInterval);
    }
    AppLogger.warning('[SchedulingLock] Failed to acquire lock within $_acquireTimeout');
    return false;
  }

  /// Releases the scheduling lock.
  static Future<void> release() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _forceRelease(prefs);
      AppLogger.debug('[SchedulingLock] Lock released');
    } catch (e) {
      AppLogger.error('[SchedulingLock] Error releasing lock', error: e);
    }
  }

  static Future<void> _forceRelease(SharedPreferences prefs) async {
    await prefs.setBool(_lockKey, false);
    await prefs.remove(_lockTimestampKey);
  }
}
