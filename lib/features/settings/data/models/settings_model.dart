import '../../domain/entities/settings_entities.dart';

/// Data-layer representation of [SettingsEntity] responsible for JSON
/// (de)serialization for persistent storage.
///
/// Kept separate from [SettingsEntity] so the domain layer never depends
/// on storage/serialization concerns.
class SettingsModel extends SettingsEntity {
  const SettingsModel({
    required super.language,
    required super.themeMode,
    required super.colorPalette,
    required super.quranRiwaya,
    required super.arabicFontSize,
    required super.notificationsEnabled,
    required super.adhanType,
    required super.morningAdhkarReminderEnabled,
    required super.eveningAdhkarReminderEnabled,
    required super.vibrationsEnabled,
    required super.keepScreenAwake,
    required super.tasbeehVibrateOnTap,
    required super.tasbeehStrongVibrateOnComplete,
  });

  /// Wraps a plain [SettingsEntity] (e.g. produced via `copyWith`) so it
  /// can be persisted.
  factory SettingsModel.fromEntity(SettingsEntity entity) {
    return SettingsModel(
      language: entity.language,
      themeMode: entity.themeMode,
      colorPalette: entity.colorPalette,
      quranRiwaya: entity.quranRiwaya,
      arabicFontSize: entity.arabicFontSize,
      notificationsEnabled: entity.notificationsEnabled,
      adhanType: entity.adhanType,
      morningAdhkarReminderEnabled: entity.morningAdhkarReminderEnabled,
      eveningAdhkarReminderEnabled: entity.eveningAdhkarReminderEnabled,
      vibrationsEnabled: entity.vibrationsEnabled,
      keepScreenAwake: entity.keepScreenAwake,
      tasbeehVibrateOnTap: entity.tasbeehVibrateOnTap,
      tasbeehStrongVibrateOnComplete: entity.tasbeehStrongVibrateOnComplete,
    );
  }

  factory SettingsModel.defaultSettings() {
    final defaults = SettingsEntity.defaultSettings();
    return SettingsModel.fromEntity(defaults);
  }

  /// Builds a [SettingsModel] from decoded JSON.
  ///
  /// Every field falls back to its default when missing or unrecognized,
  /// so older/newer persisted formats never crash settings loading.
  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    final defaults = SettingsEntity.defaultSettings();
    return SettingsModel(
      language: _enumFromName(
        AppLanguage.values,
        json['language'] as String?,
        defaults.language,
      ),
      themeMode: _enumFromName(
        AppThemeMode.values,
        json['themeMode'] as String?,
        defaults.themeMode,
      ),
      colorPalette: _enumFromName(
        AppColorPalette.values,
        json['colorPalette'] as String?,
        defaults.colorPalette,
      ),
      quranRiwaya: _enumFromName(
        QuranRiwaya.values,
        json['quranRiwaya'] as String?,
        defaults.quranRiwaya,
      ),
      arabicFontSize:
          (json['arabicFontSize'] as num?)?.toDouble() ??
          defaults.arabicFontSize,
      notificationsEnabled:
          json['notificationsEnabled'] as bool? ??
          defaults.notificationsEnabled,
      adhanType: _enumFromName(
        AdhanType.values,
        json['adhanType'] as String?,
        defaults.adhanType,
      ),
      morningAdhkarReminderEnabled:
          json['morningAdhkarReminderEnabled'] as bool? ??
          defaults.morningAdhkarReminderEnabled,
      eveningAdhkarReminderEnabled:
          json['eveningAdhkarReminderEnabled'] as bool? ??
          defaults.eveningAdhkarReminderEnabled,
      vibrationsEnabled:
          json['vibrationsEnabled'] as bool? ?? defaults.vibrationsEnabled,
      keepScreenAwake:
          json['keepScreenAwake'] as bool? ?? defaults.keepScreenAwake,
      tasbeehVibrateOnTap:
          json['tasbeehVibrateOnTap'] as bool? ?? defaults.tasbeehVibrateOnTap,
      tasbeehStrongVibrateOnComplete:
          json['tasbeehStrongVibrateOnComplete'] as bool? ??
          defaults.tasbeehStrongVibrateOnComplete,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'language': language.name,
      'themeMode': themeMode.name,
      'colorPalette': colorPalette.name,
      'quranRiwaya': quranRiwaya.name,
      'arabicFontSize': arabicFontSize,
      'notificationsEnabled': notificationsEnabled,
      'adhanType': adhanType.name,
      'morningAdhkarReminderEnabled': morningAdhkarReminderEnabled,
      'eveningAdhkarReminderEnabled': eveningAdhkarReminderEnabled,
      'vibrationsEnabled': vibrationsEnabled,
      'keepScreenAwake': keepScreenAwake,
      'tasbeehVibrateOnTap': tasbeehVibrateOnTap,
      'tasbeehStrongVibrateOnComplete': tasbeehStrongVibrateOnComplete,
    };
  }

  /// Looks up an enum value by its persisted [name], falling back to
  /// [fallback] when [name] is null or does not match any known value
  /// (e.g. a value removed/renamed in a future app version).
  static T _enumFromName<T extends Enum>(
    List<T> values,
    String? name,
    T fallback,
  ) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
