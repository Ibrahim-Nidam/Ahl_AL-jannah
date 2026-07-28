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

  /// Retrieves cached monthly prayer times in JSON string format.
  Future<String?> getCachedMonthlyPrayerTimes();

  /// Caches monthly prayer times JSON string.
  Future<void> cacheMonthlyPrayerTimes(String json);
}
