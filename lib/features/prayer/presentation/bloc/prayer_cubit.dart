import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../settings/domain/usecases/settings_usecases.dart';
import '../../domain/entities/prayer_entities.dart';
import '../../domain/usecases/prayer_usecases.dart';
import '../../data/repositories/prayer_notification_service.dart';

part 'prayer_state.dart';

@lazySingleton
class PrayerCubit extends Cubit<PrayerState> {
  final GetUserLocationUseCase _getUserLocationUseCase;
  final GetPrayerSettingsUseCase _getPrayerSettingsUseCase;
  final SavePrayerSettingsUseCase _savePrayerSettingsUseCase;
  final CalculatePrayerTimesUseCase _calculatePrayerTimesUseCase;
  final PrayerNotificationService _notificationService;
  final GetSettingsUseCase _getAppSettingsUseCase;

  Timer? _countdownTimer;

  PrayerCubit(
    this._getUserLocationUseCase,
    this._getPrayerSettingsUseCase,
    this._savePrayerSettingsUseCase,
    this._calculatePrayerTimesUseCase,
    this._notificationService,
    this._getAppSettingsUseCase,
  ) : super(PrayerInitial());

  /// Loads location, settings, fetches times from Aladhan API, starts countdown.
  Future<void> loadPrayerTimes({DateTime? date, bool forceRefresh = false}) async {
    emit(PrayerLoadInProgress());
    _stopTimer();

    try {
      final location = await _getUserLocationUseCase(
        forceRefresh: forceRefresh,
      );
      final settings = await _getPrayerSettingsUseCase();

      final targetDate = date ?? DateTime.now();
      final todayTimes = await _calculatePrayerTimesUseCase(
        location: location,
        date: targetDate,
        settings: settings,
      );

      final hijriStr = todayTimes.hijriDateStr ?? '';
      final hijriStrAr = todayTimes.hijriDateStrAr ?? '';

      final (nextName, nextTime) = _findNextPrayer(
        location,
        settings,
        todayTimes,
      );
      final remaining = nextTime.difference(DateTime.now());

      emit(
        PrayerLoadSuccess(
          location: location,
          settings: settings,
          todayTimes: todayTimes,
          nextPrayerName: nextName,
          nextPrayerTime: nextTime,
          timeRemaining: remaining,
          hijriDateStr: hijriStr,
          hijriDateStrAr: hijriStrAr,
          selectedDate: targetDate,
        ),
      );

      // Schedule notifications for the real calendar "today", even when
      // the UI is browsing another day.
      final now = DateTime.now();
      final isTodayView = targetDate.year == now.year &&
          targetDate.month == now.month &&
          targetDate.day == now.day;

      final notificationTimes = isTodayView
          ? todayTimes
          : await _calculatePrayerTimesUseCase(
              location: location,
              date: now,
              settings: settings,
            );

      final nextDayTimes = await _calculatePrayerTimesUseCase(
        location: location,
        date: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
        settings: settings,
      );

      final appSettings = await _getAppSettingsUseCase();

      await _notificationService.initialize();
      await _notificationService.requestPermissions();
      await _notificationService.schedulePrayerNotifications(
        notificationTimes,
        settings,
        appSettings.adhanType,
        language: appSettings.language,
        nextDayTimes: nextDayTimes,
      );
      // Adhkar reminders are independent of the prayer-notifications
      // toggle above (they have their own ON/OFF settings), and
      // scheduling them never wipes the prayer notifications just set,
      // so this always runs after the prayer scheduling call.
      await _notificationService.scheduleAdhkarReminders(
        notificationTimes,
        morningEnabled: appSettings.morningAdhkarReminderEnabled,
        eveningEnabled: appSettings.eveningAdhkarReminderEnabled,
        language: appSettings.language,
        nextDayTimes: nextDayTimes,
      );

      // If the user stopped the currently-active adhan (from the notification
      // shade, which may have been handled in a background isolate), make sure
      // any in-app audio for it is also stopped and it is not auto-replayed.
      final stoppedKey = await PrayerNotificationService.readManualAdhanStop();
      if (stoppedKey != null) {
        final active = PrayerNotificationIds.activePrayerKey(
          notificationTimes,
          settings,
        );
        if (active == stoppedKey) {
          await _notificationService.stopActiveAdhan(notificationTimes, settings);
        }
      }

      _startTimer();
    } catch (e) {
      emit(PrayerLoadFailure(e.toString()));
    }
  }

