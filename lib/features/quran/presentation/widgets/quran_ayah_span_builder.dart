/// Single source of truth for how an ayah's Arabic text + verse-number
/// marker are turned into styled, tappable [InlineSpan]s. Used by both
/// the portrait "real Mushaf" page and the landscape infinite-scroll
/// reader (and the reader's per-ayah "study" cards), so there is exactly
/// one place that builds ayah spans.
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/quran_entities.dart';
import '../../domain/tajweed/quran_tajweed_analyzer.dart';
import '../../domain/tajweed/quran_tajweed_rule.dart';

abstract final class QuranAyahSpanBuilder {
  /// Arabic diacritical marks range used for stripping.
  static final _diacriticsRe = RegExp(
    '[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06DC'
    '\u06DF-\u06E8\u06EA-\u06ED]',
  );

  /// Marks that only exist in the database export, not in the printed
  /// Mushaf: the small high rounded zero (۟, U+06DF) and the small high
  /// upright rectangular zero (۠, U+06E0). With Uthmani Hafs fonts these
  /// render as a floating dot above/after letters (e.g. أُو۟لَـٰٓئِكَ at
  /// 2:5), which is not part of the actual Mushaf text.
  static final _unnaturalMarksRe = RegExp('[\u06DF\u06E0]');

  /// Removes the artificial "dot" marks (U+06DF/U+06E0) that are not part
  /// of the printed Mushaf, so previews, search results and shared text
  /// never carry them.
  static String stripUnnaturalTajweedMarks(String text) =>
      text.replaceAll(_unnaturalMarksRe, '');

  /// The Bismillah base consonants (no diacritics) to match against.
  static const _bismillahBase = 'بسم الله الرحمن الرحيم';

  /// Collapses the various alef forms (ٱ wasla, آ madda, أ hamza-above,
  /// إ hamza-below) to plain ا so text-skeleton comparisons are stable
  /// regardless of which alef variant a given Quran text encoding uses.
  static String _normalizeAlef(String ch) {
    const map = {
      '\u0671': '\u0627', // ٱ
      '\u0622': '\u0627', // آ
      '\u0623': '\u0627', // أ
      '\u0625': '\u0627', // إ
    };
    return map[ch] ?? ch;
  }

  /// Strips the leading Bismillah from ayah 1 of every Surah except
  /// At-Tawbah (9), where Bismillah is absent.
  /// Al-Fatihah (1) is intentionally included because the widget renders
  /// its own Bismillah header, so the DB copy must be hidden.
  ///
  /// Uses diacritic-stripping to match regardless of Unicode ordering
  /// differences between various Quran text encodings.
  static String formatAyahText(int surahId, int number, String text) {
    if (surahId != 9 && number == 1) {
      // Strip diacritics and normalise all alef variants (ٱ/آ/أ/إ → ا) to
      // get a skeleton we can compare reliably.
      final stripped = text
          .replaceAll(_diacriticsRe, '')
          .split('')
          .map(_normalizeAlef)
          .join();

      if (stripped.startsWith(_bismillahBase)) {
        // Walk through the *original* text, consuming characters until
        // we've matched every skeleton character in _bismillahBase.
        var matched = 0;
        var i = 0;
        while (i < text.length && matched < _bismillahBase.length) {
          final ch = text[i];
          if (_diacriticsRe.hasMatch(ch)) {
            // skip diacritics in original
            i++;
            continue;
          }
          // normalise alef variants for comparison
          final norm = _normalizeAlef(ch);
          if (norm == _bismillahBase[matched]) {
            matched++;
          }
          i++;
        }
        if (matched == _bismillahBase.length) {
          // Also consume any diacritics still attached to the last
          // matched letter (e.g. the kasra under the ي/م of الرحيم) so
          // they don't leak into the remaining ayah text as a stray mark.
          while (i < text.length && _diacriticsRe.hasMatch(text[i])) {
            i++;
          }
          return stripUnnaturalTajweedMarks(text.substring(i).trim());
        }
        debugPrint('[Basmala strip] surah=$surahId stripped="$stripped" match=${stripped.startsWith(_bismillahBase)}');
      }
    }
    return stripUnnaturalTajweedMarks(text);
  }

