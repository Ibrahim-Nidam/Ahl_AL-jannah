import 'package:injectable/injectable.dart';

import '../entities/settings_entities.dart';
import '../repositories/settings_repository.dart';

@lazySingleton
class GetSettingsUseCase {
  final SettingsRepository _repository;

  const GetSettingsUseCase(this._repository);

  Future<SettingsEntity> call() => _repository.getSettings();
}

@lazySingleton
class SaveSettingsUseCase {
  final SettingsRepository _repository;

  const SaveSettingsUseCase(this._repository);

  Future<void> call(SettingsEntity settings) => _repository.saveSettings(settings);
}

@lazySingleton
class ResetSettingsUseCase {
  final SettingsRepository _repository;

  const ResetSettingsUseCase(this._repository);

  Future<void> call() => _repository.resetToDefaults();
}