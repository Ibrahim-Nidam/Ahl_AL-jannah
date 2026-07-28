/// Domain entities for the Adhkar catalog (and future Tasbeeh reuse).
library;

/// A single dhikr item from the Adhkar catalog JSON.
class AdhkarItem {
  /// Stable id from the source dataset (when available).
  final int? id;

  /// Category key used for grouping and deep links
  /// (e.g. `أذكار الصباح` / `أذكار المساء`).
  final String category;

  /// English category label for non-Arabic locales.
  final String categoryEn;

  /// Arabic category label for the Arabic locale.
  final String categoryAr;

  /// Optional segment / section grouping from Hisnul Muslim.
  final String segment;

  /// Order within the category.
  final int order;

  /// Arabic text of the dhikr.
  final String arabic;

  /// Latin-script transliteration (when available).
  final String transliteration;

  /// Translation (English in the current catalog; shown for non-Arabic locales).
  final String translation;

  /// Free-form reference / source string.
  final String reference;

  /// Parsed book name from [reference] when available.
  final String book;

  /// Parsed hadith number from [reference] when available.
  final String hadithNumber;

  /// Authenticity / grading when available.
  final String authenticity;

  /// Narrator when available.
  final String narrator;

  /// Benefits / virtues (English / source language).
  final String benefits;

  /// Arabic benefits text for the Arabic locale.
  final String benefitsAr;

  /// Recommended repetition count (Sunnah). Defaults to 1.
  final int count;

  /// Pre-built search blob (Arabic + translation + transliteration + …).
  final String search;

  const AdhkarItem({
    this.id,
    required this.category,
    this.categoryEn = '',
    this.categoryAr = '',
    this.segment = '',
    this.order = 0,
    required this.arabic,
    this.transliteration = '',
    this.translation = '',
    this.reference = '',
    this.book = '',
    this.hadithNumber = '',
    this.authenticity = '',
    this.narrator = '',
    this.benefits = '',
    this.benefitsAr = '',
    this.count = 1,
    this.search = '',
  });

  /// Backward-compatible alias used by older call sites / future Tasbeeh.
  String get zekr => arabic;

  /// Benefits alias (older azkar-db used `description`).
  String get description => benefits;

  /// Stable unique key for favorites and local maps.
  String get uniqueKey =>
      id != null ? 'id_$id' : '${category.hashCode}_${arabic.hashCode}';

  /// Locale-aware category label.
  String categoryLabel(String languageCode) {
    if (languageCode == 'ar') {
      if (categoryAr.isNotEmpty) return categoryAr;
      // Morning/Evening keys are already Arabic.
      return category;
    }
    if (categoryEn.isNotEmpty) return categoryEn;
    return category;
  }

  /// Locale-aware benefits. Arabic UI never falls back to English text.
  String benefitsForLocale(String languageCode) {
    if (languageCode == 'ar') return benefitsAr;
    return benefits;
  }
}

/// A dynamically-derived category with its display names and item count.
class AdhkarCategory {
  /// Category key (matches [AdhkarItem.category]).
  final String name;

  /// English display name.
  final String nameEn;

  /// Arabic display name.
  final String nameAr;

  final int itemCount;

  const AdhkarCategory({
    required this.name,
    this.nameEn = '',
    this.nameAr = '',
    required this.itemCount,
  });

  String displayName(String languageCode) {
    if (languageCode == 'ar') {
      if (nameAr.isNotEmpty) return nameAr;
      return name;
    }
    if (nameEn.isNotEmpty) return nameEn;
    return name;
  }
}

/// Persistent user settings for the Adhkar feature.
class AdhkarSettings {
  final bool vibrateOnTap;
  final bool autoNext;
  final bool keepScreenAwake;
  final double arabicFontSize;

  const AdhkarSettings({
    this.vibrateOnTap = true,
    this.autoNext = false,
    this.keepScreenAwake = true,
    this.arabicFontSize = 22.0,
  });

