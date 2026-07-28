/// Reusable text styles for Ahl Jannah.
///
/// Arabic Quran/body/heading styles now accept an optional font family +
/// fallback list (defaulting to the original Lateef configuration) so
/// callers can drive them from the user's selected [QuranFont] without
/// this file needing to know about the settings feature at all — keeping
/// `core/theme` fully decoupled from `features/settings`.
library;

import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const List<String> _defaultArabicFallback = [
    'Noto Naskh Arabic',
    'Scheherazade New',
    'Arial',
  ];

  // ── Arabic Styles ──

  /// Primary Arabic text style for Quran ayahs.
  static TextStyle arabicQuran({
    double fontSize = 28,
    String fontFamily = 'Lateef',
    List<String> fontFamilyFallback = _defaultArabicFallback,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: fontSize,
    height: 2.0, // generous line height for tashkeel
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    locale: const Locale('ar'),
    fontFeatures: const [
      FontFeature.enable('liga'),
      FontFeature.enable('calt'),
      FontFeature.enable('rlig'),
    ],
  );

  /// Arabic text for adhkar, hadith, and general Islamic content.
  static TextStyle arabicBody({
    double fontSize = 22,
    String fontFamily = 'Lateef',
    List<String> fontFamilyFallback = _defaultArabicFallback,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: fontSize,
    height: 1.8,
    fontWeight: FontWeight.w400,
    locale: const Locale('ar'),
    fontFeatures: const [
      FontFeature.enable('liga'),
      FontFeature.enable('calt'),
      FontFeature.enable('rlig'),
    ],
  );

  /// Bold Arabic text for surah names and headings.
  static TextStyle arabicHeading({
    double fontSize = 24,
    String fontFamily = 'Lateef',
    List<String> fontFamilyFallback = _defaultArabicFallback,
  }) => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: fontSize,
    height: 1.6,
    fontWeight: FontWeight.w700,
    locale: const Locale('ar'),
    fontFeatures: const [
      FontFeature.enable('liga'),
      FontFeature.enable('calt'),
      FontFeature.enable('rlig'),
    ],
  );

  // ── Latin / Translation Styles ──

  /// Translation text below Arabic.
  static const TextStyle translation = TextStyle(
    fontSize: 15,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: Color(0xFF49454F),
  );

  /// Section headings.
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Body text.
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Caption and labels.
  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.3,
  );

  /// Number displays (prayer countdown, counters).
  static const TextStyle numberDisplay = TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.w300,
    height: 1.1,
    letterSpacing: -1.0,
  );
}