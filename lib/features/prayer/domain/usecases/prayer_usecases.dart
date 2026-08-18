import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;

import '../entities/prayer_entities.dart';
import '../repositories/prayer_repository.dart';

int estimateAladhanMethod(double latitude, double longitude) {
  // Morocco (Casablanca coordinates: 33.5, -7.6)
  if (latitude >= 21.0 && latitude <= 36.0 && longitude >= -17.0 && longitude <= -1.0) {
    return 21; // Minister of Awqaf and Islamic Affairs (Morocco)
  }
  // Tunisia
  if (latitude >= 30.0 && latitude <= 38.0 && longitude >= 7.0 && longitude <= 12.0) {
    return 18; // Tunisia
  }
  // Algeria
  if (latitude >= 19.0 && latitude <= 37.0 && longitude >= -9.0 && longitude <= 12.0) {
    return 19; // Algeria
  }
  // France
  if (latitude >= 41.0 && latitude <= 51.0 && longitude >= -5.0 && longitude <= 10.0) {
    return 12; // Union Organisation Islamique de France
  }
  // Gulf region / Saudi Arabia
  if (latitude >= 12.0 && latitude <= 32.0 && longitude >= 34.0 && longitude <= 60.0) {
    return 4; // Umm Al-Qura
  }
  // North America
  if (latitude >= 24.0 && latitude <= 72.0 && longitude >= -125.0 && longitude <= -66.0) {
    return 2; // ISNA
  }
  // Indian subcontinent
  if (latitude >= 5.0 && latitude <= 38.0 && longitude >= 60.0 && longitude <= 98.0) {
    return 1; // Karachi
  }
  // Egypt
  if (latitude >= 22.0 && latitude <= 32.0 && longitude >= 25.0 && longitude <= 35.0) {
    return 5; // Egyptian
  }
  // Default to Muslim World League
  return 3;
}

/// Thrown when prayer times are requested but no exact-month cache exists
/// and no live fetch can be made (e.g. offline and this month was never
/// cached). Deliberately does NOT fall back to another month's data or
/// static approximations — wrong times are worse than showing an honest
/// "no data" state.
class PrayerTimesUnavailableException implements Exception {
  final DateTime requestedDate;

  PrayerTimesUnavailableException(this.requestedDate);

  @override
  String toString() =>
      'No prayer times available for ${requestedDate.year}-${requestedDate.month}-${requestedDate.day}. '
      'Connect to the internet once to cache prayer times.';
}

@lazySingleton
class CalculatePrayerTimesUseCase {
  final PrayerRepository _repository;

  const CalculatePrayerTimesUseCase(this._repository);

  // Memory cache variables — keyed by month/year AND the parameters that
  // affect the result (method, school, coordinates), so a settings or
  // location change can never silently serve stale times.
  static List<dynamic>? _activeDataList;
  static String? _activeTimezone;
  static int? _activeMonth;
  static int? _activeYear;
  static int? _activeMethodId;
  static int? _activeSchool;
  static double? _activeLat;
  static double? _activeLng;

  // Guards the once-per-session prefetch of next month, so opening the app
  // does not hammer the API on every `call`.
  static int? _prefetchedNextYear;
  static int? _prefetchedNextMonth;

