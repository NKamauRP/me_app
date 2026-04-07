import 'package:audioplayers/audioplayers.dart';

import 'theme_service.dart';

class AudioService {
  AudioService._();

  static final AudioService instance = AudioService._();

  static const String _backgroundAsset = 'sounds/calmloopbg.mp3';
  static const double _backgroundVolume = 0.2;

  final AudioPlayer _backgroundPlayer = AudioPlayer();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await _backgroundPlayer.setReleaseMode(ReleaseMode.loop);
    await _backgroundPlayer.setVolume(_backgroundVolume);
    _initialized = true;

    await updatePlaybackPreference();
  }

  Future<void> updatePlaybackPreference() async {
    if (!_initialized) {
      return;
    }

    if (ThemeService.instance.backgroundMusicEnabled) {
      await ensureLooping();
      return;
    }

    await stop();
  }

  Future<void> ensureLooping() async {
    if (!_initialized || !ThemeService.instance.backgroundMusicEnabled) {
      return;
    }

    final state = _backgroundPlayer.state;
    if (state == PlayerState.playing) {
      return;
    }

    if (state == PlayerState.paused) {
      await _backgroundPlayer.resume();
      return;
    }

    await _backgroundPlayer.play(
      AssetSource(_backgroundAsset),
      volume: _backgroundVolume,
    );
  }

  Future<void> stop() async {
    if (!_initialized) {
      return;
    }

    await _backgroundPlayer.stop();
  }

  Future<void> dispose() async {
    if (!_initialized) {
      return;
    }

    await _backgroundPlayer.dispose();
    _initialized = false;
  }
}
