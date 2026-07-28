/// App-wide constants for Ahl Jannah.
abstract final class AppConstants {
  /// Application name.
  static const String appName = 'Ahl Jannah';

  /// Application package / organization.
  static const String orgName = 'com.ahljannah';

  /// Kaaba coordinates (used for Qibla calculation).
  static const double kaabaLatitude = 21.3891;
  static const double kaabaLongitude = 39.8579;

  /// Default font sizes.
  static const double defaultArabicFontSize = 28.0;
  static const double minArabicFontSize = 18.0;
  static const double maxArabicFontSize = 48.0;

  /// Animation durations.
  static const Duration animFast = Duration(milliseconds: 200);
  static const Duration animMedium = Duration(milliseconds: 350);
  static const Duration animSlow = Duration(milliseconds: 500);

  /// SharedPreferences keys.
  static const String keyThemeMode = 'theme_mode';
  static const String keyArabicFontSize = 'arabic_font_size';
  static const String keyCalcMethod = 'calculation_method';
  static const String keyMadhab = 'madhab';
  static const String keyLatitude = 'latitude';
  static const String keyLongitude = 'longitude';
  static const String keyStartupPermissionsRequested =
      'startup_permissions_requested';
  static const String keyQuranReaderMode = 'quran_reader_mode';
  static const String keyQuranBookmarks = 'quran_bookmarks_json';
  static const String keyQuranReaderFont = 'quran_reader_font';

  /// Auto-saved "continue reading" position — separate key from
  /// [keyQuranBookmarks] so it never mixes with the user's explicit
  /// bookmarks list.
  static const String keyQuranLastPosition = 'quran_last_position_json';

  /// Persisted last selected bottom navigation tab index.
  static const String keyLastNavigationTab = 'last_navigation_tab';

  /// Tracks whether the user was inside a surah (reader) when closing the app.
  static const String keyWasInsideQuranReader = 'was_inside_quran_reader';
}