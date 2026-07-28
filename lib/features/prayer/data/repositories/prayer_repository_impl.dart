import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/prayer_entities.dart';
import '../../domain/repositories/prayer_repository.dart';

@LazySingleton(as: PrayerRepository)
class PrayerRepositoryImpl implements PrayerRepository {
  static const String _keyLatitude = 'prayer_latitude';
  static const String _keyLongitude = 'prayer_longitude';
  static const String _keyCityName = 'prayer_city_name';


  @override
  Future<UserLocation?> getCachedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLatitude);
    final lng = prefs.getDouble(_keyLongitude);
    final city = prefs.getString(_keyCityName);

    if (lat != null && lng != null) {
      return UserLocation(latitude: lat, longitude: lng, cityName: city);
    }
    return null;
  }

  @override
  Future<void> cacheLocation(UserLocation location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLatitude, location.latitude);
    await prefs.setDouble(_keyLongitude, location.longitude);
    if (location.cityName != null) {
      await prefs.setString(_keyCityName, location.cityName!);
    } else {
      await prefs.remove(_keyCityName);
    }
  }

  static const String _keyNotificationsEnabled = 'prayer_notifications_enabled';
  static const String _keyReminderInterval = 'prayer_reminder_interval_minutes';
  static const String _keyMutedPrayers = 'prayer_muted_list';
  static const String _keyUseAutomaticMethod = 'prayer_use_automatic_method';
  static const String _keyManualMethodId = 'prayer_manual_method_id';
  static const String _keyMadhab = 'prayer_madhab';

  @override
  Future<PrayerTimesSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();

    final enabled = prefs.getBool(_keyNotificationsEnabled) ?? true;
    final interval = prefs.getInt(_keyReminderInterval) ?? 5;
    final mutedList = prefs.getStringList(_keyMutedPrayers) ?? [];
    final useAutomatic = prefs.getBool(_keyUseAutomaticMethod) ?? true;
    final manualMethodId = prefs.containsKey(_keyManualMethodId) ? prefs.getInt(_keyManualMethodId) : null;
    final madhab = prefs.getInt(_keyMadhab) ?? 0;

    return PrayerTimesSettings(
      notificationsEnabled: enabled,
      reminderInterval: interval,
      mutedPrayers: mutedList,
      useAutomaticMethod: useAutomatic,
      manualMethodId: manualMethodId,
      madhab: madhab,
    );
  }

  @override
  Future<void> saveSettings(PrayerTimesSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotificationsEnabled, settings.notificationsEnabled);
    await prefs.setInt(_keyReminderInterval, settings.reminderInterval);
    await prefs.setStringList(_keyMutedPrayers, settings.mutedPrayers);
    await prefs.setBool(_keyUseAutomaticMethod, settings.useAutomaticMethod);
    if (settings.manualMethodId != null) {
      await prefs.setInt(_keyManualMethodId, settings.manualMethodId!);
    } else {
      await prefs.remove(_keyManualMethodId);
    }
    await prefs.setInt(_keyMadhab, settings.madhab);
  }

  static const String _keyIsManualLocation = 'prayer_is_manual_location';

  @override
  Future<bool> isManualLocation() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsManualLocation) ?? false;
  }

  @override
  Future<void> setManualLocation(bool isManual) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsManualLocation, isManual);
  }

  static const String _keyMonthlyPrayerTimes = 'prayer_monthly_times';

  @override
  Future<String?> getCachedMonthlyPrayerTimes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyMonthlyPrayerTimes);
  }

  @override
  Future<void> cacheMonthlyPrayerTimes(String json) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMonthlyPrayerTimes, json);
  }
}
