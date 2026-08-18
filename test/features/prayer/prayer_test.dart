import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'package:ahl_jannah/features/prayer/domain/entities/prayer_entities.dart';
import 'package:ahl_jannah/features/prayer/domain/usecases/prayer_usecases.dart';
import 'package:ahl_jannah/features/prayer/domain/repositories/prayer_repository.dart';
import 'package:ahl_jannah/features/prayer/data/repositories/prayer_repository_impl.dart';

class MockPrayerRepository implements PrayerRepository {
  UserLocation? _location;
  PrayerTimesSettings _settings = const PrayerTimesSettings(
    notificationsEnabled: true,
    adhanSoundEnabled: true,
    silentPrayers: [],
    reminderInterval: 5,
    mutedPrayers: [],
    useAutomaticMethod: true,
    madhab: 0,
  );
  bool _isManual = false;
  final Map<String, String> _monthlyCache = {};

  @override
  Future<UserLocation?> getCachedLocation() async => _location;

  @override
  Future<void> cacheLocation(UserLocation location) async => _location = location;

  @override
  Future<PrayerTimesSettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(PrayerTimesSettings settings) async => _settings = settings;

  @override
  Future<bool> isManualLocation() async => _isManual;

  @override
  Future<void> setManualLocation(bool isManual) async => _isManual = isManual;

  @override
  Future<String?> getCachedMonthlyPrayerTimes(int year, int month) async =>
      _monthlyCache['$year-$month'];

  @override
  Future<void> cacheMonthlyPrayerTimes(int year, int month, String json) async {
    _monthlyCache['$year-$month'] = json;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  group('Prayer Times Calculations & Methods', () {
    test('estimateAladhanMethod estimates correctly based on coordinates', () {
      // Cairo coordinates -> Egyptian (5)
      expect(estimateAladhanMethod(30.0444, 31.2357), 5);

      // New York -> ISNA (2)
      expect(estimateAladhanMethod(40.7128, -74.0060), 2);

      // Riyadh -> Umm Al Qura (4)
      expect(estimateAladhanMethod(24.7136, 46.6753), 4);

      // London -> Muslim World League (3)
      expect(estimateAladhanMethod(51.5074, -0.1278), 3);
    });

    test('CalculatePrayerTimesUseCase successfully reads and parses offline cached Aladhan JSON', () async {
      final repo = MockPrayerRepository();
      final calcUseCase = CalculatePrayerTimesUseCase(repo);

      final date = DateTime(2026, 7, 3);
      final location = const UserLocation(
        latitude: 33.5731,
        longitude: -7.5898,
        cityName: 'Casablanca',
      );

      final mockCalendarWrapper = {
        'month': 7,
        'year': 2026,
        'latitude': 33.5731,
        'longitude': -7.5898,
        'timezone': 'Africa/Casablanca',
        'methodId': 21,
        'school': 0,
        'data': [
          {
            'timings': {
              'Fajr': '2026-07-03T04:42:00+01:00',
              'Sunrise': '2026-07-03T06:25:00+01:00',
              'Dhuhr': '2026-07-03T13:35:00+01:00',
              'Asr': '2026-07-03T17:19:00+01:00',
              'Maghrib': '2026-07-03T20:44:00+01:00',
              'Isha': '2026-07-03T22:20:00+01:00',
            },
            'date': {
              'gregorian': {'day': '03', 'month': {'number': 7}, 'year': '2026'},
              'hijri': {'day': '18', 'month': {'en': 'Muharram'}, 'year': '1448'}
            }
          }
        ]
      };

      await repo.cacheMonthlyPrayerTimes(
        2026,
        7,
        jsonEncode(mockCalendarWrapper),
      );

      final settings = const PrayerTimesSettings(
        notificationsEnabled: true,
        adhanSoundEnabled: true,
        silentPrayers: [],
        reminderInterval: 5,
        mutedPrayers: [],
        useAutomaticMethod: true,
        madhab: 0,
      );

      final times = await calcUseCase(
        location: location,
        date: date,
        settings: settings,
      );

      expect(times.hijriDateStr, contains('Muharram'));
      expect(times.fajr.hour, 4);
      expect(times.fajr.minute, 42);
      expect(times.dhuhr.hour, 13);
      expect(times.dhuhr.minute, 35);
      expect(times.maghrib.hour, 20);
      expect(times.maghrib.minute, 44);
    });
  });

  group('Prayer Repository SharedPreferences Caching', () {
    late PrayerRepositoryImpl repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({
        'prayer_latitude': 33.5731,
        'prayer_longitude': -7.5898,
        'prayer_city_name': 'Casablanca',
        'prayer_notifications_enabled': true,
        'prayer_reminder_interval_minutes': 15,
        'prayer_muted_list': ['fajr'],
      });
      repository = PrayerRepositoryImpl();
    });

    test('loads cached settings and location details correctly', () async {
      final location = await repository.getCachedLocation();
      expect(location, isNotNull);
      expect(location!.latitude, 33.5731);
      expect(location.cityName, 'Casablanca');

      final settings = await repository.getSettings();
      expect(settings.notificationsEnabled, true);
      expect(settings.reminderInterval, 15);
      expect(settings.mutedPrayers, contains('fajr'));
    });

    test('saves settings changes to shared preferences', () async {
      final newSettings = const PrayerTimesSettings(
        notificationsEnabled: false,
        adhanSoundEnabled: false,
        silentPrayers: ['isha'],
        reminderInterval: 5,
        mutedPrayers: ['dhuhr', 'asr'],
        useAutomaticMethod: true,
        madhab: 0,
      );

      await repository.saveSettings(newSettings);

      final loaded = await repository.getSettings();
      expect(loaded.notificationsEnabled, false);
      expect(loaded.adhanSoundEnabled, false);
      expect(loaded.reminderInterval, 5);
      expect(loaded.mutedPrayers, contains('dhuhr'));
      expect(loaded.mutedPrayers, contains('asr'));
      expect(loaded.silentPrayers, contains('isha'));
    });
  });
}
