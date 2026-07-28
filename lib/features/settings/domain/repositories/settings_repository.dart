import '../entities/settings_entities.dart';

/// Repository contract for reading and persisting app settings.
abstract interface class SettingsRepository {
  /// Retrieves the current settings, or defaults if none are persisted yet.
  Future<SettingsEntity> getSettings();

  /// Persists the given settings.
  Future<void> saveSettings(SettingsEntity settings);

  /// Resets persisted settings back to [SettingsEntity.defaultSettings].
  Future<void> resetToDefaults();
}