  static List<InlineSpan> build({
    required List<AyahEntity> ayahs,
    required double fontSize,
    required Color quranTextColor,
    required Color accentColor,
    required AyahEntity? selectedAyah,
    required Set<String> bookmarkedAyahKeys,
    required TapGestureRecognizer Function(AyahEntity ayah) recognizerFor,
    bool showTajweed = false,
    String fontFamily = 'Lateef',
    List<String> fontFamilyFallback = const ['Noto Naskh Arabic', 'Scheherazade New', 'Arial'],
  }) {
    final spans = <InlineSpan>[];

    for (final ayah in ayahs) {
      final formattedText = formatAyahText(ayah.surahId, ayah.number, ayah.textAr);
      final marks = showTajweed
          ? QuranTajweedAnalyzer.analyze(formattedText)
          : const <TajweedMark>[];
      final isSelected = selectedAyah?.id == ayah.id;
      final isBookmarked =
          bookmarkedAyahKeys.contains('${ayah.surahId}-${ayah.number}');
      final recognizer = recognizerFor(ayah);
      final highlightBg = isSelected
          ? accentColor.withAlpha(60)
          : (isBookmarked ? accentColor.withAlpha(35) : null);
      final baseColor =
          isSelected ? AppColors.primaryGreen : quranTextColor;
      final baseStyle = AppTextStyles.arabicQuran(
        fontSize: fontSize,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
      );

      spans.addAll(
        _buildAyahTextSpans(
          formattedText: formattedText,
          marks: marks,
          baseStyle: baseStyle,
          baseColor: baseColor,
          highlightBg: highlightBg,
          recognizer: recognizer,
        ),
      );

      spans.add(
        TextSpan(
          text: '﴿${ayah.number}﴾ ',
          style: AppTextStyles.caption.copyWith(
            color: isSelected
                ? AppColors.primaryGreen
                : (isBookmarked ? accentColor : AppColors.accentGoldDark),
            fontWeight: FontWeight.bold,
            fontSize: fontSize * 0.5,
            backgroundColor: highlightBg,
          ),
          recognizer: recognizer,
        ),
      );
    }

    return spans;
  }

  /// Splits an ayah's formatted text into colored [TextSpan]s. When
  /// tajweed marks are present, each marked run takes the rule's fixed
  /// color ([TajweedColors]); everything else keeps [baseColor]. Without
  /// marks the whole ayah is a single span (identical to the old path).
  static List<TextSpan> _buildAyahTextSpans({
    required String formattedText,
    required List<TajweedMark> marks,
    required TextStyle baseStyle,
    required Color baseColor,
    required Color? highlightBg,
    required TapGestureRecognizer recognizer,
  }) {
    if (marks.isEmpty) {
      return [
        TextSpan(
          text: '$formattedText ',
          style: baseStyle.copyWith(
            color: baseColor,
            backgroundColor: highlightBg,
          ),
          recognizer: recognizer,
        ),
      ];
    }

    final colors = List<Color?>.filled(formattedText.length, null);
    for (final mark in marks) {
      final color = _colorForRule(mark.rule);
      for (var i = mark.start; i < mark.end && i < formattedText.length; i++) {
        colors[i] = color;
      }
    }

    final spans = <TextSpan>[];
    var i = 0;
    while (i < formattedText.length) {
      final color = colors[i];
      var j = i + 1;
      while (j < formattedText.length && colors[j] == color) {
        j++;
      }
      spans.add(
        TextSpan(
          text: formattedText.substring(i, j),
          style: baseStyle.copyWith(
            color: color ?? baseColor,
            backgroundColor: highlightBg,
          ),
          recognizer: recognizer,
        ),
      );
      i = j;
    }
    // Trailing space so the verse marker is not glued to the last run.
    spans.add(
      TextSpan(
        text: ' ',
        style: baseStyle.copyWith(
          color: baseColor,
          backgroundColor: highlightBg,
        ),
        recognizer: recognizer,
      ),
    );
    return spans;
  }

  static Color _colorForRule(QuranTajweedRule rule) {
    switch (rule) {
      case QuranTajweedRule.madd:
        return TajweedColors.madd;
      case QuranTajweedRule.maddWajib:
        return TajweedColors.maddWajib;
      case QuranTajweedRule.maddJaiz:
        return TajweedColors.maddJaiz;
      case QuranTajweedRule.maddLazim:
        return TajweedColors.maddLazim;
      case QuranTajweedRule.maddSilaSughra:
        return TajweedColors.maddSilaSughra;
      case QuranTajweedRule.ghunnah:
        return TajweedColors.ghunnah;
      case QuranTajweedRule.ikhfa:
        return TajweedColors.ikhfa;
      case QuranTajweedRule.qalqalah:
        return TajweedColors.qalqalah;
      case QuranTajweedRule.idghamBilaGhunnah:
        return TajweedColors.idghamBilaGhunnah;
      case QuranTajweedRule.ikhfaShafawi:
        return TajweedColors.ikhfaShafawi;
      case QuranTajweedRule.iqlab:
        return TajweedColors.iqlab;
      case QuranTajweedRule.notPronounced:
        return TajweedColors.notPronounced;
    }
  }
}