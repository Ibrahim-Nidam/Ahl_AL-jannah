/// App-wide color palette for Ahl Jannah.
///
/// This file is the single source of truth for every raw color value used
/// anywhere in the app. It defines three independent palettes — Emerald
/// (classic/default), Ocean, and Desert — each with full light/dark
/// variants. Nothing outside this file should declare a new `Color(...)`
/// literal for UI purposes.
///
/// `AppColors` itself remains the original Emerald palette values,
/// unchanged, so existing call sites (e.g. the Quran reader, which is out
/// of scope for this change) keep compiling and rendering exactly as
/// before. `AppOceanColors` and `AppDesertColors` are the two additional
/// palettes. All three are combined into resolvable [AppPaletteColors]
/// objects in `app_palettes.dart`.
library;
import 'package:flutter/material.dart';

/// Emerald palette (the original/default palette).
abstract final class AppColors {
  // ── Primary: Deep Emerald Green ──
  static const Color primaryGreen = Color(0xFF0D7A3E);
  static const Color primaryGreenLight = Color(0xFF2E9E5E);
  static const Color primaryGreenDark = Color(0xFF065A2C);

  // ── Secondary: Warm Gold ──
  static const Color accentGold = Color(0xFFD4A843);
  static const Color accentGoldLight = Color(0xFFE8C96D);
  static const Color accentGoldDark = Color(0xFFB8912E);

  // ── Tertiary: Soft Teal ──
  static const Color teal = Color(0xFF1A8A7D);
  static const Color tealLight = Color(0xFF4DB8AC);

  // ── Light Theme Surfaces ──
  static const Color surfaceLight = Color(0xFFFAF8F3);
  static const Color surfaceLightVariant = Color(0xFFF2EDE4);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF1C1B1F);
  static const Color onSurfaceLightVariant = Color(0xFF49454F);

  // ── Dark Theme Surfaces ──
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceDarkVariant = Color(0xFF1E1E2A);
  static const Color cardDark = Color(0xFF1E2A1E);
  static const Color onSurfaceDark = Color(0xFFE6E1E5);
  static const Color onSurfaceDarkVariant = Color(0xFFCAC4D0);

  // ── Semantic Colors (shared across all palettes) ──
  static const Color error = Color(0xFFD32F2F);
  static const Color errorLight = Color(0xFFEF5350);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);

  // ── Decorative (shared across all palettes) ──
  static const Color shimmerBase = Color(0xFFE0E0E0);
  static const Color shimmerHighlight = Color(0xFFF5F5F5);
  static const Color divider = Color(0xFFE0D9CF);
  static const Color dividerDark = Color(0xFF2C2C3A);
}

/// Ocean palette — cool teal-blue primary, warm amber accent, indigo
/// tertiary. Designed for the same contrast targets as [AppColors].
abstract final class AppOceanColors {
  static const Color primary = Color(0xFF0B6E7A);
  static const Color primaryLight = Color(0xFF3B9CA8);
  static const Color primaryDark = Color(0xFF054850);

  static const Color accent = Color(0xFFD98C3D);
  static const Color accentLight = Color(0xFFEDB06B);
  static const Color accentDark = Color(0xFFB06E22);

  static const Color tertiary = Color(0xFF3F51B5);
  static const Color tertiaryLight = Color(0xFF7986CB);

  static const Color surfaceLight = Color(0xFFF5FAFA);
  static const Color surfaceLightVariant = Color(0xFFE9F2F2);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF10201F);
  static const Color onSurfaceLightVariant = Color(0xFF3E4F4F);

  static const Color surfaceDark = Color(0xFF0E1517);
  static const Color surfaceDarkVariant = Color(0xFF162226);
  static const Color cardDark = Color(0xFF16292C);
  static const Color onSurfaceDark = Color(0xFFE3F1F1);
  static const Color onSurfaceDarkVariant = Color(0xFFBFD3D3);

  static const Color divider = Color(0xFFCFE3E3);
  static const Color dividerDark = Color(0xFF243638);
}

