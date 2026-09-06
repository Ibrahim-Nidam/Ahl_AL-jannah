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
    await _showOemAutostartNudge();
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

  /// Shows a one-time nudge for OEMs with aggressive background killing
  /// (Xiaomi/MIUI, Huawei, OnePlus, Oppo, Vivo, Samsung) to enable
  /// autostart. This is a UX nudge, not a guarantee — but combined with
  /// the exact-alarm permission, it should stop most background killing.
  Future<void> _showOemAutostartNudge() async {
    if (!Platform.isAndroid || !mounted || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(AppConstants.keyOemAutostartPrompted) ?? false;
    if (alreadyPrompted) return;

    final manufacturer = Platform.operatingSystemVersion.isNotEmpty
        ? _detectManufacturer()
        : null;
    if (manufacturer == null) return;

    final intentAction = _autostartIntentFor(manufacturer);
    if (intentAction == null) return;

    if (!context.mounted) return;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Enable Auto-Start'),
          content: Text(
            'For reliable prayer time alerts, please enable auto-start for '
            'Ahl Jannah in your device settings. This ensures notifications '
            'fire even when the app is closed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    ) ?? false;

    await prefs.setBool(AppConstants.keyOemAutostartPrompted, true);

    if (shouldOpen) {
      try {
        final intent = AndroidIntent(action: intentAction);
        await intent.launch();
      } catch (e) {
        debugPrint('Failed to open autostart settings for $manufacturer: $e');
      }
    }
  }

  /// Detects the device manufacturer for OEM-specific autostart intents.
  static String? _detectManufacturer() {
    try {
      final version = Platform.operatingSystemVersion.toLowerCase();
      if (version.contains('miui') || version.contains('xiaomi') || version.contains('redmi')) return 'xiaomi';
      if (version.contains('huawei') || version.contains('emui')) return 'huawei';
      if (version.contains('oneplus') || version.contains('hydrogen')) return 'oneplus';
      if (version.contains('oppo') || version.contains('coloros')) return 'oppo';
      if (version.contains('vivo') || version.contains('funtouch')) return 'vivo';
      if (version.contains('samsung') || version.contains('one ui')) return 'samsung';
    } catch (_) {}
    return null;
  }

  /// Returns the intent action for enabling autostart on the given manufacturer.
  static String? _autostartIntentFor(String manufacturer) {
    switch (manufacturer) {
      case 'xiaomi':
        return 'miui.intent.action.AUTO_START';
      case 'huawei':
        return 'huawei.intent.action.HSM_BOOTAPP_MANAGER';
      case 'oneplus':
        return 'com.oneplus.autostartmanage.action.AUTO_START';
      case 'oppo':
        return 'com.coloros.safecenter.startupmanager.StartUpManagerActivity';
      case 'vivo':
        return 'com.vivo.permissionmanager.activity.BgStartUpManagerActivity';
      case 'samsung':
        // Samsung doesn't have a specific intent; the battery optimization
        // screen covers it. Return null to skip.
        return null;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
