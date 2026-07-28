import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ahl_jannah/core/theme/app_colors.dart';
import 'package:ahl_jannah/core/theme/app_text_styles.dart';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';

import '../../domain/entities/adhkar_entities.dart';
import 'adhkar_repetition_counter.dart';

/// One-dhikr-at-a-time reader with horizontal swipe and auto-advance.
///
/// Counters live in this widget and are discarded when it is disposed
/// (i.e. when the user leaves the category).
class AdhkarCategoryReader extends StatefulWidget {
  final List<AdhkarItem> items;
  final double arabicFontSize;
  final int initialIndex;
  final String emptyLabel;
  final bool isLoading;

  const AdhkarCategoryReader({
    super.key,
    required this.items,
    required this.arabicFontSize,
    this.initialIndex = 0,
    required this.emptyLabel,
    this.isLoading = false,
  });

  @override
  State<AdhkarCategoryReader> createState() => _AdhkarCategoryReaderState();
}

class _AdhkarCategoryReaderState extends State<AdhkarCategoryReader> {
  late final PageController _pageController;
  late int _index;
  final Map<String, int> _repetitions = {};

  /// User toggles for locales that hide extras by default (ar / fr).
  bool _showTranslation = false;
  bool _showTransliteration = false;
  bool _localeDefaultsApplied = false;