  Future<PrayerTimeEntity> call({
    required UserLocation location,
    required DateTime date,
    required PrayerTimesSettings settings,
  }) async {
    final methodId = settings.useAutomaticMethod
        ? estimateAladhanMethod(location.latitude, location.longitude)
        : (settings.manualMethodId ?? 3);
    final school = settings.madhab;

    // 1. In-memory cache for this session (fast path).
    final fromMemory = _fromActiveList(
      location: location,
      date: date,
      methodId: methodId,
      school: school,
    );
    if (fromMemory != null) return fromMemory;

    // 2. Exact-month disk cache.
    final cachedJson = await _repository.getCachedMonthlyPrayerTimes(
      date.year,
      date.month,
    );
    if (cachedJson != null) {
      final parsed = _parseCachedMonth(
        cachedJson,
        location: location,
        date: date,
        methodId: methodId,
        school: school,
      );
      if (parsed != null) return parsed;
    }

    // 3. Live fetch of the requested month (when online).
    final fetched = await _fetchMonth(
      location: location,
      year: date.year,
      month: date.month,
      methodId: methodId,
      school: school,
    );
    if (fetched != null) {
      final dayData = _findDayInList(fetched.dataList, date.day);
      if (dayData != null) {
        _setActive(
          dataList: fetched.dataList,
          timezoneName: fetched.timezoneName,
          year: date.year,
          month: date.month,
          methodId: methodId,
          school: school,
          latitude: location.latitude,
          longitude: location.longitude,
        );
        debugPrint('[PrayerTimes] Successfully parsed prayer times from Aladhan API');
        return _parseDayData(dayData, date, fetched.timezoneName);
      }
    }

    // 4. No exact-month data available (offline and this month was never
    //    cached). Never substitute another month's times.
    throw PrayerTimesUnavailableException(date);
  }

  /// Looks up [date]'s prayer times purely from the in-memory month cache.
  /// Returns `null` when the month (or the calculation parameters it was
  /// fetched with) does not match — callers must treat `null` as "not
  /// available" rather than guessing.
  PrayerTimeEntity? calculateLocal({
    required UserLocation location,
    required DateTime date,
    required PrayerTimesSettings settings,
  }) {
    final methodId = settings.useAutomaticMethod
        ? estimateAladhanMethod(location.latitude, location.longitude)
        : (settings.manualMethodId ?? 3);
    final school = settings.madhab;

    if (_activeDataList == null || _activeTimezone == null) return null;
    if (_activeMonth != date.month || _activeYear != date.year) return null;
    if (_activeMethodId != methodId || _activeSchool != school) return null;
    if (!_coordsClose(
      _activeLat,
      _activeLng,
      location.latitude,
      location.longitude,
    )) {
      return null;
    }

    final dayData = _findDayInList(_activeDataList!, date.day);
    if (dayData == null) return null;
    return _parseDayData(dayData, date, _activeTimezone!);
  }

  /// Fast path lookup against the in-memory month cache, with the same
  /// parameter validation as [calculateLocal].
  PrayerTimeEntity? _fromActiveList({
    required UserLocation location,
    required DateTime date,
    required int methodId,
    required int school,
  }) {
    if (_activeDataList == null || _activeTimezone == null) return null;
    if (_activeMonth != date.month || _activeYear != date.year) return null;
    if (_activeMethodId != methodId || _activeSchool != school) return null;
    if (!_coordsClose(
      _activeLat,
      _activeLng,
      location.latitude,
      location.longitude,
    )) {
      return null;
    }
    final dayData = _findDayInList(_activeDataList!, date.day);
    if (dayData == null) return null;
    return _parseDayData(dayData, date, _activeTimezone!);
  }

  /// Validates a cached month payload against the current request
  /// parameters and, if it matches, returns the parsed day.
  PrayerTimeEntity? _parseCachedMonth(
    String cachedJson, {
    required UserLocation location,
    required DateTime date,
    required int methodId,
    required int school,
  }) {
    try {
      final Map<String, dynamic> cachedData = jsonDecode(cachedJson);
      final cachedMonth = cachedData['month'] as int?;
      final cachedYear = cachedData['year'] as int?;
      final cachedLat = cachedData['latitude'] as double?;
      final cachedLng = cachedData['longitude'] as double?;
      final timezoneName = cachedData['timezone'] as String?;
      final cachedMethodId = cachedData['methodId'] as int?;
      final cachedSchool = cachedData['school'] as int?;
      final dataList = cachedData['data'] as List<dynamic>?;

      if (cachedMonth != date.month ||
          cachedYear != date.year ||
          timezoneName == null ||
          dataList == null ||
          cachedLat == null ||
          cachedLng == null ||
          cachedMethodId != methodId ||
          cachedSchool != school) {
        return null;
      }
      if (!_coordsClose(
        cachedLat,
        cachedLng,
        location.latitude,
        location.longitude,
      )) {
        return null;
      }
      final dayData = _findDayInList(dataList, date.day);
      if (dayData == null) return null;
      _setActive(
        dataList: dataList,
        timezoneName: timezoneName,
        year: date.year,
        month: date.month,
        methodId: methodId,
        school: school,
        latitude: location.latitude,
        longitude: location.longitude,
      );
      return _parseDayData(dayData, date, timezoneName);
    } catch (_) {
      return null;
    }
  }

