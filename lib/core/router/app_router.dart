/// Application router using [go_router] with [StatefulShellRoute]
/// for bottom navigation tab persistence.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/adhkar/domain/entities/adhkar_entities.dart';
import '../../features/adhkar/presentation/pages/adhkar_page.dart';
import '../../features/adhkar/presentation/pages/tasbeeh_page.dart';
import '../../features/prayer/presentation/pages/prayer_page.dart';
import '../../features/qibla/presentation/pages/qibla_page.dart';
import '../../features/quran/presentation/pages/quran_bookmarks_page.dart';
import '../../features/quran/presentation/pages/quran_page.dart';
import '../../features/quran/presentation/pages/quran_reader_page.dart';
import '../../features/settings/presentation/pages/more_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../widgets/app_scaffold.dart';

/// Route name constants for type-safe navigation.
abstract final class AppRoutes {
  static const String quran = '/quran';
  static const String prayer = '/prayer';
  static const String qibla = '/qibla';
  static const String adhkar = '/adhkar';
  static const String more = '/more';
  static const String hadith = '/hadith';
  static const String settings = '/settings';
}

/// Creates the app-level [GoRouter] configuration.
///
/// Uses [StatefulShellRoute.indexedStack] to preserve each tab's
/// navigation state independently. Default startup page is [AppRoutes.prayer].
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.prayer,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return AppScaffold(navigationShell: navigationShell);
      },
      branches: [
        // ── Tab 0: Quran ──
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.quran,
              name: 'quran',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: QuranPage()),
              routes: [
                GoRoute(
                  path: 'bookmarks',
                  name: 'quran_bookmarks',
                  builder: (context, state) => const QuranBookmarksPage(),
                ),
                GoRoute(
                  path: 'reader',
                  name: 'quran_reader',
                  // IMPORTANT: this must be `pageBuilder`, not `builder`.
                  pageBuilder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final surahId = extra?['surahId'] as int?;
                    final juzId = extra?['juzId'] as int?;
                    final title = extra?['title'] as String? ?? '';
                    final initialAyahId = extra?['initialAyahId'] as int?;
                    final page = extra?['page'] as int?;

                    return MaterialPage(
                      key: ValueKey(
                        'quran_reader_${surahId}_${juzId}_${page}_$initialAyahId',
                      ),
                      child: QuranReaderPage(
                        surahId: surahId,
                        juzId: juzId,
                        title: title,
                        initialAyahId: initialAyahId,
                        page: page,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // ── Tab 1: Prayer ──
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.prayer,
              name: 'prayer',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: PrayerPage()),
            ),
          ],
        ),

        // ── Tab 2: Qibla ──
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.qibla,
              name: 'qibla',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: QiblaPage()),
            ),
          ],
        ),

        // ── Tab 3: Adhkar ──
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.adhkar,
              name: 'adhkar',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                final initialCategory = extra?['initialCategory'] as String?;
                return NoTransitionPage(
                  child: AdhkarPage(initialCategory: initialCategory),
                );
              },
              routes: [
                GoRoute(
                  path: 'tasbeeh',
                  name: 'tasbeeh',
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    final item = extra?['item'] as AdhkarItem?;
                    final addToCollection =
                        extra?['addToCollection'] as bool? ?? false;
                    return TasbeehPage(
                      initialItem: item,
                      addInitialToCollection: addToCollection,
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        // ── Tab 4: More ──
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.more,
              name: 'more',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: MorePage()),
              routes: [
                GoRoute(
                  path: 'settings',
                  name: 'settings',
                  builder: (context, state) => const SettingsPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);