/// Represents user location details for calculation.
class UserLocation {
  final double latitude;
  final double longitude;
  final String? cityName;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.cityName,
  });
}

/// Stores local prayer calculation and notification configurations.
class PrayerTimesSettings {
  /// Master switch for prayer alerts (reminders + adhan notifications).
  final bool notificationsEnabled;

  /// Whether prayer alerts make a sound. When `false`, prayer alerts are
  /// delivered as silent notifications (no adhan audio, no reminder sound)
  /// so the user can get the notification without being forced to hear it.
  /// Per-prayer exceptions live in [silentPrayers].
  final bool adhanSoundEnabled;

  /// Prayers (e.g. 'fajr', 'isha') that keep their notifications but are
  /// silenced individually — an adhan that still shows but plays no sound.
  /// Combined with [adhanSoundEnabled] it forms the effective per-prayer
  /// sound: `adhanSoundEnabled && !silentPrayers.contains(key)`.
  final List<String> silentPrayers;

  final int reminderInterval; // 5 or 15 minutes
  final List<String> mutedPrayers; // List of prayer names that are muted
  final bool useAutomaticMethod; // Use location-based estimation
  final int? manualMethodId; // Manual override for calculation method
  final int madhab; // 0 for Shafi/Standard, 1 for Hanafi (school)

  const PrayerTimesSettings({
    required this.notificationsEnabled,
    required this.adhanSoundEnabled,
    required this.silentPrayers,
    required this.reminderInterval,
    required this.mutedPrayers,
    required this.useAutomaticMethod,
    this.manualMethodId,
    required this.madhab,
  });

  factory PrayerTimesSettings.defaultSettings() {
    return const PrayerTimesSettings(
      notificationsEnabled: true,
      adhanSoundEnabled: true,
      silentPrayers: [],
      reminderInterval: 5,
      mutedPrayers: [],
      useAutomaticMethod: true,
      manualMethodId: null,
      madhab: 0,
    );
  }

  PrayerTimesSettings copyWith({
    bool? notificationsEnabled,
    bool? adhanSoundEnabled,
    List<String>? silentPrayers,
    int? reminderInterval,
    List<String>? mutedPrayers,
    bool? useAutomaticMethod,
    int? manualMethodId,
    int? madhab,
  }) {
    return PrayerTimesSettings(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      adhanSoundEnabled: adhanSoundEnabled ?? this.adhanSoundEnabled,
      silentPrayers: silentPrayers ?? this.silentPrayers,
      reminderInterval: reminderInterval ?? this.reminderInterval,
      mutedPrayers: mutedPrayers ?? this.mutedPrayers,
      useAutomaticMethod: useAutomaticMethod ?? this.useAutomaticMethod,
      manualMethodId: useAutomaticMethod == true ? null : (manualMethodId ?? this.manualMethodId),
      madhab: madhab ?? this.madhab,
    );
  }

  /// Effective sound for a single prayer: the global adhan-sound master
  /// switch, minus any per-prayer silence exceptions.
  bool prayerHasSound(String prayerKey) {
    return adhanSoundEnabled && !silentPrayers.contains(prayerKey);
  }
}

/// Represents calculated prayer times for a single day.
class PrayerTimeEntity {
  final DateTime date;
  final DateTime fajr;
  final DateTime sunrise;
  final DateTime dhuhr;
  final DateTime asr;
  final DateTime maghrib;
  final DateTime isha;
  final String? hijriDateStr;
  final String? hijriDateStrAr;

  const PrayerTimeEntity({
    required this.date,
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    this.hijriDateStr,
    this.hijriDateStrAr,
  });
}

/// AlAdhan calculation method descriptor.
class AladhanMethod {
  final int id;
  final String name;
  const AladhanMethod(this.id, this.name);
}

const List<AladhanMethod> aladhanMethods = [
  AladhanMethod(1, 'University of Islamic Sciences, Karachi'),
  AladhanMethod(2, 'Islamic Society of North America (ISNA)'),
  AladhanMethod(3, 'Muslim World League'),
  AladhanMethod(4, 'Umm Al-Qura University, Makkah'),
  AladhanMethod(5, 'Egyptian General Authority of Survey'),
  AladhanMethod(7, 'Institute of Geophysics, University of Tehran'),
  AladhanMethod(8, 'Gulf Region'),
  AladhanMethod(9, 'Kuwait'),
  AladhanMethod(10, 'Qatar'),
  AladhanMethod(11, 'Majlis Ugama Islam Singapura, Singapore'),
  AladhanMethod(12, 'Union Organization Islamique de France'),
  AladhanMethod(13, 'Diyanet İşleri Başkanlığı, Turkey'),
  AladhanMethod(14, 'Spiritual Administration of Muslims of Russia'),
  AladhanMethod(15, 'Moonsighting Committee'),
  AladhanMethod(16, 'Dubai, UAE'),
  AladhanMethod(18, 'Tunisia'),
  AladhanMethod(19, 'Algeria'),
  AladhanMethod(21, 'Morocco (Ministry of Awqaf)'),
  AladhanMethod(22, 'Kementerian Agama Republik Indonesia'),
  AladhanMethod(23, 'Comunidade Islamica de Lisboa (Portugal)'),
];