  /// Fetches one month from the Aladhan API and caches it on disk. After a
  /// successful fetch it also prefetches the *next* real month, so the
  /// month rollover keeps working offline (current + next month only).
  Future<_FetchedMonth?> _fetchMonth({
    required UserLocation location,
    required int year,
    required int month,
    required int methodId,
    required int school,
  }) async {
    final client = HttpClient();
    try {
      debugPrint('[PrayerTimes] Fetching Aladhan API for $year/$month method=$methodId school=$school lat=${location.latitude} lng=${location.longitude}');
      final url = Uri.parse(
        'https://api.aladhan.com/v1/calendar/$year/$month'
        '?latitude=${location.latitude}'
        '&longitude=${location.longitude}'
        '&method=$methodId'
        '&school=$school'
        '&iso8601=true',
      );

      final request = await client.getUrl(url).timeout(const Duration(seconds: 8));
      request.headers.set(HttpHeaders.userAgentHeader, 'AhlJannahApp/1.0');
      final response = await request.close();

      debugPrint('[PrayerTimes] Aladhan API response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;

        if (jsonMap['code'] == 200 && jsonMap['data'] != null) {
          final dataList = jsonMap['data'] as List<dynamic>;
          if (dataList.isNotEmpty) {
            final timezoneName = dataList[0]['meta']?['timezone'] as String? ?? 'UTC';

            final cacheWrapper = {
              'month': month,
              'year': year,
              'latitude': location.latitude,
              'longitude': location.longitude,
              'timezone': timezoneName,
              'methodId': methodId,
              'school': school,
              'data': dataList,
            };
            await _repository.cacheMonthlyPrayerTimes(year, month, jsonEncode(cacheWrapper));

            await _prefetchNextMonth(
              location: location,
              methodId: methodId,
              school: school,
            );

            return _FetchedMonth(dataList, timezoneName);
          }
        }
      }
    } catch (e) {
      debugPrint('[PrayerTimes] Aladhan API call failed: $e');
    } finally {
      client.close();
    }
    return null;
  }

  /// Ensures the next real month is cached (once per session), so an
  /// offline user on the last days of a month still has the rollover
  /// covered. Never caches beyond current + next month.
  Future<void> _prefetchNextMonth({
    required UserLocation location,
    required int methodId,
    required int school,
  }) async {
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1, 1);
    if (_prefetchedNextYear == next.year && _prefetchedNextMonth == next.month) {
      return;
    }
    _prefetchedNextYear = next.year;
    _prefetchedNextMonth = next.month;

    final existing = await _repository.getCachedMonthlyPrayerTimes(
      next.year,
      next.month,
    );
    if (existing != null) return;

