/// Root widget for Ahl Jannah.
///
/// Configures [MaterialApp.router] with theming, localization, screen
/// utility initialization, and the [GoRouter] navigation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'core/constants/app_constants.dart';
import 'core/di/injection.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/startup_permission_prompt.dart';
import 'features/settings/domain/entities/settings_entities.dart';
import 'features/settings/presentation/bloc/settings_cubit.dart';
import 'l10n/generated/app_localizations.dart';

/// Resolves the [Locale] the app should use for the given settings state.
///
/// Returns `null` for [AppLanguage.system] (and while settings are still
/// loading), which tells [MaterialApp] to fall back to
/// [MaterialApp.localeResolutionCallback] and pick from the device locale.
Locale? _resolveLocale(SettingsState state) {
  final language =
      state is SettingsLoadSuccess ? state.settings.language : AppLanguage.system;

  switch (language) {
    case AppLanguage.en:
      return const Locale('en');
    case AppLanguage.ar:
      return const Locale('ar');
    case AppLanguage.fr:
      return const Locale('fr');
    case AppLanguage.system:
      return null;
  }
}

/// Resolves the persisted [AppThemeMode] into Flutter's [ThemeMode].
/// Defaults to [ThemeMode.system] while settings are still loading.
ThemeMode _resolveThemeMode(SettingsState state) {
  final mode =
      state is SettingsLoadSuccess ? state.settings.themeMode : AppThemeMode.system;

  switch (mode) {
    case AppThemeMode.light:
      return ThemeMode.light;
    case AppThemeMode.dark:
      return ThemeMode.dark;
    case AppThemeMode.system:
      return ThemeMode.system;
  }
}

/// Resolves the persisted [AppColorPalette]. Defaults to the classic
/// (Emerald) palette while settings are still loading.
AppColorPalette _resolvePalette(SettingsState state) {
  return state is SettingsLoadSuccess
      ? state.settings.colorPalette
      : AppColorPalette.classic;
}

class AhlJannahApp extends StatelessWidget {
  const AhlJannahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => getIt<SettingsCubit>()..loadSettings(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, settingsState) {
          final locale = _resolveLocale(settingsState);
          final themeMode = _resolveThemeMode(settingsState);
          final palette = _resolvePalette(settingsState);

          return ScreenUtilInit(
            // Design size based on standard mobile (360 × 800).
            designSize: const Size(360, 800),
            minTextAdapt: true,
            splitScreenMode: true,
            builder: (context, child) {
              return MaterialApp.router(
                title: AppConstants.appName,
                debugShowCheckedModeBanner: false,
                builder: (context, child) {
                  return Stack(
                    children: [
                      if (child != null) child,
                      const StartupPermissionPrompt(),
                    ],
                  );
                },

                // ── Theming ──
                // Both theme variants are built for the user's selected
                // color palette; `themeMode` (driven by the settings
                // AppThemeMode) decides which one is actually shown, and
                // switches immediately when the setting changes since
                // this whole subtree rebuilds on SettingsCubit emissions.
                theme: AppTheme.light(palette),
                darkTheme: AppTheme.dark(palette),
                themeMode: themeMode,
                // ── Localization ──
                // `locale` is null for AppLanguage.system, which makes
                // MaterialApp consult `localeResolutionCallback` below
                // using the device's locale.
                locale: locale,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                localeResolutionCallback: (deviceLocale, supportedLocales) {
                  if (deviceLocale != null) {
                    for (final supported in supportedLocales) {
                      if (supported.languageCode == deviceLocale.languageCode) {
                        return supported;
                      }
                    }
                  }
                  // Fallback language when the device locale isn't one of
                  // our supported languages (en/ar/fr).
                  return const Locale('en');
                },

                // ── Routing ──
                routerConfig: appRouter,
              );
            },
          );
        },
      ),
    );
  }
}