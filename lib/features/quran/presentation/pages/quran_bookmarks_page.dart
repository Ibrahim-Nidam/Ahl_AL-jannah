import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../settings/presentation/bloc/settings_cubit.dart';
import '../../data/services/quran_bookmark_storage.dart';
import '../../domain/entities/quran_bookmark.dart';
import '../../domain/entities/quran_entities.dart';
import '../cubit/quran_cubit.dart';

/// Lists saved page + ayah bookmarks in two tabs.
///
/// Bookmarks live in [QuranBookmarkStorage], scoped to the active riwaya
/// (Hafs and Warsh keep separate bookmark sets). This page keeps a local
/// copy of the list so the UI reflects deletions immediately (optimistic
/// remove) and reloads it every time a pushed reader page pops back,
/// so changes made inside the reader are visible right away.
class QuranBookmarksPage extends StatefulWidget {
  const QuranBookmarksPage({super.key});

  @override
  State<QuranBookmarksPage> createState() => _QuranBookmarksPageState();
}

class _QuranBookmarksPageState extends State<QuranBookmarksPage>
    with SingleTickerProviderStateMixin {
  final QuranBookmarkStorage _storage = QuranBookmarkStorage();
  final QuranCubit _cubit = getIt<QuranCubit>();
  late final TabController _tabController;

  List<QuranBookmark> _bookmarks = const [];
  List<SurahEntity> _allSurahs = const [];
  bool _loading = true;
  String? _error;

  /// Juz and Hizb metadata for page bookmarks, keyed by page number.
  /// Loaded asynchronously after bookmarks are fetched.
  Map<int, ({int juz, int hizb})> _pageMetadata = const {};

  /// Tracks which surah group is currently expanded in Tab 2.
  int? _expandedSurahId;

  QuranRiwaya _activeRiwaya() {
    final state = getIt<SettingsCubit>().state;
    if (state is SettingsLoadSuccess) return state.settings.quranRiwaya;
    return QuranRiwaya.hafsAnAsim;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final bookmarks = await _storage.loadBookmarks(_activeRiwaya());
      if (!mounted) return;

      // Load surahs list for Arabic name lookups.
      final cubitState = _cubit.state;
      List<SurahEntity> surahs = const [];
      if (cubitState is QuranLoadSuccess) {
        surahs = cubitState.surahs;
      }

      setState(() {
        _bookmarks = bookmarks;
        _allSurahs = surahs;
        _loading = false;
        _error = null;
      });

      // Fetch juz/hizb metadata for page bookmarks asynchronously.
      _loadPageMetadata(bookmarks);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  /// Fetches juz/hizb data for each unique page in the page bookmarks list.
  Future<void> _loadPageMetadata(List<QuranBookmark> bookmarks) async {
    final pageBookmarks = bookmarks.where((b) => b.isPageBookmark).toList();
    final uniquePages = pageBookmarks.map((b) => b.page).toSet();
    final newMeta = <int, ({int juz, int hizb})>{};

    final isWarsh = _activeRiwaya() == QuranRiwaya.warsh;

    for (final page in uniquePages) {
      try {
        final ayahs = isWarsh
            ? await _cubit.getWarshAyahsByPage(page)
            : await _cubit.getAyahsByPage(page);
        if (ayahs.isNotEmpty) {
          newMeta[page] = (juz: ayahs.first.juz, hizb: ayahs.first.hizb);
        }
      } catch (_) {
        // Silently skip — metadata is optional enhancement.
      }
    }

    if (!mounted) return;
    setState(() => _pageMetadata = newMeta);
  }

  /// Looks up the Arabic surah name from the loaded surahs list.
  String _arabicName(int surahId) {
    final match = _allSurahs.where((s) => s.id == surahId);
    return match.isNotEmpty ? match.first.nameAr : '';
  }

  /// Removes a bookmark from the local list immediately, then persists.
  /// Re-loads on failure so the item reappears if the write failed.
  Future<void> _delete(QuranBookmark bookmark) async {
    setState(() {
      _bookmarks = _bookmarks
          .where((b) => b.id != bookmark.id)
          .toList(growable: false);
    });
    try {
      await _storage.removeBookmark(_activeRiwaya(), bookmark.id);
    } catch (_) {
      await _load();
    }
  }

  /// Opens the reader for a bookmark and refreshes the list when the user
  /// comes back, so bookmarks toggled inside the reader show up instantly.
  Future<void> _openReaderFor(QuranBookmark bookmark) async {
    await context.pushNamed(
      'quran_reader',
      extra: {
        'surahId': bookmark.surahId,
        'title': bookmark.surahName,
        'initialAyahId': bookmark.ayahNumber ?? 1,
        'page': bookmark.page,
      },
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.quranBookmarksTitle),
        titleTextStyle: AppTextStyles.arabicHeading(fontSize: 20).copyWith(
          color: isDark ? AppColors.onSurfaceDark : AppColors.onSurfaceLight,
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentGold,
          labelColor: AppColors.primaryGreen,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: const Icon(Icons.chrome_reader_mode_outlined, size: 20),
              text: l10n.quranBookmarksPages,
            ),
            Tab(
              icon: const Icon(
                Icons.format_list_numbered_rtl_rounded,
                size: 20,
              ),
              text: l10n.quranBookmarksAyahs,
            ),
          ],
        ),
      ),
      body: _buildBody(isDark, l10n),
    );
  }

  Widget _buildBody(bool isDark, AppLocalizations l10n) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryGreen),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.commonError(_error!),
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }

    if (_bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border_rounded,
              size: 80,
              color: (isDark ? Colors.white24 : Colors.black26),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.quranNoBookmarksYet,
              style: AppTextStyles.bodyLarge.copyWith(
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
              ),
            ),
          ],
        ),
      );
    }

    // 1. Sort Page Bookmarks: newest/last-used first (chrono descending)
    final pageBookmarks = _bookmarks.where((b) => b.isPageBookmark).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // 2. Group Ayah Bookmarks by Surah
    final Map<int, List<QuranBookmark>> groupedAyahBookmarks = {};
    for (final b in _bookmarks.where((b) => b.isAyahBookmark)) {
      groupedAyahBookmarks.putIfAbsent(b.surahId, () => []).add(b);
    }
    for (final list in groupedAyahBookmarks.values) {
      list.sort((a, b) => (a.ayahNumber ?? 0).compareTo(b.ayahNumber ?? 0));
    }
    final surahIds = groupedAyahBookmarks.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _load,
      child: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 1: Pages ──
          pageBookmarks.isEmpty
              ? _buildEmptyTab(l10n.quranNoPageBookmarks, isDark)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: pageBookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = pageBookmarks[index];
                    return _PageBookmarkTile(
                      bookmark: bookmark,
                      isDark: isDark,
                      arabicName: _arabicName(bookmark.surahId),
                      metadata: _pageMetadata[bookmark.page],
                      onDelete: () => _delete(bookmark),
                      onOpen: () => _openReaderFor(bookmark),
                    );
                  },
                ),

          // ── Tab 2: Ayahs (Grouped by Surah, collapsed by default) ──
          groupedAyahBookmarks.isEmpty
              ? _buildEmptyTab(l10n.quranNoAyahBookmarks, isDark)
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: surahIds.length,
                  itemBuilder: (context, index) {
                    final surahId = surahIds[index];
                    final bookmarks = groupedAyahBookmarks[surahId]!;
                    final isExpanded = _expandedSurahId == surahId;
                    return _SurahAyahGroupTile(
                      surahId: surahId,
                      surahNameEn: bookmarks.first.surahName,
                      arabicName: _arabicName(surahId),
                      bookmarks: bookmarks,
                      isDark: isDark,
                      isExpanded: isExpanded,
                      onToggle: () {
                        setState(() {
                          _expandedSurahId = isExpanded ? null : surahId;
                        });
                      },
                      onDeleteBookmark: _delete,
                      onOpenBookmark: _openReaderFor,
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyTab(String message, bool isDark) {
    return Center(
      child: Text(
        message,
        style: AppTextStyles.bodyMedium.copyWith(
          color: isDark
              ? AppColors.onSurfaceDarkVariant
              : AppColors.onSurfaceLightVariant,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page Bookmark Tile — shows Arabic + English surah name, Juz, Hizb, Page
// ─────────────────────────────────────────────────────────────────────────────

class _PageBookmarkTile extends StatelessWidget {
  final QuranBookmark bookmark;
  final bool isDark;
  final String arabicName;
  final ({int juz, int hizb})? metadata;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _PageBookmarkTile({
    required this.bookmark,
    required this.isDark,
    required this.arabicName,
    required this.metadata,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Build rich subtitle: "Arabic Name • English Name"
    final nameDisplay = arabicName.isNotEmpty
        ? '$arabicName • ${bookmark.surahName}'
        : bookmark.surahName;

    // Build metadata line: "Juz X • Hizb Y • Page Z"
    final metaParts = <String>[];
    if (metadata != null) {
      metaParts.add(l10n.quranJuzLabel(metadata!.juz));
      metaParts.add(l10n.quranHizbLabel(metadata!.hizb));
    }
    metaParts.add(l10n.quranPageLabel(bookmark.page));
    final metaLine = metaParts.join(' • ');

    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error.withAlpha(220),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.delete_sweep_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        color: isDark ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark
                ? AppColors.dividerDark
                : AppColors.divider.withAlpha(60),
          ),
        ),
        elevation: 0,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: Text(
            nameDisplay,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(
              metaLine,
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatDate(bookmark.createdAt),
                style: AppTextStyles.caption.copyWith(
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
          onTap: onOpen,
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Ayah Bookmark Tile — collapsed by default, expandable per card
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Surah Ayah Group Tile — grouped by surah, collapsed by default
// ─────────────────────────────────────────────────────────────────────────────

class _SurahAyahGroupTile extends StatelessWidget {
  final int surahId;
  final String surahNameEn;
  final String arabicName;
  final List<QuranBookmark> bookmarks;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Function(QuranBookmark) onDeleteBookmark;
  final Function(QuranBookmark) onOpenBookmark;

  const _SurahAyahGroupTile({
    required this.surahId,
    required this.surahNameEn,
    required this.arabicName,
    required this.bookmarks,
    required this.isDark,
    required this.isExpanded,
    required this.onToggle,
    required this.onDeleteBookmark,
    required this.onOpenBookmark,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Header: "Arabic Name • English Name"
    final titleText = arabicName.isNotEmpty
        ? '$arabicName • $surahNameEn'
        : surahNameEn;

    final countText = l10n.quranSavedVersesCount(bookmarks.length);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark
              ? AppColors.dividerDark
              : AppColors.divider.withAlpha(60),
        ),
      ),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── Collapsed surah header ──
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Text(
              titleText,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                countText,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.accentGoldDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            trailing: AnimatedRotation(
              turns: isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                size: 24,
                color: isDark
                    ? AppColors.onSurfaceDarkVariant
                    : AppColors.onSurfaceLightVariant,
              ),
            ),
            onTap: onToggle,
          ),

          // ── Expanded list of saved ayahs ──
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1),
                for (int i = 0; i < bookmarks.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: isDark
                          ? AppColors.dividerDark.withAlpha(50)
                          : AppColors.divider.withAlpha(40),
                    ),
                  _AyahBookmarkSubItem(
                    bookmark: bookmarks[i],
                    isDark: isDark,
                    onDelete: () => onDeleteBookmark(bookmarks[i]),
                    onOpen: () => onOpenBookmark(bookmarks[i]),
                  ),
                ],
              ],
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _AyahBookmarkSubItem extends StatelessWidget {
  final QuranBookmark bookmark;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _AyahBookmarkSubItem({
    required this.bookmark,
    required this.isDark,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final ayahLabel = l10n.quranAyahBookmarkLabel(
      bookmark.surahId,
      bookmark.ayahNumber ?? 0,
    );

    return Dismissible(
      key: ValueKey(bookmark.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppColors.error.withAlpha(200),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$ayahLabel • ${l10n.quranPageLabel(bookmark.page)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.error,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                    tooltip: 'Delete bookmark',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                bookmark.previewText,
                style: AppTextStyles.arabicBody(fontSize: 16).copyWith(
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.6,
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.commonContinue,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