    await _fetchMonth(
      location: location,
      year: next.year,
      month: next.month,
      methodId: methodId,
      school: school,
    );
  }

  void _setActive({
    required List<dynamic> dataList,
    required String timezoneName,
    required int year,
    required int month,
    required int methodId,
    required int school,
    required double latitude,
    required double longitude,
  }) {
    _activeDataList = dataList;
    _activeTimezone = timezoneName;
    _activeYear = year;
    _activeMonth = month;
    _activeMethodId = methodId;
    _activeSchool = school;
    _activeLat = latitude;
    _activeLng = longitude;
  }

  static bool _coordsClose(double? lat1, double? lng1, double lat2, double lng2) {
    if (lat1 == null || lng1 == null) return false;
    // Within ~10 km / 0.09 degrees.
    return (lat1 - lat2).abs() < 0.09 && (lng1 - lng2).abs() < 0.09;
  }

  Map<String, dynamic>? _findDayInList(List<dynamic> dataList, int day) {
    for (final item in dataList) {
      final greg = item['date']?['gregorian'];
      final dVal = int.tryParse(greg?['day']?.toString() ?? '');
      if (dVal == day) {
        return item as Map<String, dynamic>;
      }
    }
    return null;
  }

  PrayerTimeEntity _parseDayData(Map<String, dynamic> dayData, DateTime date, String timezoneName) {
    final locationTz = tz.getLocation(timezoneName);
    final timings = dayData['timings'] as Map<String, dynamic>;

    final fajrTime = tz.TZDateTime.parse(locationTz, timings['Fajr'] as String);
    final sunriseTime = tz.TZDateTime.parse(locationTz, timings['Sunrise'] as String);
    final dhuhrTime = tz.TZDateTime.parse(locationTz, timings['Dhuhr'] as String);
    final asrTime = tz.TZDateTime.parse(locationTz, timings['Asr'] as String);
    final maghribTime = tz.TZDateTime.parse(locationTz, timings['Maghrib'] as String);
    final ishaTime = tz.TZDateTime.parse(locationTz, timings['Isha'] as String);

    String? hijriStr;
    String? hijriStrAr;
    try {
      final hijri = dayData['date']?['hijri'] as Map<String, dynamic>?;
      if (hijri != null) {
        final hDay = hijri['day'];
        final hMonthEn = hijri['month']?['en'];
        final hMonthAr = hijri['month']?['ar'];
        final hYear = hijri['year'];
        final hDesignation = hijri['designation']?['abbreviated'] ?? 'AH';
        if (hDay != null && hMonthEn != null && hYear != null) {
          hijriStr = '$hDay $hMonthEn $hYear $hDesignation';
        }
        if (hDay != null && hMonthAr != null && hYear != null) {
          hijriStrAr = '$hDay $hMonthAr $hYear هـ';
        }
      }
    } catch (_) {}

    return PrayerTimeEntity(
      date: date,
      fajr: fajrTime,
      sunrise: sunriseTime,
      dhuhr: dhuhrTime,
      asr: asrTime,
      maghrib: maghribTime,
      isha: ishaTime,
      hijriDateStr: hijriStr,
      hijriDateStrAr: hijriStrAr,
    );
  }
}

/// A fetched (and cached) month of Aladhan calendar data.
class _FetchedMonth {
  final List<dynamic> dataList;
  final String timezoneName;

  const _FetchedMonth(this.dataList, this.timezoneName);
}

@lazySingleton
class GetPrayerSettingsUseCase {
  final PrayerRepository _repository;

  const GetPrayerSettingsUseCase(this._repository);

  Future<PrayerTimesSettings> call() => _repository.getSettings();
}

@lazySingleton
class SavePrayerSettingsUseCase {
  final PrayerRepository _repository;

  const SavePrayerSettingsUseCase(this._repository);

  Future<void> call(PrayerTimesSettings settings) => _repository.saveSettings(settings);
}

@lazySingleton
class GetUserLocationUseCase {
  final PrayerRepository _repository;

  static const double defaultLat = 33.5731;
  static const double defaultLng = -7.5898;
  static const String defaultCity = 'Casablanca';

  const GetUserLocationUseCase(this._repository);