  AdhkarSettings copyWith({
    bool? vibrateOnTap,
    bool? autoNext,
    bool? keepScreenAwake,
    double? arabicFontSize,
  }) {
    return AdhkarSettings(
      vibrateOnTap: vibrateOnTap ?? this.vibrateOnTap,
      autoNext: autoNext ?? this.autoNext,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
    );
  }

  Map<String, dynamic> toJson() => {
        'vibrateOnTap': vibrateOnTap,
        'autoNext': autoNext,
        'keepScreenAwake': keepScreenAwake,
        'arabicFontSize': arabicFontSize,
      };

  factory AdhkarSettings.fromJson(Map<String, dynamic> json) {
    return AdhkarSettings(
      vibrateOnTap: json['vibrateOnTap'] as bool? ?? true,
      autoNext: json['autoNext'] as bool? ?? false,
      keepScreenAwake: json['keepScreenAwake'] as bool? ?? true,
      arabicFontSize: (json['arabicFontSize'] as num?)?.toDouble() ?? 22.0,
    );
  }
}

// ── Tasbeeh domain types (shared via Adhkar feature; no duplicate catalog) ──

/// Counter target mode for Digital Tasbeeh.
enum TasbeehCounterMode {
  preset33,
  preset99,
  preset100,
  custom,
  unlimited,
}

extension TasbeehCounterModeX on TasbeehCounterMode {
  /// Resolved target count. `0` means unlimited. Custom uses [customTarget].
  int resolveTarget({required int customTarget}) {
    switch (this) {
      case TasbeehCounterMode.preset33:
        return 33;
      case TasbeehCounterMode.preset99:
        return 99;
      case TasbeehCounterMode.preset100:
        return 100;
      case TasbeehCounterMode.custom:
        return customTarget < 1 ? 1 : customTarget;
      case TasbeehCounterMode.unlimited:
        return 0;
    }
  }
}

/// How the active dhikr text was chosen.
enum TasbeehDhikrSource { catalog, collection, custom, empty }

/// One entry in the user's Tasbeeh quick-access collection.
class TasbeehCollectionItem {
  final String arabic;
  final String? catalogUniqueKey;
  final String translation;

  const TasbeehCollectionItem({
    required this.arabic,
    this.catalogUniqueKey,
    this.translation = '',
  });

  Map<String, dynamic> toJson() => {
        'arabic': arabic,
        'catalogUniqueKey': catalogUniqueKey,
        'translation': translation,
      };

  factory TasbeehCollectionItem.fromJson(Map<String, dynamic> json) {
    return TasbeehCollectionItem(
      arabic: json['arabic'] as String? ?? '',
      catalogUniqueKey: json['catalogUniqueKey'] as String?,
      translation: json['translation'] as String? ?? '',
    );
  }

  factory TasbeehCollectionItem.fromAdhkar(AdhkarItem item) {
    return TasbeehCollectionItem(
      arabic: item.arabic,
      catalogUniqueKey: item.uniqueKey,
      translation: item.translation,
    );
  }
}

/// Aggregated counters for a stats period (daily or lifetime).
class TasbeehAggregateStats {
  final int completedSessions;
  final int totalRepetitions;
  final int totalTimeMs;

  const TasbeehAggregateStats({
    this.completedSessions = 0,
    this.totalRepetitions = 0,
    this.totalTimeMs = 0,
  });

  bool get isEmpty =>
      completedSessions == 0 && totalRepetitions == 0 && totalTimeMs == 0;

