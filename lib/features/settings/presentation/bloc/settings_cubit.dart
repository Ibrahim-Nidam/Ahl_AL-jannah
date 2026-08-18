import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/settings_entities.dart';
import '../../domain/usecases/settings_usecases.dart';

part 'settings_state.dart';

@lazySingleton
class SettingsCubit extends Cubit<SettingsState> {
  final GetSettingsUseCase _getSettingsUseCase;
  final SaveSettingsUseCase _saveSettingsUseCase;
  final ResetSettingsUseCase _resetSettingsUseCase;

  SettingsCubit(
    this._getSettingsUseCase,
    this._saveSettingsUseCase,
    this._resetSettingsUseCase,
  ) : super(SettingsInitial());

  /// Loads persisted settings (or defaults) from storage.
  Future<void> loadSettings() async {
    emit(SettingsLoadInProgress());
    try {
      final settings = await _getSettingsUseCase();
      emit(SettingsLoadSuccess(settings));
    } catch (e) {
      emit(SettingsLoadFailure(e.toString()));
    }
  }

  /// Replaces the full settings object and persists it.
  ///
  /// Emits the new state optimistically, then rolls back if persistence
  /// fails so the UI never shows a value that wasn't actually saved.
  Future<void> updateSettings(SettingsEntity newSettings) async {
    final currentState = state;
    if (currentState is! SettingsLoadSuccess) return;

    final previousSettings = currentState.settings;
    emit(currentState.copyWith(settings: newSettings));

    try {
      await _saveSettingsUseCase(newSettings);
    } catch (e) {
      emit(currentState.copyWith(settings: previousSettings));
      emit(SettingsLoadFailure(e.toString()));
    }
  }

  /// Resets all settings back to their defaults.
  Future<void> resetToDefaults() async {
    try {
      await _resetSettingsUseCase();
      final settings = await _getSettingsUseCase();
      emit(SettingsLoadSuccess(settings));
    } catch (e) {
      emit(SettingsLoadFailure(e.toString()));
    }
  }

  // ── Convenience per-field setters ──
  // Thin wrappers around updateSettings so callers don't need to build
  // copyWith calls at every call-site. Add one of these whenever a new
  // field is added to SettingsEntity.

  Future<void> setLanguage(AppLanguage language) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(currentState.settings.copyWith(language: language));
    }
  }

  Future<void> setThemeMode(AppThemeMode themeMode) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(themeMode: themeMode),
      );
    }
  }

  Future<void> setColorPalette(AppColorPalette colorPalette) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(colorPalette: colorPalette),
      );
    }
  }

  Future<void> setQuranRiwaya(QuranRiwaya quranRiwaya) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(quranRiwaya: quranRiwaya),
      );
    }
  }

  Future<void> setArabicFontSize(double arabicFontSize) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(arabicFontSize: arabicFontSize),
      );
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(notificationsEnabled: enabled),
      );
    }
  }

  Future<void> setAdhanType(AdhanType adhanType) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(adhanType: adhanType),
      );
    }
  }

  Future<void> setMorningAdhkarReminderEnabled(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(morningAdhkarReminderEnabled: enabled),
      );
    }
  }

  Future<void> setEveningAdhkarReminderEnabled(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(eveningAdhkarReminderEnabled: enabled),
      );
    }
  }

  Future<void> setVibrationsEnabled(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(vibrationsEnabled: enabled),
      );
    }
  }

  Future<void> setKeepScreenAwake(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(keepScreenAwake: enabled),
      );
    }
  }

  Future<void> setTasbeehVibrateOnTap(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(tasbeehVibrateOnTap: enabled),
      );
    }
  }

  Future<void> setTasbeehStrongVibrateOnComplete(bool enabled) async {
    final currentState = state;
    if (currentState is SettingsLoadSuccess) {
      await updateSettings(
        currentState.settings.copyWith(tasbeehStrongVibrateOnComplete: enabled),
      );
    }
  }
}
