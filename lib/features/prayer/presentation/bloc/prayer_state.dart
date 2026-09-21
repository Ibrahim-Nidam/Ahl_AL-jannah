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
  final DateTime? nextDayFajr;
  final bool isPostPrayer;
  final String? currentPrayerName;
  final Duration? timeSincePrayer;

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
    this.isPostPrayer = false,
    this.currentPrayerName,
    this.timeSincePrayer,
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
    bool? isPostPrayer,
    String? currentPrayerName,
    Duration? timeSincePrayer,
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
      isPostPrayer: isPostPrayer ?? this.isPostPrayer,
      currentPrayerName: currentPrayerName ?? this.currentPrayerName,
      timeSincePrayer: timeSincePrayer ?? this.timeSincePrayer,
    );
  }
}

class PrayerLoadFailure extends PrayerState {
  final String message;

  const PrayerLoadFailure(this.message);
}