  TasbeehAggregateStats operator +(TasbeehAggregateStats other) {
    return TasbeehAggregateStats(
      completedSessions: completedSessions + other.completedSessions,
      totalRepetitions: totalRepetitions + other.totalRepetitions,
      totalTimeMs: totalTimeMs + other.totalTimeMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'completedSessions': completedSessions,
        'totalRepetitions': totalRepetitions,
        'totalTimeMs': totalTimeMs,
      };

  factory TasbeehAggregateStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const TasbeehAggregateStats();
    return TasbeehAggregateStats(
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      totalRepetitions: (json['totalRepetitions'] as num?)?.toInt() ?? 0,
      totalTimeMs: (json['totalTimeMs'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One calendar day's Tasbeeh totals + per-dhikr breakdown.
class TasbeehDayStats {
  final String date;
  final TasbeehAggregateStats totals;
  final Map<String, TasbeehAggregateStats> byDhikr;

  const TasbeehDayStats({
    required this.date,
    this.totals = const TasbeehAggregateStats(),
    this.byDhikr = const {},
  });

  TasbeehDayStats applyDelta({
    required String dhikrText,
    required TasbeehAggregateStats delta,
  }) {
    final key = dhikrText.trim();
    final existing = byDhikr[key] ?? const TasbeehAggregateStats();
    return TasbeehDayStats(
      date: date,
      totals: totals + delta,
      byDhikr: {
        ...byDhikr,
        key: existing + delta,
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'totals': totals.toJson(),
        'byDhikr': byDhikr.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory TasbeehDayStats.fromJson(String date, Map<String, dynamic> json) {
    final rawBy = json['byDhikr'] as Map<String, dynamic>? ?? const {};
    return TasbeehDayStats(
      date: json['date'] as String? ?? date,
      totals: TasbeehAggregateStats.fromJson(
        json['totals'] as Map<String, dynamic>?,
      ),
      byDhikr: rawBy.map(
        (k, v) => MapEntry(
          k,
          TasbeehAggregateStats.fromJson(v as Map<String, dynamic>?),
        ),
      ),
    );
  }
}

/// Daily history + lifetime Tasbeeh statistics (incl. per-dhikr).
///
/// Designed so a future cloud sync can replace the local store without
/// changing the presentation layer — only the repository implementation.
class TasbeehStats {
  final Map<String, TasbeehDayStats> days;
  final TasbeehAggregateStats lifetime;
  final Map<String, TasbeehAggregateStats> lifetimeByDhikr;

  const TasbeehStats({
    this.days = const {},
    this.lifetime = const TasbeehAggregateStats(),
    this.lifetimeByDhikr = const {},
  });

  factory TasbeehStats.empty() => const TasbeehStats();

  /// Compatibility alias used by older call sites.
  String get dailyDate => TasbeehStats.todayKey();

  TasbeehAggregateStats get daily =>
      days[todayKey()]?.totals ?? const TasbeehAggregateStats();

  static String todayKey([DateTime? now]) {
    final d = now ?? DateTime.now();
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  /// Newest-first list of day keys that have any activity.
  List<String> get sortedDayKeys {
    final keys = days.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return keys;
  }

  TasbeehDayStats dayFor(String date) =>
      days[date] ?? TasbeehDayStats(date: date);

  /// No-op roll helper kept for older call sites.
  TasbeehStats rolledToToday([DateTime? now]) => this;

  TasbeehStats recordProgress({
    required String dhikrText,
    required int repetitions,
    required int durationMs,
    required bool countAsCompletedSession,
    DateTime? now,
  }) {
    final text = dhikrText.trim();
    if (text.isEmpty || (repetitions <= 0 && durationMs <= 0)) {
      return this;
    }

    final delta = TasbeehAggregateStats(
      completedSessions: countAsCompletedSession ? 1 : 0,
      totalRepetitions: repetitions < 0 ? 0 : repetitions,
      totalTimeMs: durationMs < 0 ? 0 : durationMs,
    );
    if (delta.isEmpty) return this;

    final date = todayKey(now);
    final day = dayFor(date).applyDelta(dhikrText: text, delta: delta);
    final existingLife = lifetimeByDhikr[text] ?? const TasbeehAggregateStats();

    return TasbeehStats(
      days: {...days, date: day},
      lifetime: lifetime + delta,
      lifetimeByDhikr: {
        ...lifetimeByDhikr,
        text: existingLife + delta,
      },
    );
  }

  TasbeehStats clearDay(String date) {
    final day = days[date];
    if (day == null || day.totals.isEmpty) {
      return TasbeehStats(
        days: {...days}..remove(date),
        lifetime: lifetime,
        lifetimeByDhikr: lifetimeByDhikr,
      );
    }

    // Subtract that day's totals from lifetime aggregates.
    var newLifetime = TasbeehAggregateStats(
      completedSessions:
          (lifetime.completedSessions - day.totals.completedSessions)
              .clamp(0, 1 << 30),
      totalRepetitions:
          (lifetime.totalRepetitions - day.totals.totalRepetitions)
              .clamp(0, 1 << 30),
      totalTimeMs:
          (lifetime.totalTimeMs - day.totals.totalTimeMs).clamp(0, 1 << 30),
    );

    final newByDhikr = Map<String, TasbeehAggregateStats>.from(lifetimeByDhikr);
    for (final entry in day.byDhikr.entries) {
      final prev = newByDhikr[entry.key];
      if (prev == null) continue;
      final next = TasbeehAggregateStats(
        completedSessions:
            (prev.completedSessions - entry.value.completedSessions)
                .clamp(0, 1 << 30),
        totalRepetitions:
            (prev.totalRepetitions - entry.value.totalRepetitions)
                .clamp(0, 1 << 30),
        totalTimeMs:
            (prev.totalTimeMs - entry.value.totalTimeMs).clamp(0, 1 << 30),
      );
      if (next.isEmpty) {
        newByDhikr.remove(entry.key);
      } else {
        newByDhikr[entry.key] = next;
      }
    }

    final newDays = Map<String, TasbeehDayStats>.from(days)..remove(date);
    return TasbeehStats(
      days: newDays,
      lifetime: newLifetime,
      lifetimeByDhikr: newByDhikr,
    );
  }

  TasbeehStats clearAll() => const TasbeehStats();

  Map<String, dynamic> toJson() => {
        'version': 3,
        'lifetime': lifetime.toJson(),
        'lifetimeByDhikr':
            lifetimeByDhikr.map((k, v) => MapEntry(k, v.toJson())),
        'days': days.map((k, v) => MapEntry(k, v.toJson())),
      };

  factory TasbeehStats.fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 0;

    // v3: days + per-dhikr
    if (version >= 3 || json.containsKey('days')) {
      final rawDays = json['days'] as Map<String, dynamic>? ?? const {};
      final rawLifeBy =
          json['lifetimeByDhikr'] as Map<String, dynamic>? ?? const {};
      return TasbeehStats(
        days: rawDays.map(
          (k, v) => MapEntry(
            k,
            TasbeehDayStats.fromJson(k, v as Map<String, dynamic>),
          ),
        ),
        lifetime: TasbeehAggregateStats.fromJson(
          json['lifetime'] as Map<String, dynamic>?,
        ),
        lifetimeByDhikr: rawLifeBy.map(
          (k, v) => MapEntry(
            k,
            TasbeehAggregateStats.fromJson(v as Map<String, dynamic>?),
          ),
        ),
      );
    }

    // v2: dailyDate + daily + lifetime
    if (json.containsKey('lifetime') || json.containsKey('dailyDate')) {
      final date = json['dailyDate'] as String? ?? todayKey();
      final daily = TasbeehAggregateStats.fromJson(
        json['daily'] as Map<String, dynamic>?,
      );
      final lifetime = TasbeehAggregateStats.fromJson(
        json['lifetime'] as Map<String, dynamic>?,
      );
      return TasbeehStats(
        days: daily.isEmpty
            ? const {}
            : {date: TasbeehDayStats(date: date, totals: daily)},
        lifetime: lifetime,
      );
    }

    // Legacy: Map<dhikrText, count>
    var totalReps = 0;
    final byDhikr = <String, TasbeehAggregateStats>{};
    for (final entry in json.entries) {
      if (entry.value is! num) continue;
      final reps = (entry.value as num).toInt();
      totalReps += reps;
      byDhikr[entry.key] = TasbeehAggregateStats(totalRepetitions: reps);
    }
    return TasbeehStats(
      lifetime: TasbeehAggregateStats(totalRepetitions: totalReps),
      lifetimeByDhikr: byDhikr,
    );
  }
}

