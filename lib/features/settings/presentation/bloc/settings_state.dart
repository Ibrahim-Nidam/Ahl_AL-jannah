part of 'settings_cubit.dart';

abstract class SettingsState {
  const SettingsState();
}

class SettingsInitial extends SettingsState {}

class SettingsLoadInProgress extends SettingsState {}

class SettingsLoadSuccess extends SettingsState {
  final SettingsEntity settings;

  const SettingsLoadSuccess(this.settings);

  SettingsLoadSuccess copyWith({SettingsEntity? settings}) {
    return SettingsLoadSuccess(settings ?? this.settings);
  }
}

class SettingsLoadFailure extends SettingsState {
  final String message;

  const SettingsLoadFailure(this.message);
}