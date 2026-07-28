/// Renders a single Mushaf page (portrait, paginated mode).
///
/// 'mushaf' mode renders the page as continuous, unboxed, justified text
/// — matching a real printed Mushaf, using the page's own ayah grouping
/// from the database (which already mirrors the real 604-page Uthmani
/// pagination) rather than any artificial stretching. 'study' mode keeps
/// the previous per-ayah card layout with translations.
///
/// Ayah text/number styling is delegated entirely to
/// [QuranAyahSpanBuilder] — this widget only owns data loading, gesture
/// recognizer lifecycle, and layout.
library;

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../domain/entities/quran_entities.dart';
import '../cubit/quran_cubit.dart';
import 'quran_ayah_span_builder.dart';
import 'quran_inline_headers.dart';

class QuranMushafPageView extends StatefulWidget {
  final int pageNumber;
  final double fontSize;
  final bool showTranslation;
  final String translationLang;
  final String readerMode; // 'mushaf' | 'study'
  final AyahEntity? selectedAyah;
  final List<SurahEntity> allSurahs;
  final int? targetAyahNumber;
  final Function(AyahEntity) onAyahTapped;
  /// Called with the page that produced the metadata so the parent can
  /// ignore stale callbacks from off-screen / briefly-mounted pages.
  final Function(int surahId, int juz, int hizb, int pageNumber) onPageMetadataLoaded;
  final Set<String> bookmarkedAyahKeys;

  const QuranMushafPageView({
    super.key,
    required this.pageNumber,
    required this.fontSize,
    required this.showTranslation,
    required this.translationLang,
    required this.readerMode,
    required this.selectedAyah,
    required this.allSurahs,
    this.targetAyahNumber,
    required this.onAyahTapped,
    required this.onPageMetadataLoaded,
    required this.bookmarkedAyahKeys,
  });

  @override
  State<QuranMushafPageView> createState() => _QuranMushafPageViewState();
}

