import '../entities/prayer_entities.dart';

/// Repository contract for caching user location and prayer preferences offline.
abstract interface class PrayerRepository {
  /// Retrieves cached GPS coordinates of the user. Returns null if none cached.
  Future<UserLocation?> getCachedLocation();

  /// Persists user coordinates.
  Future<void> cacheLocation(UserLocation location);

  /// Retrieves user settings for calculation method, madhab, and notifications.
  Future<PrayerTimesSettings> getSettings();

  /// Persists user settings for calculation method, madhab, and notifications.
  Future<void> saveSettings(PrayerTimesSettings settings);

  /// Checks if the location was set manually by the user.
  Future<bool> isManualLocation();

  /// Sets whether the location is manual.
  Future<void> setManualLocation(bool isManual);

  /// Retrieves cached prayer times for a specific month (1-indexed) in JSON
  /// string format, or `null` if that month has not been cached.
  Future<String?> getCachedMonthlyPrayerTimes(int year, int month);

  /// Caches prayer times for a specific month (1-indexed) as a JSON string.
  /// Only the current and next month are retained on disk; any older cached
  /// months are pruned to keep storage bounded.
  Future<void> cacheMonthlyPrayerTimes(int year, int month, String json);
}
