/// Language selection for the app.
///
/// [system] follows the device locale. Concrete language behavior
/// (translated strings, RTL switching) is implemented by a later feature;
/// this enum only provides the typed value to persist.
enum AppLanguage { system, en, ar, fr }

/// App-wide theme mode.
enum AppThemeMode { system, light, dark }

/// Named color palette. Additional palettes can be appended without
/// breaking persisted values, since storage is by enum name.
///
/// `classic` keeps its original name for persistence compatibility, but
/// is presented to the user as "Emerald" (see the palette selector in
/// SettingsPage). Actual color values for every palette live in
/// `core/theme/app_colors.dart` / `core/theme/app_palettes.dart`.
enum AppColorPalette { classic, ocean, desert }

/// Quran text font. Additional fonts can be appended later — doing so
/// only requires: (1) bundling the .ttf under `assets/fonts` and
/// registering it in `pubspec.yaml`, (2) adding an enum case here with
/// its `fontFamily`/`fontFamilyFallback` in [QuranFontX] below. No other
/// file needs to change.
enum QuranFont { uthmanic }

/// Maps each [QuranFont] to its concrete font family + fallback chain.
/// Kept next to the enum (not in `core/theme`) so `core/theme` never has
/// to depend on the settings feature's font list.
extension QuranFontX on QuranFont {
  String get fontFamily {
    switch (this) {
      case QuranFont.uthmanic:
        return 'Lateef';
    }
  }

  List<String> get fontFamilyFallback {
    switch (this) {
      case QuranFont.uthmanic:
        return const ['Noto Naskh Arabic', 'Scheherazade New', 'Arial'];
    }
  }
}

/// Quran riwaya (narration/transmission). Additional riwayat can be
/// appended later.
enum QuranRiwaya { hafsAnAsim }

/// Adhan sound used for prayer notifications.
///
/// [full] plays the complete Adhan (with the dedicated Fajr Adhan for
/// Fajr specifically). [short] plays only the opening "Allahu Akbar" for
/// every prayer, including Fajr. See `PrayerNotificationService` for the
/// exact file mapping.
enum AdhanType { full, short }

/// Central, strongly-typed application settings.
///
/// This is the single source of truth consumed by the rest of the app.
/// New settings should be added here as additional fields (with a
/// matching default in [SettingsEntity.defaultSettings] and a matching
/// entry in [SettingsModel]'s JSON mapping) rather than via new,
/// unrelated storage keys.
class SettingsEntity {
  // ── Language & Direction ──
  final AppLanguage language;

  // ── Appearance ──
  final AppThemeMode themeMode;
  final AppColorPalette colorPalette;

  // ── Quran ──
  final QuranFont quranFont;
  final QuranRiwaya quranRiwaya;

  // ── Notifications ──
  final bool notificationsEnabled;
  final AdhanType adhanType;

  /// Whether the Morning Adhkar reminder (Fajr + 1 hour) is scheduled.
  final bool morningAdhkarReminderEnabled;

  /// Whether the Evening Adhkar reminder (Asr + 1 hour) is scheduled.
  final bool eveningAdhkarReminderEnabled;

  // ── Feedback & Display ──
  final bool vibrationsEnabled;
  final bool keepScreenAwake;

  // ── Tasbeeh ──
  /// Light vibration on every Tasbeeh tap.
  final bool tasbeehVibrateOnTap;

  /// Stronger vibration when a Tasbeeh target is completed.
  final bool tasbeehStrongVibrateOnComplete;

  const SettingsEntity({
    required this.language,
    required this.themeMode,
    required this.colorPalette,
    required this.quranFont,
    required this.quranRiwaya,
    required this.notificationsEnabled,
    required this.adhanType,
    required this.morningAdhkarReminderEnabled,
    required this.eveningAdhkarReminderEnabled,
    required this.vibrationsEnabled,
    required this.keepScreenAwake,
    required this.tasbeehVibrateOnTap,
    required this.tasbeehStrongVibrateOnComplete,
  });

  /// Derived text direction. Not persisted independently — it always
  /// follows [language] to avoid the two ever going out of sync.
  bool get isRtl => language == AppLanguage.ar;

  factory SettingsEntity.defaultSettings() {
    return const SettingsEntity(
      language: AppLanguage.system,
      themeMode: AppThemeMode.system,
      colorPalette: AppColorPalette.classic,
      quranFont: QuranFont.uthmanic,
      quranRiwaya: QuranRiwaya.hafsAnAsim,
      notificationsEnabled: true,
      adhanType: AdhanType.full,
      morningAdhkarReminderEnabled: true,
      eveningAdhkarReminderEnabled: true,
      vibrationsEnabled: true,
      keepScreenAwake: false,
      tasbeehVibrateOnTap: true,
      tasbeehStrongVibrateOnComplete: true,
    );
  }

  SettingsEntity copyWith({
    AppLanguage? language,
    AppThemeMode? themeMode,
    AppColorPalette? colorPalette,
    QuranFont? quranFont,
    QuranRiwaya? quranRiwaya,
    bool? notificationsEnabled,
    AdhanType? adhanType,
    bool? morningAdhkarReminderEnabled,
    bool? eveningAdhkarReminderEnabled,
    bool? vibrationsEnabled,
    bool? keepScreenAwake,
    bool? tasbeehVibrateOnTap,
    bool? tasbeehStrongVibrateOnComplete,
  }) {
    return SettingsEntity(
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      colorPalette: colorPalette ?? this.colorPalette,
      quranFont: quranFont ?? this.quranFont,
      quranRiwaya: quranRiwaya ?? this.quranRiwaya,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      adhanType: adhanType ?? this.adhanType,
      morningAdhkarReminderEnabled:
          morningAdhkarReminderEnabled ?? this.morningAdhkarReminderEnabled,
      eveningAdhkarReminderEnabled:
          eveningAdhkarReminderEnabled ?? this.eveningAdhkarReminderEnabled,
      vibrationsEnabled: vibrationsEnabled ?? this.vibrationsEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      tasbeehVibrateOnTap: tasbeehVibrateOnTap ?? this.tasbeehVibrateOnTap,
      tasbeehStrongVibrateOnComplete: tasbeehStrongVibrateOnComplete ??
          this.tasbeehStrongVibrateOnComplete,
    );
  }
}