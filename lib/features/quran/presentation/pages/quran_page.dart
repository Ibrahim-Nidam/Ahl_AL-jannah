import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/clear_text_suffix.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../data/services/quran_bookmark_storage.dart';
import '../../domain/entities/quran_bookmark.dart';
import '../../domain/entities/quran_entities.dart';
import '../cubit/quran_cubit.dart';
import '../widgets/quran_ayah_span_builder.dart';
import '../widgets/quran_inline_headers.dart';

class QuranPage extends StatefulWidget {
  const QuranPage({super.key});

  @override
  State<QuranPage> createState() => _QuranPageState();
}

class _QuranPageState extends State<QuranPage>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin<QuranPage> {
  late final QuranCubit _cubit;
  late final TabController _tabController;
  final TextEditingController _surahFilterController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _surahFilterQuery = '';

  final QuranBookmarkStorage _bookmarkStorage = QuranBookmarkStorage();
  Future<QuranBookmark?>? _lastPositionFuture;
  bool _autoResumed = false;

  /// Warsh per-surah ayah counts (loaded lazily when the Warsh riwaya is
  /// active; counts differ from Hafs in 51 surahs).
  Map<int, int> _warshAyahCounts = const {};
  QuranRiwaya? _lastCountsRiwaya;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<QuranCubit>();
    _cubit.loadSurahs();
    _tabController = TabController(length: 3, vsync: this);
    _surahFilterController.addListener(() {
      setState(() {
        _surahFilterQuery = _surahFilterController.text.toLowerCase();
      });
    });
    _syncSurahCountsForRiwaya();
    _refreshLastPosition(autoResume: true);
  }

  /// Loads (or clears) the Warsh surah counts to match the active riwaya.
  /// No-op when the riwaya hasn't changed since the last sync, so it is
  /// safe to call from a settings listener on every settings update.
  Future<void> _syncSurahCountsForRiwaya() async {
    final settingsState = getIt<SettingsCubit>().state;
    final riwaya = settingsState is SettingsLoadSuccess
        ? settingsState.settings.quranRiwaya
        : QuranRiwaya.hafsAnAsim;
    if (riwaya == _lastCountsRiwaya) return;
    _lastCountsRiwaya = riwaya;

    if (riwaya == QuranRiwaya.warsh) {
      try {
        final counts = await _cubit.getWarshSurahAyahCounts();
        if (mounted) setState(() => _warshAyahCounts = counts);
      } catch (e) {
        debugPrint('[QuranPage] failed to load Warsh surah counts: $e');
        if (mounted) setState(() => _warshAyahCounts = const {});
      }
    } else {
      if (mounted) setState(() => _warshAyahCounts = const {});
    }
  }

  /// Ayah count for a surah under the active riwaya (Hafs counts from the
  /// surah table, Warsh counts from the Warsh ayah table).
  int _ayahCountFor(SurahEntity surah) {
    if (_warshAyahCounts.isNotEmpty) {
      return _warshAyahCounts[surah.id] ?? surah.ayahCount;
    }
    return surah.ayahCount;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _surahFilterController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Re-fetches the "last reading position" bookmark. Called on first
  /// load, and again every time a push into the reader returns.
  /// If [autoResume] is true and the user was actively inside a surah
  /// when closing the app, automatically opens the reader at the saved position.
  void _refreshLastPosition({bool autoResume = false}) {
    final riwaya = getIt<SettingsCubit>().state is SettingsLoadSuccess
        ? (getIt<SettingsCubit>().state as SettingsLoadSuccess)
              .settings
              .quranRiwaya
        : QuranRiwaya.hafsAnAsim;
    setState(() {
      _lastPositionFuture = _bookmarkStorage.getLastPosition(riwaya).then((
        pos,
      ) async {
        if (pos != null && autoResume && !_autoResumed && mounted) {
          final prefs = await SharedPreferences.getInstance();
          final wasInsideReader =
              prefs.getBool(AppConstants.keyWasInsideQuranReader) ?? false;
          if (wasInsideReader && mounted) {
            _autoResumed = true;
            // The initial shell route (and its entrance animation) may still
            // be in flight during the first frames, leaving the Navigator
            // locked ("!_debugLocked"). Wait past that transition before
            // pushing the reader so the auto-resume never navigates while
            // the navigator is busy.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Future<void>.delayed(const Duration(milliseconds: 400), () {
                if (!mounted) return;
                _openReader({
                  'surahId': pos.surahId,
                  'title': pos.surahName,
                  'initialAyahId': pos.ayahNumber,
                  'page': pos.page,
                });
              });
            });
          }
        }
        return pos;
      });
    });
  }

  void _openReader(Map<String, dynamic> extra) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool(AppConstants.keyWasInsideQuranReader, true);
    });
    context.pushNamed('quran_reader', extra: extra).then((_) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool(AppConstants.keyWasInsideQuranReader, false);
      });
      if (mounted) _refreshLastPosition();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context);

    return BlocProvider.value(
      value: _cubit,
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            current is SettingsLoadSuccess &&
            (previous is! SettingsLoadSuccess ||
                previous.settings.quranRiwaya != current.settings.quranRiwaya),
        listener: (context, state) {
          _syncSurahCountsForRiwaya();
          _refreshLastPosition();
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.navQuran),
            titleTextStyle: AppTextStyles.arabicHeading(fontSize: 22).copyWith(
              color: isDark
                  ? AppColors.onSurfaceDark
                  : AppColors.onSurfaceLight,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bookmarks_outlined),
                onPressed: () => context
                    .pushNamed('quran_bookmarks')
                    .then((_) => _refreshLastPosition()),
                tooltip: l10n.quranBookmarksTooltip,
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.accentGold,
              labelColor: AppColors.primaryGreen,
              unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
              tabs: [
                Tab(text: l10n.quranTabSurah),
                Tab(text: l10n.quranTabJuz),
                Tab(text: l10n.quranTabSearch),
              ],
            ),
          ),
          body: Column(
            children: [
              _buildContinueReadingBanner(isDark),
              Expanded(
                child: BlocBuilder<QuranCubit, QuranState>(
                  builder: (context, state) {
                    final l10n = AppLocalizations.of(context);
                    if (state is QuranLoadInProgress &&
                        state is! QuranLoadSuccess) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primaryGreen,
                        ),
                      );
                    }

                    if (state is QuranLoadFailure) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 60,
                              color: AppColors.error,
                            ),
                            const SizedBox(height: 16),
                            Text(l10n.quranFailedToLoad(state.message)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => _cubit.loadSurahs(),
                              child: Text(l10n.commonRetry),
                            ),
                          ],
                        ),
                      );
                    }

                    List<SurahEntity> surahs = [];
                    List<AyahEntity> searchResults = [];
                    String searchQuery = '';
                    bool isSearching = false;
                    String? searchError;

                    if (state is QuranLoadSuccess) {
                      surahs = state.surahs;
                      searchResults = state.searchResults;
                      searchQuery = state.searchQuery;
                      isSearching = state.isSearching;
                      searchError = state.searchError;
                    }

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        // ── Tab 1: Surah List ──
                        _buildSurahTab(surahs, isDark),

                        // ── Tab 2: Juz List ──
                        _buildJuzTab(isDark, surahs),

                        // ── Tab 3: Search ──
                        _buildSearchTab(
                          searchResults,
                          searchQuery,
                          isDark,
                          surahs,
                          isSearching,
                          searchError,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueReadingBanner(bool isDark) {
    return FutureBuilder<QuranBookmark?>(
      future: _lastPositionFuture,
      builder: (context, snapshot) {
        final l10n = AppLocalizations.of(context);
        final position = snapshot.data;
        if (position == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                _openReader({
                  'surahId': position.surahId,
                  'title': position.surahName,
                  'initialAyahId': position.ayahNumber,
                  'page': position.page,
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [AppColors.primaryGreenDark, AppColors.cardDark]
                        : [AppColors.primaryGreen, AppColors.primaryGreenDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_rounded, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.quranContinueReading,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white70,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.quranPageDotSurah(
                              position.page,
                              position.surahName,
                            ),
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSurahTab(List<SurahEntity> surahs, bool isDark) {
    final l10n = AppLocalizations.of(context);
    final filteredSurahs = surahs.where((s) {
      final nameEn = s.nameEn.toLowerCase();
      final nameAr = s.nameAr;
      return nameEn.contains(_surahFilterQuery) ||
          nameAr.contains(_surahFilterQuery);
    }).toList();

    return Column(
      children: [
        // Search bar for local filtering
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            controller: _surahFilterController,
            decoration: InputDecoration(
              hintText: l10n.quranFilterSurahsHint,
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.primaryGreen,
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.surfaceDarkVariant
                  : AppColors.surfaceLightVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              suffixIcon: ClearTextSuffix(controller: _surahFilterController),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredSurahs.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemBuilder: (context, index) {
              final surah = filteredSurahs[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.cardLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.dividerDark
                        : AppColors.divider.withAlpha(80),
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withAlpha(40),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${surah.id}',
                        style: AppTextStyles.headingSmall.copyWith(
                          color: AppColors.accentGoldDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    surah.nameEn,
                    style: AppTextStyles.headingSmall.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceDark
                          : AppColors.onSurfaceLight,
                    ),
                  ),
                  subtitle: Row(
                    children: [
                      Text(
                        quranRevelationLabel(l10n, surah.revelation),
                        style: AppTextStyles.caption.copyWith(
                          color: surah.revelation == 'meccan'
                              ? AppColors.primaryGreen
                              : AppColors.teal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.quranAyahCount(_ayahCountFor(surah)),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.onSurfaceDarkVariant
                              : AppColors.onSurfaceLightVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: Text(
                    surah.nameAr,
                    style: AppTextStyles.arabicHeading(
                      fontSize: 18,
                    ).copyWith(color: AppColors.primaryGreen),
                  ),
                  onTap: () {
                    _openReader({'surahId': surah.id, 'title': surah.nameEn});
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJuzTab(bool isDark, List<SurahEntity> surahs) {
    final l10n = AppLocalizations.of(context);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: 30,
      itemBuilder: (context, index) {
        final juzNumber = index + 1;
        final juzLabel = l10n.quranJuzLabel(juzNumber);
        return InkWell(
          onTap: () {
            _openReader({'juzId': juzNumber, 'title': juzLabel});
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.surfaceDarkVariant, AppColors.cardDark]
                    : [Colors.white, AppColors.surfaceLightVariant],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.dividerDark
                    : AppColors.divider.withAlpha(80),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 30 : 10),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.primaryGreen.withAlpha(200),
                  size: 28,
                ),
                const SizedBox(height: 8),
                Text(
                  juzLabel,
                  style: AppTextStyles.headingSmall.copyWith(
                    color: isDark
                        ? AppColors.onSurfaceDark
                        : AppColors.onSurfaceLight,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchTab(
    List<AyahEntity> results,
    String query,
    bool isDark,
    List<SurahEntity> surahs,
    bool isSearching,
    String? searchError,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: l10n.quranSearchHint,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.surfaceDarkVariant
                        : AppColors.surfaceLightVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: ClearTextSuffix(controller: _searchController),
                  ),
                  onSubmitted: (val) {
                    _cubit.search(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.search_rounded),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  _cubit.search(_searchController.text);
                },
              ),
            ],
          ),
        ),
        if (query.isNotEmpty && !isSearching && searchError == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.quranFoundResults(results.length, query),
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark
                      ? AppColors.onSurfaceDarkVariant
                      : AppColors.onSurfaceLightVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        Expanded(
          child: isSearching
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                )
              : searchError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      l10n.commonError(searchError),
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : results.isEmpty
              ? Center(
                  child: Text(
                    query.isEmpty
                        ? l10n.quranSearchPrompt
                        : l10n.quranNoResults,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceDarkVariant
                          : AppColors.onSurfaceLightVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: results.length,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemBuilder: (context, index) {
                    final ayah = results[index];
                    final surahName = surahs
                        .firstWhere(
                          (s) => s.id == ayah.surahId,
                          orElse: () => SurahEntity(
                            id: ayah.surahId,
                            nameAr: '',
                            nameEn: l10n.quranSurahFallback(ayah.surahId),
                            revelation: '',
                            ayahCount: 0,
                          ),
                        )
                        .nameEn;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cardDark
                            : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? AppColors.dividerDark
                              : AppColors.divider.withAlpha(80),
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          _openReader({
                            'surahId': ayah.surahId,
                            'title': surahName,
                            'initialAyahId': ayah.number,
                          });
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$surahName ${ayah.surahId}:${ayah.number}',
                                  style: AppTextStyles.headingSmall.copyWith(
                                    fontSize: 14,
                                    color: AppColors.accentGoldDark,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppColors.primaryGreen,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              QuranAyahSpanBuilder.stripUnnaturalTajweedMarks(
                                ayah.textAr,
                              ),
                              style: AppTextStyles.arabicBody(fontSize: 16)
                                  .copyWith(
                                    color: isDark
                                        ? AppColors.onSurfaceDark
                                        : AppColors.primaryGreen,
                                  ),
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              locale: const Locale('ar'),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ayah.translationEn ?? '',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.onSurfaceDarkVariant
                                    : AppColors.onSurfaceLightVariant,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
