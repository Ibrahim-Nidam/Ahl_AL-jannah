/// Landscape reading mode: continuous, infinite vertical scroll across
/// the whole Mushaf starting from [initialPage] — no page snapping.
///
/// Ayahs flow as justified RTL runs (same as portrait mushaf), not one
/// verse per line. Pages load lazily near the bottom of the viewport.
/// Surah / Juz / Hizb boundaries get a [QuranReadingSeparator].
library;

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../domain/entities/quran_entities.dart';
import '../cubit/quran_cubit.dart';
import 'quran_ayah_span_builder.dart';
import 'quran_inline_headers.dart';
import 'quran_reading_separator.dart';

typedef QuranPositionChangedCallback = void Function(
  int surahId,
  int juz,
  int page,
  double scrollOffset,
);

class QuranLandscapeReader extends StatefulWidget {
  final int initialPage;
  final double? initialScrollOffset;
  final double fontSize;
  final bool showTajweed;
  final List<SurahEntity> allSurahs;
  final AyahEntity? selectedAyah;
  final Set<String> bookmarkedAyahKeys;
  final void Function(AyahEntity) onAyahTapped;
  final QuranPositionChangedCallback onPositionChanged;
  final String fontFamily;
  final List<String> fontFamilyFallback;

  const QuranLandscapeReader({
    super.key,
    required this.initialPage,
    this.initialScrollOffset,
    required this.fontSize,
    required this.showTajweed,
    required this.allSurahs,
    required this.selectedAyah,
    required this.bookmarkedAyahKeys,
    required this.onAyahTapped,
    required this.onPositionChanged,
    this.fontFamily = 'Lateef',
    this.fontFamilyFallback = const ['Noto Naskh Arabic', 'Scheherazade New', 'Arial'],
  });

  @override
  State<QuranLandscapeReader> createState() => _QuranLandscapeReaderState();
}

class _QuranLandscapeReaderState extends State<QuranLandscapeReader> {
  static const int _maxPage = 604;

  final QuranCubit _cubit = getIt<QuranCubit>();
  final ScrollController _scrollController = ScrollController();
  final List<AyahEntity> _ayahs = [];
  final Map<int, GlobalKey> _pageMarkerKeys = {};
  final Map<int, TapGestureRecognizer> _recognizers = {};

  int _nextPageToLoad = 1;
  bool _isLoadingMore = false;
  bool _initialLoadDone = false;
  bool _reachedEnd = false;

  // Cached item list: rebuilding the Text.rich trees for every loaded ayah
  // on every state change is expensive (each ayah becomes many colored
  // spans when tajweed is on). The cache is invalidated only when the data
  // or styling actually changes, so scroll/position updates reuse the same
  // widget instances and Flutter skips re-layout entirely.
  List<Widget>? _cachedItems;
  String? _itemsSignature;

