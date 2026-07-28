/// Material 3 theme configuration for Ahl Jannah.
///
/// Builds light/dark [ThemeData] from a selected [AppColorPalette],
/// attaching the resolved [AppPaletteColors] as a [ThemeExtension] so any
/// widget in the app can read palette-aware colors (including the
/// dedicated Quran-text color) via `Theme.of(context)`.
library;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/settings/domain/entities/settings_entities.dart';
import 'app_palettes.dart';

abstract final class AppTheme {
  static ThemeData light([AppColorPalette palette = AppColorPalette.classic]) {
    return _build(AppPalettes.resolve(palette, Brightness.light), Brightness.light);
  }

  static ThemeData dark([AppColorPalette palette = AppColorPalette.classic]) {
    return _build(AppPalettes.resolve(palette, Brightness.dark), Brightness.dark);
  }

  /// Picks black or white — whichever gives stronger contrast — for text
  /// or icons placed on top of [background]. Used to keep the app legible
  /// (high contrast) across all three palettes without hand-tuning each
  /// on-color individually.
  static Color _contrastOn(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  static ThemeData _build(AppPaletteColors p, Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = ColorScheme.fromSeed(
      seedColor: p.primary,
      brightness: brightness,
      primary: p.primary,
      onPrimary: _contrastOn(p.primary),
      secondary: p.accent,
      onSecondary: _contrastOn(p.accent),
      tertiary: p.tertiary,
      onTertiary: _contrastOn(p.tertiary),
      surface: p.surface,
      onSurface: p.onSurface,
      onSurfaceVariant: p.onSurfaceVariant,
      error: p.error,
      onError: _contrastOn(p.error),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: p.surface,
      fontFamily: 'Inter',

      // The design-system extension — this is what makes palette colors
      // (including `quranText`) available anywhere via
      // `Theme.of(context).extension<AppPaletteColors>()`.
      extensions: <ThemeExtension<dynamic>>[p],

      // ── App Bar ──
      appBarTheme: AppBarTheme(
        backgroundColor: p.surface,
        foregroundColor: p.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        systemOverlayStyle:
            isLight ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: p.onSurface,
          letterSpacing: -0.3,
        ),
      ),

      // ── Bottom Navigation ──
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? p.card : p.surfaceVariant,
        indicatorColor: p.primary.withAlpha(isLight ? 30 : 40),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: p.primary,
            );
          }
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: p.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: p.primary, size: 24);
          }
          return IconThemeData(color: p.onSurfaceVariant, size: 24);
        }),
        elevation: 3,
        height: 72,
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.divider.withAlpha(80)),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: p.divider,
        thickness: 0.5,
        space: 1,
      ),

      // ── Elevated Button ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: _contrastOn(p.primary),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Icon ──
      iconTheme: IconThemeData(color: p.onSurfaceVariant, size: 24),

      // ── Text ──
      textTheme: _buildTextTheme(p.onSurface),
    );
  }

  /// Builds a [TextTheme] using [color] for every role. Latin/general UI
  /// text — never used for Quran ayahs, which always use the dedicated
  /// `quranText` color plus the user's selected Quran font instead.
  static TextTheme _buildTextTheme(Color color) {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(fontSize: 45, fontWeight: FontWeight.w400, color: color),
      displaySmall: TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: color),
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: color),
      titleLarge: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: color, height: 1.5),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: color, height: 1.5),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: color, height: 1.4),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }
}