  /// Toggles notifications on/off and saves settings.
  Future<void> toggleNotifications(bool enabled) async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      final newSettings = currentState.settings.copyWith(
        notificationsEnabled: enabled,
      );
      await updateSettings(newSettings);
    }
  }

  /// Sets the reminder interval (5–15 minutes) and saves settings.
  Future<void> setReminderInterval(int minutes) async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      final newSettings = currentState.settings.copyWith(
        reminderInterval: minutes,
      );
      await updateSettings(newSettings);
    }
  }

  /// Stops whichever Adhan is currently playing, if any.
  Future<void> stopActiveAdhan() async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      await _notificationService.stopActiveAdhan(
        currentState.todayTimes,
        currentState.settings,
      );
    }
  }

  /// Toggles muting of a specific prayer (e.g. 'fajr', 'asr').
  Future<void> togglePrayerMute(String prayerName) async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      final mutedList = List<String>.from(currentState.settings.mutedPrayers);
      if (mutedList.contains(prayerName)) {
        mutedList.remove(prayerName);
      } else {
        mutedList.add(prayerName);
      }

      final newSettings = currentState.settings.copyWith(
        mutedPrayers: mutedList,
      );

      await updateSettings(newSettings);
    }
  }

  /// Updates settings, recalculates timings, and reschedules notifications.
  Future<void> updateSettings(PrayerTimesSettings newSettings) async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      try {
        await _savePrayerSettingsUseCase(newSettings);

        // Fetch/recalculate timings with the new settings
        final todayTimes = await _calculatePrayerTimesUseCase(
          location: currentState.location,
          date: currentState.todayTimes.date, // Preserve the currently displayed date
          settings: newSettings,
        );

        final (nextName, nextTime) = _findNextPrayer(
          currentState.location,
          newSettings,
          todayTimes,
        );
        final remaining = nextTime.difference(DateTime.now());

        emit(
          currentState.copyWith(
            settings: newSettings,
            todayTimes: todayTimes,
            nextPrayerName: nextName,
            nextPrayerTime: nextTime,
            timeRemaining: remaining,
            hijriDateStr: todayTimes.hijriDateStr,
            hijriDateStrAr: todayTimes.hijriDateStrAr,
          ),
        );

        final appSettings = await _getAppSettingsUseCase();

        // Always schedule against calendar "today", not the browsed date.
        final now = DateTime.now();
        final isTodayView = currentState.selectedDate.year == now.year &&
            currentState.selectedDate.month == now.month &&
            currentState.selectedDate.day == now.day;
        final notificationTimes = isTodayView
            ? todayTimes
            : await _calculatePrayerTimesUseCase(
                location: currentState.location,
                date: now,
                settings: newSettings,
              );
        final nextDayTimes = await _calculatePrayerTimesUseCase(
          location: currentState.location,
          date: DateTime(now.year, now.month, now.day)
              .add(const Duration(days: 1)),
          settings: newSettings,
        );

        if (newSettings.notificationsEnabled) {
          await _notificationService.schedulePrayerNotifications(
            notificationTimes,
            newSettings,
            appSettings.adhanType,
            language: appSettings.language,
            nextDayTimes: nextDayTimes,
          );
        } else {
          await _notificationService.cancelAllNotifications();
        }

        // Adhkar reminders are independent of the prayer-notifications
        // toggle — they always get (re)scheduled per their own settings,
        // whether or not prayer notifications are enabled.
        await _notificationService.scheduleAdhkarReminders(
          notificationTimes,
          morningEnabled: appSettings.morningAdhkarReminderEnabled,
          eveningEnabled: appSettings.eveningAdhkarReminderEnabled,
          language: appSettings.language,
          nextDayTimes: nextDayTimes,
        );
      } catch (e) {
        emit(PrayerLoadFailure(e.toString()));
      }
    }
  }

  /// Starts a 1-second periodic timer to update the countdown in the state.
  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final currentState = state;
      if (currentState is PrayerLoadSuccess) {
        final now = DateTime.now();
        final isTodayView = currentState.selectedDate.year == now.year &&
            currentState.selectedDate.month == now.month &&
            currentState.selectedDate.day == now.day;

        if (!isTodayView) {
          _countdownTimer?.cancel();
          return;
        }

        final remaining = currentState.nextPrayerTime.difference(now);

        if (remaining.isNegative || remaining.inSeconds == 0) {
          // Current prayer time passed! Transition UI to next prayer without calling
          // loadPrayerTimes() which would cancel pending system notifications.
          final (nextName, nextTime) = _findNextPrayer(
            currentState.location,
            currentState.settings,
            currentState.todayTimes,
          );
          final newRemaining = nextTime.difference(now);
          emit(
            currentState.copyWith(
              nextPrayerName: nextName,
              nextPrayerTime: nextTime,
              timeRemaining: newRemaining,
            ),
          );
        } else {
          emit(currentState.copyWith(timeRemaining: remaining));
        }
      } else {
        _countdownTimer?.cancel();
      }
    });
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  /// Helper to calculate the next prayer name and timestamp.
  (String, DateTime) _findNextPrayer(
    UserLocation location,
    PrayerTimesSettings settings,
    PrayerTimeEntity today,
  ) {
    final now = DateTime.now();

    if (now.isBefore(today.fajr)) return ('Fajr', today.fajr);
    if (now.isBefore(today.sunrise)) return ('Sunrise', today.sunrise);
    if (now.isBefore(today.dhuhr)) return ('Dhuhr', today.dhuhr);
    if (now.isBefore(today.asr)) return ('Asr', today.asr);
    if (now.isBefore(today.maghrib)) return ('Maghrib', today.maghrib);
    if (now.isBefore(today.isha)) return ('Isha', today.isha);

    // If all today's prayers are past, the next prayer is tomorrow's Fajr.
    final tomorrow = now.add(const Duration(days: 1));
    final tomorrowTimes = _calculatePrayerTimesUseCase.calculateLocal(
      location: location,
      date: tomorrow,
      settings: settings,
    );

    return ('Fajr', tomorrowTimes.fajr);
  }

  @override
  Future<void> close() {
    _stopTimer();
    return super.close();
  }
}