  @override
  void initState() {
    super.initState();
    final max = widget.items.isEmpty ? 0 : widget.items.length - 1;
    _index = widget.initialIndex.clamp(0, max);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_localeDefaultsApplied) return;
    _localeDefaultsApplied = true;
    final lang = Localizations.localeOf(context).languageCode;
    // English shows translation + transliteration by default.
    // Arabic & French keep translation hidden until opted in.
    // Arabic never offers transliteration; French hides it until opted in.
    if (lang == 'en') {
      _showTranslation = true;
      _showTransliteration = true;
    }
  }

  @override
  void didUpdateWidget(covariant AdhkarCategoryReader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      // New category / filtered set — reset counters and page.
      _repetitions.clear();
      final max = widget.items.isEmpty ? 0 : widget.items.length - 1;
      _index = widget.initialIndex.clamp(0, max);
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_index);
      }
    }
  }

  @override
  void dispose() {
    _repetitions.clear();
    _pageController.dispose();
    super.dispose();
  }

  /// Arabic UI never shows transliteration.
  bool _canOfferTransliteration(String lang) => lang != 'ar';

  bool _translationVisible(String lang) {
    if (lang == 'en') return true;
    return _showTranslation;
  }

  bool _transliterationVisible(String lang) {
    if (!_canOfferTransliteration(lang)) return false;
    if (lang == 'en') return true;
    return _showTransliteration;
  }

  void _onIncrement(AdhkarItem item) {
    final key = item.uniqueKey;
    final target = item.count < 1 ? 1 : item.count;
    final current = _repetitions[key] ?? 0;
    if (current >= target) return;

    final next = current + 1;
    setState(() => _repetitions[key] = next);

    if (next >= target && _index < widget.items.length - 1) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  void _openInTasbeeh(AdhkarItem item) {
    context.pushNamed(
      'tasbeeh',
      extra: <String, dynamic>{
        'item': item,
        'addToCollection': true,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isLoading && widget.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.items.isEmpty) {
      return Center(child: Text(widget.emptyLabel));
    }

    final total = widget.items.length;
    final progress = total == 0 ? 0.0 : (_index + 1) / total;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Row(
            children: [
              Text(
                l10n.adhkarProgressLabel(_index + 1, total),
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDarkVariant
                      : AppColors.onSurfaceLightVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                l10n.adhkarSwipeHint,
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDarkVariant.withValues(alpha: 0.8)
                      : AppColors.onSurfaceLightVariant.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: isDark
                  ? AppColors.surfaceDarkVariant
                  : AppColors.surfaceLightVariant,
              color: AppColors.primaryGreen,
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: total,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return _DhikrSlide(
                item: item,
                index: index,
                arabicFontSize: widget.arabicFontSize,
                repetitionCurrent: _repetitions[item.uniqueKey] ?? 0,
                showTranslation: _translationVisible(lang) &&
                    item.translation.isNotEmpty,
                showTransliteration: _transliterationVisible(lang) &&
                    item.transliteration.isNotEmpty,
                // ar/fr: translation opt-in. fr: transliteration opt-in.
                // ar: transliteration never offered. en: both always on.
                offerTranslationToggle:
                    lang != 'en' && item.translation.isNotEmpty,
                offerTransliterationToggle: _canOfferTransliteration(lang) &&
                    lang != 'en' &&
                    item.transliteration.isNotEmpty,
                translationExpanded: _showTranslation,
                transliterationExpanded: _showTransliteration,
                onToggleTranslation: () {
                  setState(() => _showTranslation = !_showTranslation);
                },
                onToggleTransliteration: () {
                  setState(() => _showTransliteration = !_showTransliteration);
                },
                onIncrement: () => _onIncrement(item),
                onReset: () {
                  setState(() => _repetitions[item.uniqueKey] = 0);
                },
                onAddToTasbeeh: () => _openInTasbeeh(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DhikrSlide extends StatelessWidget {
  final AdhkarItem item;
  final int index;
  final double arabicFontSize;
  final int repetitionCurrent;
  final bool showTranslation;
  final bool showTransliteration;
  final bool offerTranslationToggle;
  final bool offerTransliterationToggle;
  final bool translationExpanded;
  final bool transliterationExpanded;
  final VoidCallback onToggleTranslation;
  final VoidCallback onToggleTransliteration;
  final VoidCallback onIncrement;
  final VoidCallback onReset;
  final VoidCallback onAddToTasbeeh;

  const _DhikrSlide({
    required this.item,
    required this.index,
    required this.arabicFontSize,
    required this.repetitionCurrent,
    required this.showTranslation,
    required this.showTransliteration,
    required this.offerTranslationToggle,
    required this.offerTransliterationToggle,
    required this.translationExpanded,
    required this.transliterationExpanded,
    required this.onToggleTranslation,
    required this.onToggleTransliteration,
    required this.onIncrement,
    required this.onReset,
    required this.onAddToTasbeeh,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final target = item.count < 1 ? 1 : item.count;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AppColors.surfaceDarkVariant,
                          AppColors.cardDark,
                        ]
                      : [
                          Colors.white,
                          AppColors.surfaceLightVariant,
                        ],
                ),
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.divider.withValues(alpha: 0.7),
                ),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (target > 1)
                          Text(
                            l10n.adhkarRepeatHint(target),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.accentGoldDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      item.arabic,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: AppTextStyles.arabicBody(
                        fontSize: arabicFontSize + 4,
                      ).copyWith(
                        color: isDark
                            ? AppColors.onSurfaceDark
                            : AppColors.onSurfaceLight,
                        height: 2.0,
                      ),
                    ),
                    if (offerTransliterationToggle || offerTranslationToggle) ...[
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (offerTransliterationToggle)
                            TextButton.icon(
                              onPressed: onToggleTransliteration,
                              icon: Icon(
                                transliterationExpanded
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: Text(
                                transliterationExpanded
                                    ? l10n.adhkarHideTransliteration
                                    : l10n.adhkarShowTransliteration,
                              ),
                            ),
                          if (offerTranslationToggle)
                            TextButton.icon(
                              onPressed: onToggleTranslation,
                              icon: Icon(
                                translationExpanded
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                              ),
                              label: Text(
                                translationExpanded
                                    ? l10n.adhkarHideTranslation
                                    : l10n.adhkarShowTranslation,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (showTransliteration) ...[
                      const SizedBox(height: 12),
                      Text(
                        item.transliteration,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDarkVariant
                              : AppColors.onSurfaceLightVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (showTranslation) ...[
                      const SizedBox(height: 12),
                      Text(
                        item.translation,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.translation.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDarkVariant
                              : AppColors.onSurfaceLightVariant,
                        ),
                      ),
                    ],
                    if (_hasMeta) ...[
                      const SizedBox(height: 18),
                      Divider(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.divider.withValues(alpha: 0.8),
                      ),
                      const SizedBox(height: 8),
                      ..._metaRows(l10n, isDark),
                    ],
                    if (item.benefitsForLocale(lang).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        l10n.adhkarBenefitsLabel,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.benefitsForLocale(lang),
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDarkVariant
                              : AppColors.onSurfaceLightVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Center(
                      child: FilledButton.tonalIcon(
                        onPressed: onAddToTasbeeh,
                        icon: const Icon(Icons.fingerprint_rounded, size: 20),
                        label: Text(l10n.tasbeehAddAndOpen),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AdhkarRepetitionCounter(
            current: repetitionCurrent,
            target: target,
            onIncrement: onIncrement,
            onReset: onReset,
          ),
        ],
      ),
    );
  }

  bool get _hasMeta =>
      item.reference.isNotEmpty ||
      item.authenticity.isNotEmpty ||
      item.narrator.isNotEmpty ||
      item.book.isNotEmpty ||
      item.hadithNumber.isNotEmpty;

  List<Widget> _metaRows(AppLocalizations l10n, bool isDark) {
    final color = isDark
        ? AppColors.onSurfaceDarkVariant
        : AppColors.onSurfaceLightVariant;
    final rows = <Widget>[];

    void add(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            '$label: $value',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(color: color),
          ),
        ),
      );
    }

    add(l10n.adhkarReferenceLabel, item.reference);
    add(l10n.adhkarAuthenticityLabel, item.authenticity);
    add(l10n.adhkarNarratorLabel, item.narrator);
    add(l10n.adhkarBookLabel, item.book);
    add(l10n.adhkarHadithNumberLabel, item.hadithNumber);
    return rows;
  }
}
