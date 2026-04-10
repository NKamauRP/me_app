import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_service.dart';

class AudioService with WidgetsBindingObserver {
  AudioService._();
  static final AudioService instance = AudioService._();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _sfxPlayer   = AudioPlayer();

  bool _musicEnabled = true;
  bool _sfxEnabled   = true;
  bool _isPlaying    = false;

  static const _musicEnabledKey = 'audio_music_enabled';
  static const _sfxEnabledKey   = 'audio_sfx_enabled';

  // ── Initialise ────────────────────────────────────────────────

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    _sfxEnabled   = prefs.getBool(_sfxEnabledKey)   ?? true;

    // Music plays on media volume channel
    await _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer.setVolume(0.4);
    await _sfxPlayer.setVolume(1.0);

    // Tap sounds use AudioContext to respect silent/ringer mode
    await _sfxPlayer.setAudioContext(
      AudioContext(
        android: AudioContextAndroid(
          audioFocus: AndroidAudioFocus.none,
          // RING stream respects silent mode switch
          audioMode: AndroidAudioMode.ringtone,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.notificationRingtone,
          stayAwake: false,
        ),
      ),
    );

    if (_musicEnabled) await startMusic();
  }

  // ── App lifecycle — pause on background, resume on foreground ─

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _pauseMusic();
        break;
      case AppLifecycleState.resumed:
        if (_musicEnabled) _resumeMusic();
        break;
      case AppLifecycleState.hidden:
        _pauseMusic();
        break;
    }
  }

  // ── Music controls ─────────────────────────────────────────────

  Future<void> startMusic() async {
    if (!_musicEnabled) return;
    await _musicPlayer.play(AssetSource('audio/ambient.mp3'));
    _isPlaying = true;
  }

  Future<void> _pauseMusic() async {
    if (_isPlaying) {
      await _musicPlayer.pause();
      _isPlaying = false;
    }
  }

  Future<void> _resumeMusic() async {
    if (!_isPlaying && _musicEnabled) {
      await _musicPlayer.resume();
      _isPlaying = true;
    }
  }

  Future<void> stopMusic() async {
    await _musicPlayer.stop();
    _isPlaying = false;
  }

  // Legacy support or internal update
  Future<void> updatePlaybackPreference() async {
     final prefs = await SharedPreferences.getInstance();
     final enabled = prefs.getBool(_musicEnabledKey) ?? true;
     await setMusicEnabled(enabled);
  }

  // ── Tap sound ──────────────────────────────────────────────────

  /// Play a short tap sound that respects silent mode.
  Future<void> playTap() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/tap.mp3'));
    } catch (_) {
      // Silent fail — never crash the app over a sound
    }
  }

  Future<void> playSuccess() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/chime.mp3'));
    } catch (_) {}
  }

  Future<void> playReward() async {
    if (!_sfxEnabled) return;
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.play(AssetSource('audio/reward.mp3'));
    } catch (_) {}
  }

  // ── Settings toggles ──────────────────────────────────────────

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, enabled);
    if (enabled) {
      await startMusic();
    } else {
      await stopMusic();
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sfxEnabledKey, enabled);
  }

  bool get isMusicEnabled => _musicEnabled;
  bool get isSfxEnabled   => _sfxEnabled;

  // ── Cleanup ────────────────────────────────────────────────────

  Future<void> dispose() async {
    WidgetsBinding.instance.removeObserver(this);
    await _musicPlayer.dispose();
    await _sfxPlayer.dispose();
  }
}
