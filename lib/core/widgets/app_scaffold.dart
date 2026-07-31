/// Scaffold wrapper with persistent bottom navigation bar.
///
/// Used by [StatefulShellRoute] to wrap the navigation shell,
/// preserving each tab's state independently and restoring the last tab.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ahl_jannah/l10n/generated/app_localizations.dart';
import '../constants/app_constants.dart';

/// A [Scaffold] that wraps [StatefulNavigationShell] with a
/// Material 3 [NavigationBar] at the bottom.
class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.navigationShell,
    super.key,
  });

  /// The navigation shell provided by [StatefulShellRoute].
  final StatefulNavigationShell navigationShell;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  bool _tabRestored = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Wait for the initial shell route transition to finish; switching
      // branches while the Navigator is mid-transition can trigger the
      // "!_debugLocked" assertion in NavigatorState.build.
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        _restoreLastTab();
      });
    });
  }

  Future<void> _restoreLastTab() async {
    if (_tabRestored || !mounted) return;
    _tabRestored = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final savedTab = prefs.getInt(AppConstants.keyLastNavigationTab);
      if (savedTab != null && savedTab >= 0 && savedTab < 5) {
        // Only auto-restore if the shell is currently at the default initial
        // branch (1 - Prayer) and no deep-link path overrode it.
        final path = GoRouterState.of(context).uri.path;
        final isDefaultPath = path == '/prayer' || path == '/quran';
        if (widget.navigationShell.currentIndex == 1 && isDefaultPath && savedTab != 1) {
          widget.navigationShell.goBranch(savedTab);
        }
      }
    } catch (_) {
      // Best-effort restoration.
    }
  }

  Future<void> _onTabSelected(int index) async {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConstants.keyLastNavigationTab, index);
    } catch (_) {
      // Best-effort storage.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final path = GoRouterState.of(context).uri.path;
    // Immersive reading: hide the section nav on the Quran reader so the
    // mushaf can use the full height.
    final hideBottomNav = path.contains('/quran/reader');

    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: hideBottomNav
          ? null
          : NavigationBar(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _onTabSelected,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(Icons.menu_book_rounded),
                  label: l10n.navQuran,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.mosque_outlined),
                  selectedIcon: const Icon(Icons.mosque_rounded),
                  label: l10n.navPrayer,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.explore_outlined),
                  selectedIcon: const Icon(Icons.explore_rounded),
                  label: l10n.navQibla,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.auto_awesome_outlined),
                  selectedIcon: const Icon(Icons.auto_awesome_rounded),
                  label: l10n.navAdhkar,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.more_horiz_outlined),
                  selectedIcon: const Icon(Icons.more_horiz_rounded),
                  label: l10n.moreTabTitle,
                ),
              ],
            ),
    );
  }
}
