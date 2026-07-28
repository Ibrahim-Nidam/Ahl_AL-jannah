import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/settings_model.dart';

/// Local (on-device) persistence contract for settings.
abstract interface class SettingsLocalDataSource {
  /// Returns the persisted settings, or defaults if nothing is stored yet
  /// or the stored data could not be parsed.
  Future<SettingsModel> getSettings();

  /// Persists the given settings.
  Future<void> saveSettings(SettingsModel settings);

  /// Removes any persisted settings.
  Future<void> clearSettings();
}

@LazySingleton(as: SettingsLocalDataSource)
class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  /// Settings are stored as a single JSON blob under one key so that
  /// adding a new setting later never requires a new storage key or a
  /// repository migration — only a new field in [SettingsModel].
  static const String _keySettingsJson = 'app_settings_json';

  @override
  Future<SettingsModel> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySettingsJson);
    if (jsonStr == null) {
      return SettingsModel.defaultSettings();
    }

    try {
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SettingsModel.fromJson(decoded);
    } catch (_) {
      // Corrupted or incompatible data — fail safe to defaults rather
      // than crashing settings load.
      return SettingsModel.defaultSettings();
    }
  }

  @override
  Future<void> saveSettings(SettingsModel settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySettingsJson, jsonEncode(settings.toJson()));
  }

  @override
  Future<void> clearSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySettingsJson);
  }
}