import 'dart:async';
import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_palettes.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/services/quran_bookmark_storage.dart';
import '../../domain/entities/quran_bookmark.dart';
import '../../domain/entities/quran_entities.dart';
import '../cubit/quran_cubit.dart';
import '../widgets/quran_ayah_span_builder.dart';
import '../widgets/quran_landscape_reader.dart';
import '../widgets/quran_mushaf_page_view.dart';

class QuranReaderPage extends StatefulWidget {
  final int? surahId;
  final int? juzId;
  final String title;
  final int? initialAyahId;
  final int? page;

  const QuranReaderPage({
    super.key,
    this.surahId,
    this.juzId,
    required this.title,
    this.initialAyahId,
    this.page,
  });

  @override
  State<QuranReaderPage> createState() => _QuranReaderPageState();
}

class _QuranReaderPageState extends State<QuranReaderPage>
    with WidgetsBindingObserver {
  late final QuranCubit _cubit;
  final QuranBookmarkStorage _bookmarkStorage = QuranBookmarkStorage();

  bool _isLoading = true;
  String? _errorMessage;

  final ValueNotifier<bool> _chromeVisible = ValueNotifier<bool>(true);

  PageController? _pageController;
  int _currentPageNumber = 1;
  int? _activeSurahId;
  int? _activeJuz;
  int? _activeHizb;
  double? _resumeScrollOffset;
  double? _lastKnownScrollOffset;

  // Portrait remount generation — bumped whenever we recreate the
  // PageController so PageView gets a fresh identity with the correct
  // initialPage.
  int _portraitGeneration = 0;
  int _landscapeGeneration = 0;

  // Spurious onPageChanged(0) during attach must not overwrite reading
  // progress or metadata. Only persist once the portrait pager has
  // settled on [_currentPageNumber].
  bool _portraitSettled = false;
  bool _canPersistPosition = false;
  bool _orientationsUnlocked = false;
  Size _lastMediaSize = Size.zero;
  Orientation? _lastOrientation;

  List<SurahEntity> _allSurahs = [];
  AyahEntity? _selectedAyah;
  List<QuranBookmark> _bookmarks = [];

  double _fontSize = 28.0;
  bool _showTranslation = true;
  String _translationLang = 'en';
  String _readerMode = 'mushaf';

  late final SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    debugPrint('[QuranReader] initState: surahId=${widget.surahId} juzId=${widget.juzId} page=${widget.page}');
    WidgetsBinding.instance.addObserver(this);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(AppConstants.keyWasInsideQuranReader, true);
    });
    _enableWakelock();
    _cubit = getIt<QuranCubit>();
    _loadSettingsAndData();
  }

  @override
  void didChangeMetrics() {
    // Recover when the engine reports a real size after a 0x0 cold-start frame.
    if (!mounted || _isLoading) return;
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return;
    final view = views.first;
    final logical = view.physicalSize / view.devicePixelRatio;
    debugPrint('[QuranReader] didChangeMetrics logical=${logical.width}x${logical.height}');
    if (logical.width >= 1 && logical.height >= 1) {
      setState(() {});
    }
  }

  void _ensureOrientationsUnlocked() {
    if (_orientationsUnlocked) return;
    _orientationsUnlocked = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[QuranReader] WakelockPlus.enable failed (non-fatal): $e');
    }
  }

  Future<void> _disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('[QuranReader] WakelockPlus.disable failed (non-fatal): $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(AppConstants.keyWasInsideQuranReader, false);
    });
    if (_canPersistPosition) {
      unawaited(_saveLastPosition());
    }
    _pageController?.dispose();
    _chromeVisible.dispose();
    _disableWakelock();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _loadSettingsAndData() async {
    debugPrint('[QuranReader] _loadSettingsAndData: start');
    try {
      _prefs = await SharedPreferences.getInstance();

      setState(() {
        _fontSize = _prefs.getDouble('quran_arabic_font_size') ?? 28.0;
        _showTranslation = _prefs.getBool('quran_show_translation') ?? true;
        _translationLang = _prefs.getString('quran_translation_lang') ?? 'en';
        _readerMode = _prefs.getString(AppConstants.keyQuranReaderMode) ?? 'mushaf';
      });

      final cubitState = _cubit.state;
      if (cubitState is QuranLoadSuccess) {
        _allSurahs = cubitState.surahs;
        debugPrint('[QuranReader] surahs already loaded: ${_allSurahs.length}');
      } else {
        debugPrint('[QuranReader] loading surahs...');
        await _cubit.loadSurahs();
        final latest = _cubit.state;
        if (latest is QuranLoadSuccess) {
          _allSurahs = latest.surahs;
          debugPrint('[QuranReader] surahs loaded: ${_allSurahs.length}');
        } else {
          debugPrint('[QuranReader] WARNING: surahs failed to load, state=$latest');
        }
      }

      int initialPageNum = 1;
      final lastPosition = await _bookmarkStorage.getLastPosition();

      if (widget.page != null) {
        initialPageNum = widget.page!;
        if (lastPosition != null &&
            lastPosition.page == widget.page &&
            lastPosition.ayahNumber == widget.initialAyahId) {
          _resumeScrollOffset = lastPosition.scrollOffset;
          if (lastPosition.readingMode != null) {
            _readerMode = lastPosition.readingMode!;
          }
        }
      } else if (widget.surahId != null) {
        debugPrint('[QuranReader] fetching ayahs for surah ${widget.surahId}');
        final ayahs = await _cubit.getAyahsBySurah(widget.surahId!);
        debugPrint('[QuranReader] got ${ayahs.length} ayahs for surah ${widget.surahId}');
        if (ayahs.isNotEmpty) {
          if (widget.initialAyahId != null) {
            final target = ayahs.firstWhere(
              (a) => a.number == widget.initialAyahId,
              orElse: () => ayahs.first,
            );
            initialPageNum = target.page;
            _selectedAyah = target;
          } else {
            initialPageNum = ayahs.first.page;
          }
        } else {
          debugPrint('[QuranReader] WARNING: no ayahs returned for surah ${widget.surahId} — check the Quran database.');
        }
      } else if (widget.juzId != null) {
        final ayahs = await _cubit.getAyahsByJuz(widget.juzId!);
        if (ayahs.isNotEmpty) initialPageNum = ayahs.first.page;
      } else if (lastPosition != null) {
        initialPageNum = lastPosition.page;
        _resumeScrollOffset = lastPosition.scrollOffset;
        if (lastPosition.readingMode != null) {
          _readerMode = lastPosition.readingMode!;
        }
      }

      debugPrint('[QuranReader] resolved initialPageNum=$initialPageNum');
      _currentPageNumber = initialPageNum;
      // Prefer the route's surah until the visible page reports metadata.
      _activeSurahId = widget.surahId;
      _portraitSettled = false;
      _canPersistPosition = false;
      _pageController = PageController(initialPage: initialPageNum - 1);
      debugPrint('[QuranReader] constructed PageController with initialPage=${_pageController!.initialPage}');

      await _loadBookmarks();

      setState(() => _isLoading = false);
      debugPrint('[QuranReader] _loadSettingsAndData: done, isLoading=false');
      _schedulePortraitSettle();
    } catch (e, st) {
      debugPrint('[QuranReader] _loadSettingsAndData FAILED: $e\n$st');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLastPosition() async {
    if (!_canPersistPosition) {
      debugPrint('[QuranReader] skip save: portrait/landscape position not settled yet');
      return;
    }
    // Prefer metadata from the *current* page; fall back to the opened surah.
    final surahId = _activeSurahId ?? widget.surahId;
    if (surahId == null) return;
    final surah = _getSurahEntity(surahId);
    try {
      await _bookmarkStorage.saveLastPosition(
        surahId: surahId,
        surahName: surah.nameEn,
        page: _currentPageNumber,
        ayahNumber: _selectedAyah?.number,
        previewText: surah.nameEn,
        readingMode: _readerMode,
        scrollOffset: _lastKnownScrollOffset,
      );
      debugPrint('[QuranReader] saved last position: surah=$surahId page=$_currentPageNumber');
    } catch (e) {
      debugPrint('[QuranReader] Failed to save last reading position: $e');
    }
  }

  void _onPageMetadataLoaded(int surahId, int juz, int hizb, int pageNumber) {
    // Ignore metadata from pages that briefly mounted during a pager race
    // (e.g. page 1 of Al-Fatiha while we intended another surah).
    if (pageNumber != _currentPageNumber) {
      debugPrint(
        '[QuranReader] ignore metadata for page $pageNumber '
        '(current=$_currentPageNumber)',
      );
      return;
    }
    if (_activeSurahId != surahId || _activeJuz != juz || _activeHizb != hizb) {
      setState(() {
        _activeSurahId = surahId;
        _activeJuz = juz;
        _activeHizb = hizb;
      });
      // Re-save position with the correct surah metadata after page change
      // — _onPortraitPageChanged saves immediately but the surah metadata
      // arrives asynchronously, so the intermediate save can have stale surah info.
      unawaited(_saveLastPosition());
    }
  }

  void _onAyahTapped(AyahEntity ayah) {
    setState(() {
      if (_selectedAyah?.id == ayah.id) {
        _selectedAyah = null;
      } else {
        _selectedAyah = ayah;
      }
    });
  }

  SurahEntity _getSurahEntity(int surahId) {
    final l10n = AppLocalizations.of(context);
    return _allSurahs.firstWhere(
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

  String _getCurrentTitle() {
    if (_activeSurahId == null) return widget.title;
    return _getSurahEntity(_activeSurahId!).nameEn;
  }

  Future<void> _loadBookmarks() async {
    try {
      final bookmarks = await _bookmarkStorage.loadBookmarks();
      if (mounted) setState(() => _bookmarks = bookmarks);
    } catch (e) {
      debugPrint('Error loading bookmarks: $e');
    }
  }

  bool get _isCurrentPageBookmarked {
    return _bookmarks.any((b) => b.isPageBookmark && b.page == _currentPageNumber);
  }

  QuranBookmark? get _currentPageBookmark {
    try {
      return _bookmarks.firstWhere((b) => b.isPageBookmark && b.page == _currentPageNumber);
    } catch (_) {
      return null;
    }
  }

  bool _isAyahBookmarked(int surahId, int ayahNumber) {
    return _bookmarks.any(
      (b) => b.isAyahBookmark && b.surahId == surahId && b.ayahNumber == ayahNumber,
    );
  }

  QuranBookmark? _getAyahBookmark(int surahId, int ayahNumber) {
    try {
      return _bookmarks.firstWhere(
        (b) => b.isAyahBookmark && b.surahId == surahId && b.ayahNumber == ayahNumber,
      );
    } catch (_) {
      return null;
    }
  }

  Set<String> get _bookmarkedAyahKeys {
    return _bookmarks
        .where((b) => b.isAyahBookmark)
        .map((b) => '${b.surahId}-${b.ayahNumber}')
        .toSet();
  }

  Future<void> _togglePageBookmark() async {
    final pageNum = _currentPageNumber;
    final existing = _currentPageBookmark;
    if (existing != null) {
      try {
        await _bookmarkStorage.removeBookmark(existing.id);
        await _loadBookmarks();
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.quranPageRemovedBookmark(pageNum)), behavior: SnackBarBehavior.floating),
        );
      } catch (e) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranFailedRemoveBookmark('$e'))));
      }
    } else {
      try {
        final verses = await _cubit.getAyahsByPage(pageNum);
        if (verses.isNotEmpty) {
          final first = verses.first;
          final surah = _getSurahEntity(first.surahId);
          await _bookmarkStorage.addPageBookmark(
            surahId: first.surahId,
            surahName: surah.nameEn,
            page: pageNum,
            ayahNumber: first.number,
            previewText: QuranAyahSpanBuilder.formatAyahText(first.surahId, first.number, first.textAr),
            readingMode: _readerMode,
          );
          await _loadBookmarks();
          if (!mounted) return;
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.quranPageBookmarked(pageNum)), behavior: SnackBarBehavior.floating),
          );
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranFailedBookmarkPage('$e'))));
        }
      }
    }
  }

  Future<void> _toggleSelectedAyahBookmark() async {
    final ayah = _selectedAyah;
    if (ayah == null) return;

    final existing = _getAyahBookmark(ayah.surahId, ayah.number);
    if (existing != null) {
      try {
        await _bookmarkStorage.removeBookmark(existing.id);
        await _loadBookmarks();
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.quranVerseRemovedBookmark(ayah.surahId, ayah.number)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _selectedAyah = null);
      } catch (e) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranFailedRemoveBookmark('$e'))));
      }
    } else {
      try {
        final surah = _getSurahEntity(ayah.surahId);
        await _bookmarkStorage.addAyahBookmark(
          surahId: ayah.surahId,
          surahName: surah.nameEn,
          page: ayah.page,
          ayahNumber: ayah.number,
          previewText: QuranAyahSpanBuilder.formatAyahText(ayah.surahId, ayah.number, ayah.textAr),
          readingMode: _readerMode,
        );
        await _loadBookmarks();
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.quranVerseBookmarked(ayah.surahId, ayah.number)),
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _selectedAyah = null);
      } catch (e) {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranFailedBookmarkVerse('$e'))));
      }
    }
  }

  void _copySelectedAyah() {
    final ayah = _selectedAyah;
    if (ayah == null) return;
    final l10n = AppLocalizations.of(context);
    final surah = _getSurahEntity(ayah.surahId);
    final translationText = _translationLang == 'fr' ? ayah.translationFr : ayah.translationEn;
    final textToCopy = '${surah.nameEn} ${ayah.surahId}:${ayah.number}\n\n'
        '${ayah.textAr}\n\n${translationText ?? ""}';
    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.quranVerseCopied)));
    setState(() => _selectedAyah = null);
  }

  void _shareSelectedAyah() {
    final ayah = _selectedAyah;
    if (ayah == null) return;
    final l10n = AppLocalizations.of(context);
    final surah = _getSurahEntity(ayah.surahId);
    final translationText = _translationLang == 'fr' ? ayah.translationFr : ayah.translationEn;
    final shareText = '✨ *${l10n.quranShareQuoteTitle}* ✨\n\n'
        '📖 *${surah.nameEn}* (${ayah.surahId}:${ayah.number})\n\n'
        '« ${ayah.textAr} »\n\n${translationText ?? ""}\n\n${l10n.quranShareViaApp}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.quranVerseShareReady)),
    );
    setState(() => _selectedAyah = null);
  }

  Future<void> _saveFontSize(double size) async {
    setState(() => _fontSize = size);
    await _prefs.setDouble('quran_arabic_font_size', size);
  }

  Future<void> _saveShowTranslation(bool value) async {
    setState(() => _showTranslation = value);
    await _prefs.setBool('quran_show_translation', value);
  }

  Future<void> _saveTranslationLang(String lang) async {
    setState(() => _translationLang = lang);
    await _prefs.setString('quran_translation_lang', lang);
  }

  Future<void> _saveReaderMode(String mode) async {
    setState(() => _readerMode = mode);
    await _prefs.setString(AppConstants.keyQuranReaderMode, mode);
  }

  void _showSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.isDarkMode ? AppColors.surfaceDarkVariant : AppColors.surfaceLightVariant,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.quranSettingsAppearance,
                    style: AppTextStyles.headingMedium.copyWith(
                      color: context.isDarkMode ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.quranReadingMode,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.isDarkMode ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'mushaf', label: Text(l10n.quranModeMushaf)),
                      ButtonSegment(value: 'study', label: Text(l10n.quranModeStudy)),
                    ],
                    selected: {_readerMode},
                    onSelectionChanged: (selection) {
                      setModalState(() {});
                      _saveReaderMode(selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    l10n.quranArabicFontSize(_fontSize.round()),
                    style: AppTextStyles.headingSmall.copyWith(
                      color: context.isDarkMode ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                    ),
                  ),
                  Slider(
                    value: _fontSize,
                    min: 20.0,
                    max: 45.0,
                    divisions: 25,
                    activeColor: AppColors.primaryGreen,
                    inactiveColor: AppColors.primaryGreen.withAlpha(50),
                    onChanged: (val) {
                      setModalState(() {});
                      _saveFontSize(val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text(
                      l10n.quranShowTranslations,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: context.isDarkMode ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                    ),
                    value: _showTranslation,
                    activeThumbColor: AppColors.primaryGreen,
                    onChanged: (val) {
                      setModalState(() {});
                      _saveShowTranslation(val);
                    },
                  ),
                  if (_showTranslation) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.quranTranslationLanguage,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: context.isDarkMode
                                  ? AppColors.onSurfaceDarkVariant
                                  : AppColors.onSurfaceLightVariant,
                            ),
                          ),
                          SegmentedButton<String>(
                            segments: [
                              ButtonSegment(value: 'en', label: Text(l10n.quranLangEnglish)),
                              ButtonSegment(value: 'fr', label: Text(l10n.quranLangFrench)),
                            ],
                            selected: {_translationLang},
                            onSelectionChanged: (Set<String> newSelection) {
                              setModalState(() {});
                              _saveTranslationLang(newSelection.first);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionOverlay(bool isDark) {
    final ayah = _selectedAyah;
    if (ayah == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final surah = _getSurahEntity(ayah.surahId);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDarkVariant.withAlpha(240) : Colors.white.withAlpha(240),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.accentGold.withAlpha(150), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 15, offset: const Offset(0, 5))],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.nameEn,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                  ),
                  Text(
                    l10n.quranVerseLabel(ayah.surahId, ayah.number),
                    style: AppTextStyles.bodySmall.copyWith(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _isAyahBookmarked(ayah.surahId, ayah.number) ? Icons.bookmark_rounded : Icons.bookmark_add_outlined,
                    color: AppColors.primaryGreen,
                  ),
                  tooltip: _isAyahBookmarked(ayah.surahId, ayah.number)
                      ? l10n.quranUnmarkVerse
                      : l10n.quranBookmarkVerse,
                  onPressed: _toggleSelectedAyahBookmark,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primaryGreen),
                  tooltip: l10n.commonCopy,
                  onPressed: _copySelectedAyah,
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.primaryGreen),
                  tooltip: l10n.commonShare,
                  onPressed: _shareSelectedAyah,
                ),
                const SizedBox(width: 8),
                Container(width: 1.5, height: 30, color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.error),
                  tooltip: l10n.quranClearSelection,
                  onPressed: () => setState(() => _selectedAyah = null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark, Color surfaceColor) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: surfaceColor,
      elevation: 1,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => context.pop(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getCurrentTitle(),
                      style: AppTextStyles.arabicHeading(fontSize: 18).copyWith(
                        color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_activeJuz != null)
                      Text(
                        _activeHizb != null
                            ? '${l10n.quranJuzLabel(_activeJuz!)} • ${l10n.quranHizbLabel(_activeHizb!)} • ${l10n.quranPageLabel(_currentPageNumber)}'
                            : l10n.quranJuzPageSubtitle(_activeJuz!, _currentPageNumber),
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.accentGoldDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  _isCurrentPageBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: _isCurrentPageBookmarked ? AppColors.accentGold : null,
                ),
                tooltip: _isCurrentPageBookmarked ? l10n.quranUnmarkPage : l10n.quranBookmarkPage,
                onPressed: _togglePageBookmark,
              ),
              IconButton(
                icon: const Icon(Icons.bookmarks_rounded),
                tooltip: l10n.quranManageBookmarks,
                onPressed: () => context.pushNamed('quran_bookmarks').then((_) => _loadBookmarks()),
              ),
              IconButton(
                icon: const Icon(Icons.text_fields_rounded),
                onPressed: _showSettingsBottomSheet,
                tooltip: l10n.quranSettingsTooltip,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// After the portrait PageView attaches, confirm it shows
  /// [_currentPageNumber], then allow position persistence.
  ///
  /// Never treat [PageController.initialPage] as proof of position —
  /// with a reverse/RTL pager the controller can report the intended
  /// initial page while the viewport is still on index 0 (blank screen).
  void _schedulePortraitSettle({int retriesLeft = 24}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isLoading) return;
      final controller = _pageController;
      if (controller == null) return;

      if (!controller.hasClients) {
        if (retriesLeft > 0) {
          Future.delayed(const Duration(milliseconds: 32), () {
            if (mounted) _schedulePortraitSettle(retriesLeft: retriesLeft - 1);
          });
        } else {
          debugPrint('[QuranReader] portrait settle gave up waiting for clients');
        }
        return;
      }

      // A 0-wide viewport can still report initialPage — that caused false
      // "settled" logs while MushafPage 1 was the only child built.
      final viewport = controller.position.viewportDimension;
      if (viewport < 1) {
        debugPrint(
          '[QuranReader] portrait settle: viewport=$viewport, waiting…',
        );
        if (retriesLeft > 0) {
          Future.delayed(const Duration(milliseconds: 32), () {
            if (mounted) _schedulePortraitSettle(retriesLeft: retriesLeft - 1);
          });
        }
        return;
      }

      final targetIndex = (_currentPageNumber - 1).clamp(0, 603);
      final page = controller.page;
      if (page == null) {
        debugPrint('[QuranReader] portrait settle: page is null, jumping to $targetIndex');
        controller.jumpToPage(targetIndex);
        if (retriesLeft > 0) {
          Future.delayed(const Duration(milliseconds: 32), () {
            if (mounted) _schedulePortraitSettle(retriesLeft: retriesLeft - 1);
          });
        }
        return;
      }

      final reported = page.round();
      if (reported != targetIndex) {
        debugPrint(
          '[QuranReader] portrait settle: correcting $reported → $targetIndex',
        );
        controller.jumpToPage(targetIndex);
        if (retriesLeft > 0) {
          Future.delayed(const Duration(milliseconds: 32), () {
            if (mounted) _schedulePortraitSettle(retriesLeft: retriesLeft - 1);
          });
        }
        return;
      }

      if (!_portraitSettled || !_canPersistPosition) {
        setState(() {
          _portraitSettled = true;
          _canPersistPosition = true;
        });
        debugPrint(
          '[QuranReader] portrait settled on page $_currentPageNumber '
          '(controller.page=$page)',
        );
        unawaited(_saveLastPosition());
      }
    });
  }

  void _onPortraitPageChanged(int index) {
    final pageNum = index + 1;
    // Ignore attach-time notifications that would reset progress to page 1.
    if (!_portraitSettled) {
      debugPrint(
        '[QuranReader] ignore onPageChanged($index) before settle '
        '(want page $_currentPageNumber)',
      );
      return;
    }

    setState(() {
      _currentPageNumber = pageNum;
      _selectedAyah = null;
      _lastKnownScrollOffset = null;
    });
    _canPersistPosition = true;
    unawaited(_saveLastPosition());
  }

  Widget _buildPortrait() {
    // Use ambient RTL Directionality for mushaf page-turn direction
    // instead of PageView.reverse. `reverse: true` breaks initialPage /
    // jumpToPage on many devices (viewport stays on page 1 → blank).
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        key: ValueKey('quran_portrait_$_portraitGeneration'),
        controller: _pageController,
        itemCount: 604,
        onPageChanged: _onPortraitPageChanged,
        itemBuilder: (context, index) {
          final pageNum = index + 1;
          return QuranMushafPageView(
            key: ValueKey('quran_page_$pageNum'),
            pageNumber: pageNum,
            fontSize: _fontSize,
            showTranslation: _showTranslation,
            translationLang: _translationLang,
            readerMode: _readerMode,
            selectedAyah: _selectedAyah,
            allSurahs: _allSurahs,
            bookmarkedAyahKeys: _bookmarkedAyahKeys,
            targetAyahNumber:
                (pageNum == widget.page || pageNum == _selectedAyah?.page)
                    ? widget.initialAyahId
                    : null,
            onAyahTapped: _onAyahTapped,
            onPageMetadataLoaded: _onPageMetadataLoaded,
          );
        },
      ),
    );
  }

  Widget _buildLandscape() {
    return QuranLandscapeReader(
      // Key must NOT include page — onPositionChanged updates page and
      // would remount the reader (jump to top) on every scroll settle.
      key: ValueKey('quran_landscape_$_landscapeGeneration'),
      initialPage: _currentPageNumber,
      initialScrollOffset: _resumeScrollOffset,
      fontSize: _fontSize,
      allSurahs: _allSurahs,
      selectedAyah: _selectedAyah,
      bookmarkedAyahKeys: _bookmarkedAyahKeys,
      onAyahTapped: _onAyahTapped,
      onPositionChanged: (surahId, juz, page, offset) {
        // Avoid setState when nothing meaningful changed — reduces rebuild jank
        // while scrolling landscape.
        final pageChanged = page != _currentPageNumber;
        final surahChanged = surahId != _activeSurahId || juz != _activeJuz;
        _lastKnownScrollOffset = offset;
        _canPersistPosition = true;
        if (pageChanged || surahChanged) {
          setState(() {
            _activeSurahId = surahId;
            _activeJuz = juz;
            _currentPageNumber = page;
          });
        } else {
          _activeSurahId = surahId;
          _activeJuz = juz;
          _currentPageNumber = page;
        }
        unawaited(_saveLastPosition());
      },
    );
  }

  /// Remounts the portrait pager at [_currentPageNumber]. Used when the
  /// window size recovers from 0x0 (cold start) or when returning from landscape.
  void _remountPortraitPager() {
    final old = _pageController;
    final targetIndex = (_currentPageNumber - 1).clamp(0, 603);
    _pageController = PageController(initialPage: targetIndex);
    _portraitGeneration++;
    _portraitSettled = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      old?.dispose();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _schedulePortraitSettle();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final palette = Theme.of(context).extension<AppPaletteColors>();
    final surfaceColor = palette?.surface ?? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight);
    final mediaSize = MediaQuery.sizeOf(context);

    debugPrint(
      '[QuranReader] build: isLoading=$_isLoading errorMessage=$_errorMessage '
      'media=${mediaSize.width.toStringAsFixed(0)}x${mediaSize.height.toStringAsFixed(0)}',
    );

    return Scaffold(
      backgroundColor: surfaceColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: palette?.primary ?? AppColors.primaryGreen),
            )
          : _errorMessage != null
              ? Center(child: Text(AppLocalizations.of(context).commonError(_errorMessage!)))
              : _buildReaderBody(mediaSize, isDark, surfaceColor),
    );
  }

  Widget _buildReaderBody(
    Size mediaSize,
    bool isDark,
    Color surfaceColor,
  ) {
    // Prefer MediaQuery over LayoutBuilder — LayoutBuilder was reporting 0x0
    // after cold start even though the shell had a real size.
    final width = mediaSize.width;
    final height = mediaSize.height;

    if (width < 1 || height < 1) {
      debugPrint('[QuranReader] waiting for non-zero MediaQuery size');
      // So the next non-zero frame is treated as a recovery remount.
      _lastMediaSize = Size.zero;
      _portraitSettled = false;
      return const Center(child: CircularProgressIndicator());
    }

    // Safe to unlock rotation only once we have a real viewport.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ensureOrientationsUnlocked();
    });

    final isLandscape = width > height;
    final orientation =
        isLandscape ? Orientation.landscape : Orientation.portrait;
    final previous = _lastOrientation;
    final sizeRecovered =
        _lastMediaSize.width < 1 && width >= 1 && height >= 1;

    debugPrint(
      '[QuranReader] reader body ${width.toStringAsFixed(0)}x${height.toStringAsFixed(0)} '
      '→ $orientation (was $previous, sizeRecovered=$sizeRecovered)',
    );

    // Cold-start recovery: viewport was 0, now real — remount pager.
    if (sizeRecovered ||
        (previous == Orientation.landscape &&
            orientation == Orientation.portrait)) {
      _remountPortraitPager();
    }

    if (orientation == Orientation.landscape &&
        previous != Orientation.landscape) {
      _landscapeGeneration++;
      _resumeScrollOffset = _lastKnownScrollOffset;
      _canPersistPosition = true;
    }

    _lastOrientation = orientation;
    _lastMediaSize = mediaSize;

    // Chrome sits above the mushaf (inset), never overlays the text.
    return Column(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _chromeVisible,
          builder: (context, visible, _) {
            return ClipRect(
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                heightFactor: visible ? 1.0 : 0.0,
                child: _buildTopBar(isDark, surfaceColor),
              ),
            );
          },
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_selectedAyah != null) {
                      setState(() => _selectedAyah = null);
                    } else {
                      _chromeVisible.value = !_chromeVisible.value;
                    }
                  },
                  child: isLandscape ? _buildLandscape() : _buildPortrait(),
                ),
              ),
              if (_selectedAyah != null) _buildSelectionOverlay(isDark),
            ],
          ),
        ),
      ],
    );
  }
}