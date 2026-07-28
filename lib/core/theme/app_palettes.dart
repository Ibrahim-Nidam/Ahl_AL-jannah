/// Resolves the app's [AppColorPalette] setting + current [Brightness]
/// into a concrete set of colors, exposed as a Material [ThemeExtension].
///
/// This is the mechanism that makes the design system scalable: any
/// widget can call `Theme.of(context).extension<AppPaletteColors>()!` and
/// automatically get colors that match whatever the user has selected,
/// with zero per-widget logic. Adding a fourth palette later means adding
/// one color group to `app_colors.dart` and one case here — nothing else
/// in the app needs to change.
library;
import 'package:flutter/material.dart';

import '../../features/settings/domain/entities/settings_entities.dart';
import 'app_colors.dart';

/// A resolved, brightness-aware color set for a single palette.
@immutable
class AppPaletteColors extends ThemeExtension<AppPaletteColors> {
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;
  final Color accentLight;
  final Color accentDark;
  final Color tertiary;
  final Color tertiaryLight;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color divider;
  final Color error;
  final Color success;
  final Color warning;
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Dedicated Quran-ayah text color. Pure black in light mode (per
  /// design requirement), and a soft high-contrast tone in dark mode.
  final Color quranText;

  const AppPaletteColors({
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.tertiary,
    required this.tertiaryLight,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.divider,
    required this.error,
    required this.success,
    required this.warning,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.quranText,
  });

  @override
  AppPaletteColors copyWith({
    Color? primary,
    Color? primaryLight,
    Color? primaryDark,
    Color? accent,
    Color? accentLight,
    Color? accentDark,
    Color? tertiary,
    Color? tertiaryLight,
    Color? surface,
    Color? surfaceVariant,
    Color? card,
    Color? onSurface,
    Color? onSurfaceVariant,
    Color? divider,
    Color? error,
    Color? success,
    Color? warning,
    Color? shimmerBase,
    Color? shimmerHighlight,
    Color? quranText,
  }) {
    return AppPaletteColors(
      primary: primary ?? this.primary,
      primaryLight: primaryLight ?? this.primaryLight,
      primaryDark: primaryDark ?? this.primaryDark,
      accent: accent ?? this.accent,
      accentLight: accentLight ?? this.accentLight,
      accentDark: accentDark ?? this.accentDark,
      tertiary: tertiary ?? this.tertiary,
      tertiaryLight: tertiaryLight ?? this.tertiaryLight,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      onSurface: onSurface ?? this.onSurface,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      divider: divider ?? this.divider,
      error: error ?? this.error,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
      quranText: quranText ?? this.quranText,
    );
  }

  @override
  AppPaletteColors lerp(ThemeExtension<AppPaletteColors>? other, double t) {
    if (other is! AppPaletteColors) return this;
    return AppPaletteColors(
      primary: Color.lerp(primary, other.primary, t)!,
      primaryLight: Color.lerp(primaryLight, other.primaryLight, t)!,
      primaryDark: Color.lerp(primaryDark, other.primaryDark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentLight: Color.lerp(accentLight, other.accentLight, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
      tertiary: Color.lerp(tertiary, other.tertiary, t)!,
      tertiaryLight: Color.lerp(tertiaryLight, other.tertiaryLight, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      onSurfaceVariant:
          Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      error: Color.lerp(error, other.error, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight:
          Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
      quranText: Color.lerp(quranText, other.quranText, t)!,
    );
  }
}

/// Resolves [AppColorPalette] + [Brightness] into [AppPaletteColors].
///
/// This is the *only* place that needs to change to add a new palette:
/// add the color group to `app_colors.dart`, then add one case + two
/// static const definitions (light/dark) below.
abstract final class AppPalettes {
  static AppPaletteColors resolve(
    AppColorPalette palette,
    Brightness brightness,
  ) {
    switch (palette) {
      case AppColorPalette.classic:
        return brightness == Brightness.light ? _emeraldLight : _emeraldDark;
      case AppColorPalette.ocean:
        return brightness == Brightness.light ? _oceanLight : _oceanDark;
      case AppColorPalette.desert:
        return brightness == Brightness.light ? _desertLight : _desertDark;
    }
  }

  // ── Emerald (classic / default) ──
  static const _emeraldLight = AppPaletteColors(
    primary: AppColors.primaryGreen,
    primaryLight: AppColors.primaryGreenLight,
    primaryDark: AppColors.primaryGreenDark,
    accent: AppColors.accentGold,
    accentLight: AppColors.accentGoldLight,
    accentDark: AppColors.accentGoldDark,
    tertiary: AppColors.teal,
    tertiaryLight: AppColors.tealLight,
    surface: AppColors.surfaceLight,
    surfaceVariant: AppColors.surfaceLightVariant,
    card: AppColors.cardLight,
    onSurface: AppColors.onSurfaceLight,
    onSurfaceVariant: AppColors.onSurfaceLightVariant,
    divider: AppColors.divider,
    error: AppColors.error,
    success: AppColors.success,
    warning: AppColors.warning,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    quranText: Color(0xFF000000),
  );

  static const _emeraldDark = AppPaletteColors(
    primary: AppColors.primaryGreenLight,
    primaryLight: AppColors.primaryGreenLight,
    primaryDark: AppColors.primaryGreenDark,
    accent: AppColors.accentGoldLight,
    accentLight: AppColors.accentGoldLight,
    accentDark: AppColors.accentGoldDark,
    tertiary: AppColors.tealLight,
    tertiaryLight: AppColors.tealLight,
    surface: AppColors.surfaceDark,
    surfaceVariant: AppColors.surfaceDarkVariant,
    card: AppColors.cardDark,
    onSurface: AppColors.onSurfaceDark,
    onSurfaceVariant: AppColors.onSurfaceDarkVariant,
    divider: AppColors.dividerDark,
    error: AppColors.errorLight,
    success: AppColors.success,
    warning: AppColors.warning,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    quranText: AppColors.onSurfaceDark,
  );

  // ── Ocean ──
  static const _oceanLight = AppPaletteColors(
    primary: AppOceanColors.primary,
    primaryLight: AppOceanColors.primaryLight,
    primaryDark: AppOceanColors.primaryDark,
    accent: AppOceanColors.accent,
    accentLight: AppOceanColors.accentLight,
    accentDark: AppOceanColors.accentDark,
    tertiary: AppOceanColors.tertiary,
    tertiaryLight: AppOceanColors.tertiaryLight,
    surface: AppOceanColors.surfaceLight,
    surfaceVariant: AppOceanColors.surfaceLightVariant,
    card: AppOceanColors.cardLight,
    onSurface: AppOceanColors.onSurfaceLight,
    onSurfaceVariant: AppOceanColors.onSurfaceLightVariant,
    divider: AppOceanColors.divider,
    error: AppColors.error,
    success: AppColors.success,
    warning: AppColors.warning,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    quranText: Color(0xFF000000),
  );

  static const _oceanDark = AppPaletteColors(
    primary: AppOceanColors.primaryLight,
    primaryLight: AppOceanColors.primaryLight,
    primaryDark: AppOceanColors.primaryDark,
    accent: AppOceanColors.accentLight,
    accentLight: AppOceanColors.accentLight,
    accentDark: AppOceanColors.accentDark,
    tertiary: AppOceanColors.tertiaryLight,
    tertiaryLight: AppOceanColors.tertiaryLight,
    surface: AppOceanColors.surfaceDark,
    surfaceVariant: AppOceanColors.surfaceDarkVariant,
    card: AppOceanColors.cardDark,
    onSurface: AppOceanColors.onSurfaceDark,
    onSurfaceVariant: AppOceanColors.onSurfaceDarkVariant,
    divider: AppOceanColors.dividerDark,
    error: AppColors.errorLight,
    success: AppColors.success,
    warning: AppColors.warning,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    quranText: AppOceanColors.onSurfaceDark,
  );

  // ── Desert ──
  static const _desertLight = AppPaletteColors(
    primary: AppDesertColors.primary,
    primaryLight: AppDesertColors.primaryLight,
    primaryDark: AppDesertColors.primaryDark,
    accent: AppDesertColors.accent,
    accentLight: AppDesertColors.accentLight,
    accentDark: AppDesertColors.accentDark,
    tertiary: AppDesertColors.tertiary,
    tertiaryLight: AppDesertColors.tertiaryLight,
    surface: AppDesertColors.surfaceLight,
    surfaceVariant: AppDesertColors.surfaceLightVariant,
    card: AppDesertColors.cardLight,
    onSurface: AppDesertColors.onSurfaceLight,
    onSurfaceVariant: AppDesertColors.onSurfaceLightVariant,
    divider: AppDesertColors.divider,
    error: AppColors.error,
    success: AppColors.success,
    warning: AppColors.warning,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    quranText: Color(0xFF000000),
  );

  static const _desertDark = AppPaletteColors(
    primary: AppDesertColors.primaryLight,
    primaryLight: AppDesertColors.primaryLight,
    primaryDark: AppDesertColors.primaryDark,
    accent: AppDesertColors.accentLight,
    accentLight: AppDesertColors.accentLight,
    accentDark: AppDesertColors.accentDark,
    tertiary: AppDesertColors.tertiaryLight,
    tertiaryLight: AppDesertColors.tertiaryLight,
    surface: AppDesertColors.surfaceDark,
    surfaceVariant: AppDesertColors.surfaceDarkVariant,
    card: AppDesertColors.cardDark,
    onSurface: AppDesertColors.onSurfaceDark,
    onSurfaceVariant: AppDesertColors.onSurfaceDarkVariant,
    divider: AppDesertColors.dividerDark,
    error: AppColors.errorLight,
    success: AppColors.success,
    warning: AppColors.warning,
    shimmerBase: AppColors.shimmerBase,
    shimmerHighlight: AppColors.shimmerHighlight,
    quranText: AppDesertColors.onSurfaceDark,
  );
}