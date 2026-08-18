part of 'prayer_cubit.dart';

abstract class PrayerState {
  const PrayerState();
}

class PrayerInitial extends PrayerState {}

class PrayerLoadInProgress extends PrayerState {}

class PrayerLoadSuccess extends PrayerState {
  final UserLocation location;
  final PrayerTimesSettings settings;
  final PrayerTimeEntity todayTimes;
  final String nextPrayerName;
  final DateTime nextPrayerTime;
  final Duration timeRemaining;
  final String hijriDateStr;
  final String hijriDateStrAr;
  final DateTime selectedDate;

  /// Tomorrow's Fajr time, captured during the last successful load. Used
  /// once all of today's prayers have passed (i.e. between Isha and Fajr)
  /// so the countdown does not need a fresh calendar call every second.
  final DateTime? nextDayFajr;

  const PrayerLoadSuccess({
    required this.location,
    required this.settings,
    required this.todayTimes,
    required this.nextPrayerName,
    required this.nextPrayerTime,
    required this.timeRemaining,
    required this.hijriDateStr,
    required this.hijriDateStrAr,
    required this.selectedDate,
    this.nextDayFajr,
  });

  PrayerLoadSuccess copyWith({
    UserLocation? location,
    PrayerTimesSettings? settings,
    PrayerTimeEntity? todayTimes,
    String? nextPrayerName,
    DateTime? nextPrayerTime,
    Duration? timeRemaining,
    String? hijriDateStr,
    String? hijriDateStrAr,
    DateTime? selectedDate,
    DateTime? nextDayFajr,
  }) {
    return PrayerLoadSuccess(
      location: location ?? this.location,
      settings: settings ?? this.settings,
      todayTimes: todayTimes ?? this.todayTimes,
      nextPrayerName: nextPrayerName ?? this.nextPrayerName,
      nextPrayerTime: nextPrayerTime ?? this.nextPrayerTime,
      timeRemaining: timeRemaining ?? this.timeRemaining,
      hijriDateStr: hijriDateStr ?? this.hijriDateStr,
      hijriDateStrAr: hijriDateStrAr ?? this.hijriDateStrAr,
      selectedDate: selectedDate ?? this.selectedDate,
      nextDayFajr: nextDayFajr ?? this.nextDayFajr,
    );
  }
}

class PrayerLoadFailure extends PrayerState {
  final String message;

  const PrayerLoadFailure(this.message);
}
