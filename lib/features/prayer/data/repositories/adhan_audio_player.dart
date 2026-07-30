import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/prayer_entities.dart';
import '../../../settings/domain/entities/settings_entities.dart';
import '../../../../core/utils/app_logger.dart';

/// Service for playing adhan audio using audioplayers plugin.
/// This is more reliable than notification sounds on real Android devices.
@singleton
class AdhanAudioPlayer {
  final AudioPlayer _audioPlayer = AudioPlayer();
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
    if (_isPlaying) {
      AppLogger.info('Stopping currently playing adhan before starting new one');
      await stopAdhan();
    }

    final assetPath = _getAssetPath(prayerKey, adhanType);
    AppLogger.info('Playing adhan from asset: $assetPath');

    try {
      _isPlaying = true;
      _currentPrayerKey = prayerKey;

      // Set audio session to alarm category for priority playback
      AppLogger.debug('Setting audio player configuration');
      await _audioPlayer.setReleaseMode(ReleaseMode.release);
      await _audioPlayer.setVolume(1.0);
      
      // On Android, set player mode to ensure it plays even in silent mode
      if (Platform.isAndroid) {
        AppLogger.debug('Android detected - using setSourceAsset');
        await _audioPlayer.setSourceAsset(assetPath);
        await _audioPlayer.play(AssetSource(assetPath));
      } else {
        AppLogger.debug('iOS detected - using standard play');
        await _audioPlayer.play(AssetSource(assetPath));
      }

      AppLogger.info('Audio player play command executed successfully');

      // Listen for completion to reset state
      _audioPlayer.onPlayerComplete.listen((_) {
        _isPlaying = false;
        _currentPrayerKey = null;
        AppLogger.info('Adhan playback completed naturally');
      });
      
      _audioPlayer.onPlayerStateChanged.listen((state) {
        AppLogger.debug('Audio player state changed: $state');
        if (state == PlayerState.completed || state == PlayerState.stopped) {
          _isPlaying = false;
          _currentPrayerKey = null;
        }
      });
    } catch (e, stackTrace) {
      _isPlaying = false;
      _currentPrayerKey = null;
      AppLogger.error('Failed to play adhan', error: e, stackTrace: stackTrace);
    }
  }

  /// Stops the currently playing adhan.
  Future<void> stopAdhan() async {
    if (!_isPlaying) return;

    try {
      AppLogger.info('Stopping adhan for $_currentPrayerKey');
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentPrayerKey = null;
      AppLogger.info('Adhan stopped successfully');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to stop adhan', error: e, stackTrace: stackTrace);
    }
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
    await _audioPlayer.dispose();
  }
}
