import 'package:shared_preferences/shared_preferences.dart';

/// Secret gate for the Settings page's debug tools.
///
/// The debug section is hidden from regular users. It only becomes
/// visible after tapping the About dialog's content 20 times. The unlock
/// is persisted so it survives restarts, and never shows any UI feedback,
/// so only the developer knows it exists.
class DebugAccess {
  DebugAccess._();

  static const String _prefsKey = 'debug_tools_unlocked';
  static const int requiredTaps = 20;

  static int _tapCount = 0;
  static bool _unlocked = false;

  static bool get isUnlocked => _unlocked;

  /// Registers one tap on the About dialog content. Persists the unlock
  /// the moment the secret threshold is reached.
  static Future<void> registerTap() async {
    _tapCount++;
    if (!_unlocked && _tapCount >= requiredTaps) {
      _unlocked = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, true);
    }
  }

  /// Loads a previously persisted unlock (called by SettingsPage on init).
  static Future<void> loadUnlock() async {
    if (_unlocked) return;
    final prefs = await SharedPreferences.getInstance();
    _unlocked = prefs.getBool(_prefsKey) ?? false;
  }

  /// Clears the unlock so the debug tools hide again. Called from the
  /// "Hide Debug Tools" button inside the debug section itself.
  static Future<void> resetUnlock() async {
    _tapCount = 0;
    _unlocked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