  @override
  void initState() {
    super.initState();
    _nextPageToLoad = widget.initialPage;
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    for (final r in _recognizers.values) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    await _loadNextPage();
    await _loadNextPage();
    await _loadNextPage();
    if (!mounted) return;
    setState(() => _initialLoadDone = true);

    final offset = widget.initialScrollOffset;
    if (offset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        final max = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(offset.clamp(0, max));
        _handleScrollEnd();
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleScrollEnd();
      });
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || _nextPageToLoad > _maxPage) {
      if (_nextPageToLoad > _maxPage) _reachedEnd = true;
      return;
    }
    _isLoadingMore = true;
    if (mounted) setState(() {});
    final pageNum = _nextPageToLoad;
    try {
      final ayahs = await _cubit.getAyahsByPage(pageNum);
      if (!mounted) return;

      // Append at the bottom only — scroll offset stays put, so the
      // user never jumps when the next page streams in.
      setState(() {
        if (ayahs.isNotEmpty) {
          _pageMarkerKeys.putIfAbsent(pageNum, GlobalKey.new);
          _ayahs.addAll(ayahs);
        }
        _nextPageToLoad = pageNum + 1;
        if (_nextPageToLoad > _maxPage) _reachedEnd = true;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Landscape reader: failed to load page $pageNum: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _reachedEnd) return;
    final position = _scrollController.position;
    if (position.pixels > position.maxScrollExtent - 1200) {
      _loadNextPage();
    }
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

  TapGestureRecognizer _getOrCreateRecognizer(AyahEntity ayah) {
    return _recognizers.putIfAbsent(
      ayah.id,
      () => TapGestureRecognizer()..onTap = () => widget.onAyahTapped(ayah),
    );
  }

  void _handleScrollEnd() {
    if (!_scrollController.hasClients) return;
    final ancestor = context.findRenderObject();
    if (ancestor is! RenderBox || !ancestor.attached) return;

    int? bestPage;
    double bestDistance = double.infinity;

    for (final entry in _pageMarkerKeys.entries) {
      final markerContext = entry.value.currentContext;
      if (markerContext == null) continue;
      final markerBox = markerContext.findRenderObject();
      if (markerBox is! RenderBox || !markerBox.attached) continue;

      final position = markerBox.localToGlobal(Offset.zero, ancestor: ancestor);
      final distance = (position.dy - 80).abs();
      if (position.dy <= 200 && distance < bestDistance) {
        bestDistance = distance;
        bestPage = entry.key;
      }
    }

    bestPage ??= _pageMarkerKeys.keys.isNotEmpty
        ? _pageMarkerKeys.keys.first
        : widget.initialPage;

    final ayahsOnPage = _ayahs.where((a) => a.page == bestPage);
    if (ayahsOnPage.isEmpty) return;
    final first = ayahsOnPage.first;
    widget.onPositionChanged(
      first.surahId,
      first.juz,
      bestPage,
      _scrollController.offset,
    );
  }

  void _flushAyahRun(
    List<Widget> items,
    List<AyahEntity> pending,
    Color quranTextColor,
    Color accent,
  ) {
    if (pending.isEmpty) return;
    final run = List<AyahEntity>.from(pending);
    pending.clear();
    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
        child: Text.rich(
          TextSpan(
            children: QuranAyahSpanBuilder.build(
              ayahs: run,
              fontSize: widget.fontSize,
              quranTextColor: quranTextColor,
              accentColor: accent,
              selectedAyah: widget.selectedAyah,
              bookmarkedAyahKeys: widget.bookmarkedAyahKeys,
              recognizerFor: _getOrCreateRecognizer,
              showTajweed: widget.showTajweed,
              fontFamily: widget.fontFamily,
              fontFamilyFallback: widget.fontFamilyFallback,
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.justify,
          locale: const Locale('ar'),
        ),
      ),
    );
  }

  /// Builds a continuous mushaf-style flow: ayahs share one justified
  /// paragraph until a surah/juz/hizb boundary needs a block separator.
  List<Widget> _buildItems(
    Color quranTextColor,
    Color accent,
    AppLocalizations l10n,
  ) {
    final items = <Widget>[];
    final pending = <AyahEntity>[];
    int? lastSurah;
    int? lastJuz;
    int? lastHizb;
    int? lastPage;

    for (final ayah in _ayahs) {
      final isNewPage = lastPage != ayah.page;
      final isNewSurah = lastSurah != ayah.surahId;
      final isNewJuz = lastJuz != ayah.juz;
      final isNewHizb = lastHizb != ayah.hizb;

      if (isNewPage) {
        // Invisible page marker for position tracking — does not break
        // the visual flow beyond closing the current text run.
        _flushAyahRun(items, pending, quranTextColor, accent);
        items.add(
          SizedBox(
            key: _pageMarkerKeys[ayah.page],
            width: double.infinity,
            height: 0,
          ),
        );
      }

      if (isNewSurah) {
        _flushAyahRun(items, pending, quranTextColor, accent);
        final surah = _getSurahEntity(ayah.surahId);
        items.add(
          QuranReadingSeparator(
            kind: QuranSeparatorKind.surah,
            label: surah.nameEn,
            arabicLabel: surah.nameAr,
          ),
        );
        if (ayah.surahId != 9 && ayah.number == 1) {
          items.add(QuranInlineBismillah(
            color: quranTextColor,
            fontFamily: widget.fontFamily,
            fontFamilyFallback: widget.fontFamilyFallback,
          ));
        }
      } else if (isNewJuz) {
        _flushAyahRun(items, pending, quranTextColor, accent);
        items.add(
          QuranReadingSeparator(
            kind: QuranSeparatorKind.juz,
            label: l10n.quranJuzLabel(ayah.juz),
          ),
        );
      } else if (isNewHizb) {
        _flushAyahRun(items, pending, quranTextColor, accent);
        items.add(
          QuranReadingSeparator(
            kind: QuranSeparatorKind.hizb,
            label: l10n.quranHizbLabel(ayah.hizb),
          ),
        );
      }

      pending.add(ayah);
      lastSurah = ayah.surahId;
      lastJuz = ayah.juz;
      lastHizb = ayah.hizb;
      lastPage = ayah.page;
    }

    _flushAyahRun(items, pending, quranTextColor, accent);

    if (_isLoadingMore) {
      items.add(
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return items;
  }

  /// Returns the item list, reusing the cached one when nothing that
  /// affects the rendered ayahs has changed since the last build.
  List<Widget> _getItems(Color quranTextColor, Color accent, AppLocalizations l10n) {
    final signature = _computeSignature(quranTextColor, accent, l10n);
    if (_itemsSignature == signature && _cachedItems != null) {
      return _cachedItems!;
    }
    final items = _buildItems(quranTextColor, accent, l10n);
    _itemsSignature = signature;
    _cachedItems = items;
    return items;
  }

  String _computeSignature(Color quranTextColor, Color accent, AppLocalizations l10n) {
    final bookmarks = widget.bookmarkedAyahKeys.toList()..sort();
    final bookmarksStr = bookmarks.join(',');
    return [
      _ayahs.length,
      _nextPageToLoad,
      _isLoadingMore,
      widget.fontSize,
      widget.showTajweed,
      widget.selectedAyah?.id ?? -1,
      bookmarksStr,
      widget.allSurahs.length,
      quranTextColor.toARGB32(),
      accent.toARGB32(),
      l10n.localeName,
    ].join('|');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final palette = theme.extension<AppPaletteColors>();
    final quranTextColor = palette?.quranText ?? theme.colorScheme.onSurface;
    final accent = palette?.accent ?? AppColors.accentGold;

    if (!_initialLoadDone) {
      return Center(
        child: CircularProgressIndicator(
          color: palette?.primary ?? AppColors.primaryGreen,
        ),
      );
    }

    final items = _getItems(quranTextColor, accent, l10n);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _handleScrollEnd();
        }
        return false;
      },
      // CustomScrollView keeps scroll physics smoother when slivers grow
      // at the bottom compared to rebuilding a plain ListView of Text.rich.
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => items[index],
                childCount: items.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