class _QuranMushafPageViewState extends State<QuranMushafPageView> {
  final QuranCubit _cubit = getIt<QuranCubit>();
  List<AyahEntity> _ayahs = [];
  bool _isLoading = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _ayahKeys = {};
  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    debugPrint('[MushafPage ${widget.pageNumber}] initState');
    _loadPageData();
  }

  @override
  void didUpdateWidget(covariant QuranMushafPageView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageNumber != widget.pageNumber) {
      _loadPageData();
    }
  }

  @override
  void dispose() {
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPageData() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      debugPrint('[MushafPage ${widget.pageNumber}] fetching ayahs...');
      final loaded = await _cubit.getAyahsByPage(widget.pageNumber);
      debugPrint('[MushafPage ${widget.pageNumber}] got ${loaded.length} ayahs');
      if (!mounted) return;

      for (final r in _recognizers.values) {
        r.dispose();
      }
      _recognizers.clear();
      _ayahKeys.clear();
      for (final ayah in loaded) {
        _ayahKeys[ayah.number] = GlobalKey();
      }

      setState(() {
        _ayahs = loaded;
        _isLoading = false;
      });
      debugPrint('[MushafPage ${widget.pageNumber}] state updated: _ayahs.length=${_ayahs.length} isLoading=false');

      if (loaded.isNotEmpty) {
        widget.onPageMetadataLoaded(
          loaded.first.surahId,
          loaded.first.juz,
          loaded.first.hizb,
          widget.pageNumber,
        );
      }

      if (widget.targetAyahNumber != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToAyah(widget.targetAyahNumber!),
        );
      }
    } catch (e, st) {
      debugPrint('[MushafPage ${widget.pageNumber}] FAILED: $e\n$st');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToAyah(int ayahNumber) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final key = _ayahKeys[ayahNumber];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  SurahEntity _getSurahEntity(int surahId) {
    final l10n = AppLocalizations.of(context);
    return widget.allSurahs.firstWhere(
      (s) => s.id == surahId,
      orElse: () => SurahEntity(
        id: surahId,
        nameAr: '',
        nameEn: l10n.quranSurahFallback(surahId),
        revelation: '',
        ayahCount: 0,
      ),
    );
  }

  List<List<AyahEntity>> _groupBySurah(List<AyahEntity> ayahs) {
    final groups = <List<AyahEntity>>[];
    if (ayahs.isEmpty) return groups;
    var current = [ayahs.first];
    for (var i = 1; i < ayahs.length; i++) {
      if (ayahs[i].surahId == ayahs[i - 1].surahId) {
        current.add(ayahs[i]);
      } else {
        groups.add(current);
        current = [ayahs[i]];
      }
    }
    groups.add(current);
    return groups;
  }

  TapGestureRecognizer _getOrCreateRecognizer(AyahEntity ayah) {
    return _recognizers.putIfAbsent(
      ayah.id,
      () => TapGestureRecognizer()..onTap = () => widget.onAyahTapped(ayah),
    );
  }

  Widget _buildMushafFlow(Color quranTextColor, Color accent) {
    final groups = _groupBySurah(_ayahs);
    debugPrint('[MushafPage ${widget.pageNumber}] _buildMushafFlow: ${groups.length} surah groups, quranTextColor=$quranTextColor');
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final group in groups) ...[
            if (group.first.number == 1) ...[
              QuranInlineSurahHeader(
                surah: _getSurahEntity(group.first.surahId),
                accent: accent,
              ),
              if (group.first.surahId != 9)
                QuranInlineBismillah(color: quranTextColor),
            ],
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text.rich(
                TextSpan(
                  children: QuranAyahSpanBuilder.build(
                    ayahs: group,
                    fontSize: widget.fontSize,
                    quranTextColor: quranTextColor,
                    accentColor: accent,
                    selectedAyah: widget.selectedAyah,
                    bookmarkedAyahKeys: widget.bookmarkedAyahKeys,
                    recognizerFor: _getOrCreateRecognizer,
                  ),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.justify,
                locale: const Locale('ar'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStudyView(bool isDark, Color quranTextColor, Color accent) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _ayahs.length,
      itemBuilder: (context, index) {
        final l10n = AppLocalizations.of(context);
        final ayah = _ayahs[index];
        final isSelected = widget.selectedAyah?.id == ayah.id;
        final isBookmarked =
            widget.bookmarkedAyahKeys.contains('${ayah.surahId}-${ayah.number}');
        final key = _ayahKeys[ayah.number];
        final translationText = widget.translationLang == 'fr'
            ? ayah.translationFr
            : ayah.translationEn;
        final surahName = _getSurahEntity(ayah.surahId).nameEn;

        return GestureDetector(
          onTap: () => widget.onAyahTapped(ayah),
          child: Container(
            key: key,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? accent
                    : (isDark
                        ? AppColors.dividerDark.withAlpha(50)
                        : AppColors.divider.withAlpha(100)),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$surahName • ${l10n.quranJuzLabel(ayah.juz)} • ${l10n.quranHizbLabel(ayah.hizb)} • ${l10n.quranPageLabel(ayah.page)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.onSurfaceDarkVariant
                                : AppColors.onSurfaceLightVariant,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isBookmarked) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.bookmark_rounded, color: accent, size: 16),
                        ],
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryGreen : accent,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${ayah.number}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text.rich(
                  TextSpan(
                    children: QuranAyahSpanBuilder.build(
                      ayahs: [ayah],
                      fontSize: widget.fontSize,
                      quranTextColor: quranTextColor,
                      accentColor: accent,
                      selectedAyah: widget.selectedAyah,
                      bookmarkedAyahKeys: widget.bookmarkedAyahKeys,
                      recognizerFor: _getOrCreateRecognizer,
                    ),
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  locale: const Locale('ar'),
                ),
                if (widget.showTranslation && translationText != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    translationText,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceDarkVariant
                          : AppColors.onSurfaceLightVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context);
    final palette = Theme.of(context).extension<AppPaletteColors>();
    final quranTextColor =
        palette?.quranText ?? (isDark ? AppColors.onSurfaceDark : Colors.black);
    final accent = palette?.accent ?? AppColors.accentGold;

    debugPrint(
      '[MushafPage ${widget.pageNumber}] build: isLoading=$_isLoading error=$_error ayahs=${_ayahs.length} palette=${palette != null}',
    );

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: palette?.primary ?? AppColors.primaryGreen),
      );
    }
    if (_error != null) {
      return Center(child: Text(l10n.commonError(_error!)));
    }
    if (_ayahs.isEmpty) {
      debugPrint('[MushafPage ${widget.pageNumber}] WARNING: no ayahs, showing empty message');
      return Center(child: Text(l10n.quranNoVersesOnPage));
    }

    return widget.readerMode == 'study'
        ? _buildStudyView(isDark, quranTextColor, accent)
        : _buildMushafFlow(quranTextColor, accent);
  }
}