import 'dart:async';
import 'package:flutter/foundation.dart';
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

      // Resolve the times used for notification scheduling. These are
      // always for the real calendar "today", even when the UI is browsing
      // another day. Tomorrow's times may be unavailable while offline if
      // the next month was never cached — that must not fail today's page,
      // so it is computed leniently.
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

      PrayerTimeEntity? nextDayTimes;
      try {
        nextDayTimes = await _calculatePrayerTimesUseCase(
          location: location,
          date: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
          settings: settings,
        );
      } catch (e) {
        debugPrint('[Prayer] Failed to compute next-day times: $e');
      }

      final (nextName, nextTime) = _findNextPrayer(
        todayTimes,
        nextDayFajr: nextDayTimes?.fajr,
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
          nextDayFajr: nextDayTimes?.fajr,
        ),
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

  /// Toggles the adhan/reminder sound on/off and saves settings.
  Future<void> toggleAdhanSound(bool enabled) async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      final newSettings = currentState.settings.copyWith(
        adhanSoundEnabled: enabled,
      );
      await updateSettings(newSettings);
    }
  }

  /// Saves prayer alert settings from anywhere in the app (e.g. the Settings
  /// page) and immediately applies/reschedules. Unlike [toggleNotifications],
  /// this works even when the Prayer page has not been loaded yet.
  Future<void> applyPrayerSettings(PrayerTimesSettings newSettings) async {
    if (state is PrayerLoadSuccess) {
      await updateSettings(newSettings);
      return;
    }
    try {
      await _savePrayerSettingsUseCase(newSettings);
      await loadPrayerTimes();
    } catch (e) {
      emit(PrayerLoadFailure(e.toString()));
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

  /// Toggles whether a specific prayer (e.g. 'fajr', 'isha') plays adhan
  /// sound, independent of mute (which removes the notification entirely).
  Future<void> togglePrayerSound(String prayerName) async {
    final currentState = state;
    if (currentState is PrayerLoadSuccess) {
      final silentList = List<String>.from(currentState.settings.silentPrayers);
      if (silentList.contains(prayerName)) {
        silentList.remove(prayerName);
      } else {
        silentList.add(prayerName);
      }

      final newSettings = currentState.settings.copyWith(
        silentPrayers: silentList,
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

        PrayerTimeEntity? nextDayTimes;
        try {
          nextDayTimes = await _calculatePrayerTimesUseCase(
            location: currentState.location,
            date: DateTime(now.year, now.month, now.day)
                .add(const Duration(days: 1)),
            settings: newSettings,
          );
        } catch (e) {
          debugPrint('[Prayer] Failed to compute next-day times after setting change: $e');
        }

        final (nextName, nextTime) = _findNextPrayer(
          todayTimes,
          nextDayFajr: nextDayTimes?.fajr,
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
            nextDayFajr: nextDayTimes?.fajr,
          ),
        );

        if (newSettings.notificationsEnabled) {
          final appSettings = await _getAppSettingsUseCase();
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
        final appSettings = await _getAppSettingsUseCase();
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
            currentState.todayTimes,
            nextDayFajr: currentState.nextDayFajr,
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
  ///
  /// Once all of today's prayers have passed, the next prayer is tomorrow's
  /// Fajr. [nextDayFajr] is captured during the last successful load to
  /// avoid a per-second calendar lookup; when it is unavailable (offline and
  /// the next month was never cached) the countdown falls back to a
  /// day-ahead placeholder that the next successful load will correct.
  (String, DateTime) _findNextPrayer(
    PrayerTimeEntity today, {
    required DateTime? nextDayFajr,
  }) {
    final now = DateTime.now();

    if (now.isBefore(today.fajr)) return ('Fajr', today.fajr);
    if (now.isBefore(today.sunrise)) return ('Sunrise', today.sunrise);
    if (now.isBefore(today.dhuhr)) return ('Dhuhr', today.dhuhr);
    if (now.isBefore(today.asr)) return ('Asr', today.asr);
    if (now.isBefore(today.maghrib)) return ('Maghrib', today.maghrib);
    if (now.isBefore(today.isha)) return ('Isha', today.isha);

    // All today's prayers are past → the next prayer is tomorrow's Fajr.
    if (nextDayFajr != null) return ('Fajr', nextDayFajr);

    // No accurate tomorrow data available; keep the countdown alive with a
    // day-ahead placeholder until the next successful load corrects it.
    final placeholder = today.isha.add(const Duration(days: 1));
    return ('Fajr', placeholder);
  }

  @override
  Future<void> close() {
    _stopTimer();
    return super.close();
  }
}