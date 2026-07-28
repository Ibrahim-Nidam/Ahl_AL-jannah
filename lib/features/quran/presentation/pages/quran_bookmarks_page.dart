import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/extensions.dart';
import '../../data/services/quran_bookmark_storage.dart';
import '../../domain/entities/quran_bookmark.dart';

class QuranBookmarksPage extends StatefulWidget {
  const QuranBookmarksPage({super.key});

  @override
  State<QuranBookmarksPage> createState() => _QuranBookmarksPageState();
}

class _QuranBookmarksPageState extends State<QuranBookmarksPage>
    with SingleTickerProviderStateMixin {
  final QuranBookmarkStorage _storage = QuranBookmarkStorage();
  late Future<List<QuranBookmark>> _futureBookmarks;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _futureBookmarks = _storage.loadBookmarks();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _futureBookmarks = _storage.loadBookmarks();
    });
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
              icon: const Icon(Icons.format_list_numbered_rtl_rounded, size: 20),
              text: l10n.quranBookmarksAyahs,
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<QuranBookmark>>(
        future: _futureBookmarks,
        builder: (context, snapshot) {
          final l10n = AppLocalizations.of(context);
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            );
          }

          final bookmarks = snapshot.data ?? const [];

          if (bookmarks.isEmpty) {
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
          final pageBookmarks = bookmarks
              .where((b) => b.isPageBookmark)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // 2. Sort Ayah Bookmarks: grouped by surah (asc), then by ayah number (asc)
          final ayahBookmarks = bookmarks
              .where((b) => b.isAyahBookmark)
              .toList()
            ..sort((a, b) {
              final surahCompare = a.surahId.compareTo(b.surahId);
              if (surahCompare != 0) return surahCompare;
              return (a.ayahNumber ?? 0).compareTo(b.ayahNumber ?? 0);
            });

          // Group ayah bookmarks by surahId (ordered maps preserve insertion order of keys)
          final ayahGroups = <int, List<QuranBookmark>>{};
          final surahNames = <int, String>{};
          for (final bookmark in ayahBookmarks) {
            ayahGroups.putIfAbsent(bookmark.surahId, () => []).add(bookmark);
            surahNames[bookmark.surahId] = bookmark.surahName;
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // ── Tab 1: Pages ──
              pageBookmarks.isEmpty
                  ? _buildEmptyTab(l10n.quranNoPageBookmarks, isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: pageBookmarks.length,
                      itemBuilder: (context, index) {
                        final bookmark = pageBookmarks[index];
                        return _BookmarkTile(
                          bookmark: bookmark,
                          isDark: isDark,
                          onDelete: () async {
                            await _storage.removeBookmark(bookmark.id);
                            _refresh();
                          },
                        );
                      },
                    ),

              // ── Tab 2: Ayahs ──
              ayahGroups.isEmpty
                  ? _buildEmptyTab(l10n.quranNoAyahBookmarks, isDark)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: ayahGroups.entries.map((entry) {
                        final surahId = entry.key;
                        final surahName = surahNames[surahId] ??
                            l10n.quranSurahFallback(surahId);
                        final groupBookmarks = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceDarkVariant
                                : AppColors.surfaceLightVariant,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.dividerDark
                                  : AppColors.divider.withAlpha(50),
                            ),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              initiallyExpanded: true,
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.menu_book_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                surahName,
                                style: AppTextStyles.headingSmall.copyWith(
                                  color: isDark
                                      ? AppColors.onSurfaceDark
                                      : AppColors.onSurfaceLight,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                l10n.quranSavedVersesCount(groupBookmarks.length),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.accentGoldDark,
                                ),
                              ),
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Divider(height: 1),
                                ),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: groupBookmarks.length,
                                  itemBuilder: (context, idx) {
                                    final bookmark = groupBookmarks[idx];
                                    return _BookmarkTile(
                                      bookmark: bookmark,
                                      isDark: isDark,
                                      onDelete: () async {
                                        await _storage.removeBookmark(bookmark.id);
                                        _refresh();
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ],
          );
        },
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

class _BookmarkTile extends StatelessWidget {
  final QuranBookmark bookmark;
  final bool isDark;
  final Future<void> Function() onDelete;

  const _BookmarkTile({
    required this.bookmark,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final subtitle = bookmark.isPageBookmark
        ? l10n.quranPageDotSurah(bookmark.page, bookmark.surahName)
        : '${l10n.quranAyahBookmarkLabel(bookmark.surahId, bookmark.ayahNumber ?? 0)} • ${l10n.quranPageLabel(bookmark.page)}';

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
        child: const Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 28),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              bookmark.previewText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: bookmark.isAyahBookmark
                  ? AppTextStyles.arabicBody(fontSize: 16).copyWith(
                      color: isDark ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    )
                  : AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.onSurfaceDarkVariant
                          : AppColors.onSurfaceLightVariant,
                    ),
              textDirection: bookmark.isAyahBookmark ? TextDirection.rtl : null,
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
          onTap: () {
            context.pushNamed(
              'quran_reader',
              extra: {
                'surahId': bookmark.surahId,
                'title': bookmark.surahName,
                'initialAyahId': bookmark.ayahNumber ?? 1,
                'page': bookmark.page,
              },
            );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.month}/${dateTime.day}';
  }
}