  Future<UserLocation> call({bool forceRefresh = false}) async {
    // 1. Try cached location first if not forcing refresh
    if (!forceRefresh) {
      final cached = await _repository.getCachedLocation();
      if (cached != null) {
        debugPrint('[Location] Using cached location: ${cached.cityName} (${cached.latitude}, ${cached.longitude})');
        return cached;
      }
    }

    // 2. Fetch live GPS coordinates
    try {
      final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('[Location] GPS service enabled: $isServiceEnabled');
      if (!isServiceEnabled) {
        debugPrint('[Location] GPS disabled, falling back...');
        return _fallbackToIPOrCache();
      }

      var permission = await Geolocator.checkPermission();
      debugPrint('[Location] Current permission status: $permission');
      if (permission == LocationPermission.denied) {
        debugPrint('[Location] Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('[Location] Permission after request: $permission');
        if (permission == LocationPermission.denied) {
          debugPrint('[Location] Permission denied by user, falling back...');
          return _fallbackToIPOrCache();
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[Location] Permission permanently denied, falling back...');
        return _fallbackToIPOrCache();
      }

      debugPrint('[Location] Fetching GPS position...');
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 6),
      );
      debugPrint('[Location] GPS position: (${position.latitude}, ${position.longitude})');

      final cityName = await _reverseGeocode(position.latitude, position.longitude);

      final location = UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName ?? 'Live Location',
      );

      await _repository.cacheLocation(location);
      return location;
    } catch (e) {
      debugPrint('[Location] GPS fetch failed: $e — falling back...');
      return _fallbackToIPOrCache();
    }
  }

  Future<UserLocation> _fallbackToIPOrCache() async {
    // 1. Try IP Geolocation
    debugPrint('[Location] Trying IP geolocation...');
    final ipLoc = await _getIPLocation();
    if (ipLoc != null) {
      debugPrint('[Location] IP geolocation success: ${ipLoc.cityName}');
      await _repository.cacheLocation(ipLoc);
      return ipLoc;
    }

    // 2. Try cached location
    final cached = await _repository.getCachedLocation();
    if (cached != null) {
      debugPrint('[Location] Using cached location: ${cached.cityName}');
      return cached;
    }

    // 3. Fallback to default
    debugPrint('[Location] All methods failed — using default Casablanca');
    return const UserLocation(
      latitude: defaultLat,
      longitude: defaultLng,
      cityName: defaultCity,
    );
  }

  Future<String?> _reverseGeocode(double lat, double lng) async {
    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=10&addressdetails=1',
      );
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      request.headers.set(HttpHeaders.userAgentHeader, 'AhlJannahApp/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          return address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              address['county'] ??
              address['state'] ??
              address['country'];
        }
      }
    } catch (_) {} finally {
      client.close();
    }
    return null;
  }

  Future<UserLocation?> _getIPLocation() async {
    final client = HttpClient();
    try {
      final uri = Uri.parse('https://ipapi.co/json/');
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      request.headers.set(HttpHeaders.userAgentHeader, 'AhlJannahApp/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;
        final lat = data['latitude'] as double?;
        final lng = data['longitude'] as double?;
        final city = data['city'] as String?;
        if (lat != null && lng != null) {
          return UserLocation(
            latitude: lat,
            longitude: lng,
            cityName: city ?? 'IP Location',
          );
        }
      }
    } catch (_) {
      try {
        final uri = Uri.parse('https://ip-api.com/json/');
        final request = await client.getUrl(uri).timeout(const Duration(seconds: 3));
        final response = await request.close();
        if (response.statusCode == 200) {
          final responseBody = await response.transform(utf8.decoder).join();
          final data = jsonDecode(responseBody) as Map<String, dynamic>;
          final lat = data['lat'] as double?;
          final lng = data['lon'] as double?;
          final city = data['city'] as String?;
          if (lat != null && lng != null) {
            return UserLocation(
              latitude: lat,
              longitude: lng,
              cityName: city ?? 'IP Location',
          );
          }
        }
      } catch (_) {}
    } finally {
      client.close();
    }
    return null;
  }
}
