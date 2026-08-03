import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import '../di/injection.dart';
import '../../features/prayer/data/repositories/prayer_notification_service.dart';
import '../../l10n/generated/app_localizations.dart';

/// Requests notification/location permissions and battery optimization
/// exemption once, after [MaterialApp] has mounted so
/// [MaterialLocalizations] and [showDialog] are available.
class StartupPermissionPrompt extends StatefulWidget {
  const StartupPermissionPrompt({super.key});

  @override
  State<StartupPermissionPrompt> createState() => _StartupPermissionPromptState();
}

class _StartupPermissionPromptState extends State<StartupPermissionPrompt> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRequestStartupPermissions());
  }

  Future<void> _maybeRequestStartupPermissions() async {
    if (_started || !mounted) return;
    _started = true;

    final prefs = await SharedPreferences.getInstance();
    final hasRequested =
        prefs.getBool(AppConstants.keyStartupPermissionsRequested) ?? false;
    if (hasRequested || !mounted) return;

    if (!context.mounted) return;

    final shouldRequest =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            return AlertDialog(
              title: Text(l10n.startupPermissionsTitle),
              content: Text(l10n.startupPermissionsBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.commonContinue),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldRequest) {
      // Don't set the flag - allow asking again on next app launch
      return;
    }

    await _requestPermissions();
    await _requestBatteryOptimization();
    await prefs.setBool(AppConstants.keyStartupPermissionsRequested, true);
  }

  Future<void> _requestPermissions() async {
    final notificationService = getIt<PrayerNotificationService>();
    await notificationService.initialize();
    await notificationService.requestPermissions();

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          await Geolocator.requestPermission();
        }
      }
    } catch (_) {
      // Best-effort prompt only.
    }
  }

  Future<void> _requestBatteryOptimization() async {
    if (!Platform.isAndroid || !mounted || !context.mounted) return;

    final l10n = AppLocalizations.of(context);

    final shouldOpen =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text(l10n.batteryOptimizationSectionTitle),
              content: Text(l10n.startupBatteryOptimizationBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.commonContinue),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldOpen) return;

    try {
      final intent = AndroidIntent(
        action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
      );
      await intent.launch();
    } catch (e) {
      debugPrint('Failed to open battery optimization settings: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
