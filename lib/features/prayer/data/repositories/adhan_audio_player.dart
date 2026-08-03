import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:injectable/injectable.dart';

import '../../../settings/domain/entities/settings_entities.dart';
import '../../../../core/utils/app_logger.dart';

/// Service for playing adhan audio using audioplayers plugin.
/// This is more reliable than notification sounds on real Android devices.
///
/// Creates a fresh [AudioPlayer] for every playback session and fully disposes
/// it when done, ensuring the native platform player never enters a terminal
/// state that would block subsequent playback.
@singleton
class AdhanAudioPlayer {
  AudioPlayer? _currentPlayer;
  StreamSubscription? _completionSub;
  StreamSubscription? _stateSub;
  bool _isPlaying = false;
  String? _currentPrayerKey;

  /// Plays the adhan for the specified prayer key and adhan type.
  Future<void> playAdhan(String prayerKey, AdhanType adhanType) async {
    AppLogger.info('AdhanAudioPlayer.playAdhan called - prayerKey: $prayerKey, adhanType: $adhanType');

    if (_isPlaying && _currentPrayerKey == prayerKey) {
      AppLogger.warning('Adhan already playing for $prayerKey, skipping');
      return;
    }

    // Stop any currently playing adhan
    if (_isPlaying || _currentPlayer != null) {
      AppLogger.info('Stopping currently playing adhan before starting new one');
      await stopAdhan();
    }

    final assetPath = _getAssetPath(prayerKey, adhanType);
    AppLogger.info('Playing adhan from asset: $assetPath');

    try {
      final player = AudioPlayer();
      _currentPlayer = player;
      _isPlaying = true;
      _currentPrayerKey = prayerKey;

      AppLogger.debug('Setting audio player configuration');
      await player.setAudioContext(AudioContext(
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          usageType: AndroidUsageType.alarm,
          contentType: AndroidContentType.music,
          audioFocus: AndroidAudioFocus.gain,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
          },
        ),
      ));
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(1.0);

      AppLogger.debug('Starting adhan audio playback');
      await player.play(AssetSource(assetPath));

      AppLogger.info('Audio player play command executed successfully');

      // Cancel any stale subscriptions before registering new ones
      await _completionSub?.cancel();
      await _stateSub?.cancel();

      _completionSub = player.onPlayerComplete.listen((_) {
        AppLogger.info('Adhan playback completed naturally');
        _resetState();
      });

      _stateSub = player.onPlayerStateChanged.listen((state) {
        AppLogger.debug('Audio player state changed: $state');
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _resetState();
        }
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to play adhan', error: e, stackTrace: stackTrace);
      _resetState();
    }
  }

  /// Stops the currently playing adhan.
  Future<void> stopAdhan() async {
    if (_currentPlayer == null && !_isPlaying) return;

    try {
      AppLogger.info('Stopping adhan for $_currentPrayerKey');
      await _currentPlayer?.stop();
      AppLogger.info('Adhan stopped successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to stop adhan', error: e, stackTrace: stackTrace);
    }
    _resetState();
  }

  /// Returns whether an adhan is currently playing.
  bool get isPlaying => _isPlaying;

  /// Returns the prayer key of the currently playing adhan, if any.
  String? get currentPrayerKey => _currentPrayerKey;

  /// Gets the asset path for the adhan file based on prayer key and adhan type.
  String _getAssetPath(String prayerKey, AdhanType adhanType) {
    if (adhanType == AdhanType.short) {
      return 'adhan_short.mp3';
    }
    if (prayerKey == 'fajr') {
      return 'adhan_alfajr.mp3';
    }
    return 'adhan.mp3';
  }

  /// Releases resources when the service is no longer needed.
  Future<void> dispose() async {
    await _currentPlayer?.dispose();
    await _completionSub?.cancel();
    await _stateSub?.cancel();
    _currentPlayer = null;
    _completionSub = null;
    _stateSub = null;
    _isPlaying = false;
    _currentPrayerKey = null;
  }

  /// Tears down the current player and resets all state so a fresh
  /// playback can begin on the next [playAdhan] call.
  void _resetState() {
    _completionSub?.cancel();
    _completionSub = null;
    _stateSub?.cancel();
    _stateSub = null;
    _currentPlayer?.dispose();
    _currentPlayer = null;
    _isPlaying = false;
    _currentPrayerKey = null;
  }
}
