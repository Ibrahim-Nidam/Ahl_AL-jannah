import 'package:injectable/injectable.dart';

import '../../domain/entities/settings_entities.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/settings_local_data_source.dart';
import '../models/settings_model.dart';

@LazySingleton(as: SettingsRepository)
class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsLocalDataSource _localDataSource;

  const SettingsRepositoryImpl(this._localDataSource);

  @override
  Future<SettingsEntity> getSettings() => _localDataSource.getSettings();

  @override
  Future<void> saveSettings(SettingsEntity settings) {
    final model = settings is SettingsModel
        ? settings
        : SettingsModel.fromEntity(settings);
    return _localDataSource.saveSettings(model);
  }

  @override
  Future<void> resetToDefaults() {
    return _localDataSource.saveSettings(SettingsModel.defaultSettings());
  }
}