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

@lazySingleton
class CalculatePrayerTimesUseCase {
  final PrayerRepository _repository;

  const CalculatePrayerTimesUseCase(this._repository);

  // Memory cache variables
  static List<dynamic>? _activeDataList;
  static String? _activeTimezone;
  static int? _activeMonth;
  static int? _activeYear;

  Future<PrayerTimeEntity> call({
    required UserLocation location,
    required DateTime date,
    required PrayerTimesSettings settings,
  }) async {
    final methodId = settings.useAutomaticMethod
        ? estimateAladhanMethod(location.latitude, location.longitude)
        : (settings.manualMethodId ?? 3);
    final school = settings.madhab;

    // 1. Try to load from cached monthly prayer times
    final cachedJson = await _repository.getCachedMonthlyPrayerTimes();
    if (cachedJson != null) {
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

        if (cachedMonth == date.month &&
            cachedYear == date.year &&
            timezoneName != null &&
            dataList != null &&
            cachedLat != null &&
            cachedLng != null &&
            cachedMethodId == methodId &&
            cachedSchool == school) {
          // Check if coordinates are close (within ~10 km / 0.09 degrees)
          final latDiff = (cachedLat - location.latitude).abs();
          final lngDiff = (cachedLng - location.longitude).abs();
          if (latDiff < 0.09 && lngDiff < 0.09) {
            final dayData = _findDayInList(dataList, date.day);
            if (dayData != null) {
              _activeDataList = dataList;
              _activeTimezone = timezoneName;
              _activeMonth = date.month;
              _activeYear = date.year;
              return _parseDayData(dayData, date, timezoneName);
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fetch from Aladhan API
    final client = HttpClient();
    try {
      debugPrint('[PrayerTimes] Fetching Aladhan API for ${date.year}/${date.month} method=$methodId school=$school lat=${location.latitude} lng=${location.longitude}');
      final url = Uri.parse(
        'https://api.aladhan.com/v1/calendar/${date.year}/${date.month}'
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

            // Cache data
            final cacheWrapper = {
              'month': date.month,
              'year': date.year,
              'latitude': location.latitude,
              'longitude': location.longitude,
              'timezone': timezoneName,
              'methodId': methodId,
              'school': school,
              'data': dataList,
            };
            await _repository.cacheMonthlyPrayerTimes(jsonEncode(cacheWrapper));

            _activeDataList = dataList;
            _activeTimezone = timezoneName;
            _activeMonth = date.month;
            _activeYear = date.year;

            final dayData = _findDayInList(dataList, date.day);
            if (dayData != null) {
              debugPrint('[PrayerTimes] Successfully parsed prayer times from Aladhan API');
              return _parseDayData(dayData, date, timezoneName);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[PrayerTimes] Aladhan API call failed: $e');
    } finally {
      client.close();
    }

    // 3. Fallback to existing disk cache as last resort if month/coords mismatch
    if (cachedJson != null) {
      try {
        final Map<String, dynamic> cachedData = jsonDecode(cachedJson);
        final timezoneName = cachedData['timezone'] as String? ?? 'UTC';
        final dataList = cachedData['data'] as List<dynamic>?;
        if (dataList != null) {
          final dayData = _findDayInList(dataList, date.day) ?? dataList.first;
          debugPrint('[PrayerTimes] Using stale disk cache as fallback');
          return _parseDayData(dayData, date, timezoneName);
        }
      } catch (_) {}
    }

    // 4. Last resort: return static default times so the app never crashes
    debugPrint('[PrayerTimes] All sources failed — returning static default times');
    return calculateLocal(location: location, date: date, settings: settings);
  }

  PrayerTimeEntity calculateLocal({
    required UserLocation location,
    required DateTime date,
    required PrayerTimesSettings settings,
  }) {
    if (_activeDataList != null && _activeTimezone != null && _activeMonth == date.month && _activeYear == date.year) {
      final dayData = _findDayInList(_activeDataList!, date.day);
      if (dayData != null) {
        return _parseDayData(dayData, date, _activeTimezone!);
      }
    }

    // Static safety fallback
    final localTz = tz.local;
    return PrayerTimeEntity(
      date: date,
      fajr: tz.TZDateTime(localTz, date.year, date.month, date.day, 5, 0),
      sunrise: tz.TZDateTime(localTz, date.year, date.month, date.day, 6, 30),
      dhuhr: tz.TZDateTime(localTz, date.year, date.month, date.day, 12, 30),
      asr: tz.TZDateTime(localTz, date.year, date.month, date.day, 16, 0),
      maghrib: tz.TZDateTime(localTz, date.year, date.month, date.day, 19, 30),
      isha: tz.TZDateTime(localTz, date.year, date.month, date.day, 21, 0),
      hijriDateStr: '1 Ramadan 1447 AH',
    );
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
        final uri = Uri.parse('http://ip-api.com/json/');
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