/// Desert palette — deep maroon primary, warm gold accent, bronze/olive
/// tertiary, sand-toned surfaces.
abstract final class AppDesertColors {
  static const Color primary = Color(0xFF7A2E3E);
  static const Color primaryLight = Color(0xFFA34C5E);
  static const Color primaryDark = Color(0xFF551F2B);

  static const Color accent = Color(0xFFC9962E);
  static const Color accentLight = Color(0xFFE0B863);
  static const Color accentDark = Color(0xFF9C7420);

  static const Color tertiary = Color(0xFF7C6A46);
  static const Color tertiaryLight = Color(0xFFA6926A);

  static const Color surfaceLight = Color(0xFFFAF4EC);
  static const Color surfaceLightVariant = Color(0xFFF1E6D6);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF241416);
  static const Color onSurfaceLightVariant = Color(0xFF564042);

  static const Color surfaceDark = Color(0xFF171012);
  static const Color surfaceDarkVariant = Color(0xFF241A1D);
  static const Color cardDark = Color(0xFF2B1E21);
  static const Color onSurfaceDark = Color(0xFFF0E2E4);
  static const Color onSurfaceDarkVariant = Color(0xFFD8C4C7);

  static const Color divider = Color(0xFFE6D4C3);
  static const Color dividerDark = Color(0xFF3A2A2D);
}

/// Tajweed rule colors used by the Quran reader's "Show Tajweed Rules"
/// mode. These are intentionally **fixed** and independent of the selected
/// [AppColorPalette] / brightness so a user who learns "red = madd" keeps
/// that association no matter which palette they switch to.
///
/// The hues follow the well-known Madani Mushaf coloring convention:
/// red for elongation (madd), green for nasalization / idgham bighunnah /
/// Colors for the tajweed highlighting. Follows the Quran Foundation
/// (Quran.com) palette, which is red-family for the madd lengths (natural
/// red, muttasil/munfasil red, lazim dark red, sila sughra light orange),
/// green for the ghunnah family (ghunnah, idgham bighunnah, iqlab), teal
/// for ikhfa, blue for qalqalah, brown for idgham bila ghunnah, gray for
/// ikhfa shafawi, and light gray for the "not pronounced" noon/tanween of
/// idgham and iqlab.
abstract final class TajweedColors {
  /// Madd tabee'i — natural 2-count elongation (red).
  static const Color madd = Color(0xFFE53935);

  /// Madd wajib muttasil — 4/5-count before a hamza in the same word.
  static const Color maddWajib = Color(0xFFF44336);

  /// Madd ja'iz munfasil — 4-count before a word-initial hamza.
  static const Color maddJaiz = Color(0xFFE57373);

  /// Madd lazim — 6-count (mushaddad / huruf al-muqatta'at).
  static const Color maddLazim = Color(0xFFB71C1C);

  /// Madd sila sughra — 2-count small-waw/yeh on the heh (light orange).
  static const Color maddSilaSughra = Color(0xFFFFB74D);

  /// Ghunnah, idgham bighunnah letter, idgham shafawi (green).
  static const Color ghunnah = Color(0xFF43A047);

  /// Ikhfa — concealment of noon saakinah / tanween (teal).
  static const Color ikhfa = Color(0xFF26A69A);

  /// Qalqalah — echoing letters ق ط ب ج د (blue).
  static const Color qalqalah = Color(0xFF1E88E5);

  /// Idgham bila ghunnah — merge without nasalization (ل ر) (brown).
  static const Color idghamBilaGhunnah = Color(0xFF8D6E63);

  /// Ikhfa shafawi — concealment of meem saakinah before ب (gray).
  static const Color ikhfaShafawi = Color(0xFF78909C);

  /// Iqlab — the ب following a converted noon/tanween (green).
  static const Color iqlab = Color(0xFF43A047);

  /// The unpronounced noon/tanween of idgham bighunnah and iqlab (gray).
  static const Color notPronounced = Color(0xFF9E9E9E);
}