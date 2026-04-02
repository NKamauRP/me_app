import 'package:audioplayers/audioplayers.dart';

import 'theme_service.dart';

class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  static const String _tapAsset = 'sounds/tap.mp3';
  static const String _successAsset = 'sounds/chime.mp3';
  static const String _rewardAsset = 'sounds/reward.mp3';

  final AudioPlayer _tapPlayer = AudioPlayer()..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _successPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);
  final AudioPlayer _rewardPlayer = AudioPlayer()
    ..setPlayerMode(PlayerMode.lowLatency);

  bool get _enabled => ThemeService.instance.soundEnabled;

  Future<void> playTap() => _play(_tapPlayer, _tapAsset);

  Future<void> playSuccess() => _play(_successPlayer, _successAsset);

  Future<void> playReward() => _play(_rewardPlayer, _rewardAsset);

  Future<void> _play(AudioPlayer player, String assetPath) async {
    if (!_enabled) {
      return;
    }

    await player.stop();
    await player.play(AssetSource(assetPath));
  }

  Future<void> dispose() async {
    await _tapPlayer.dispose();
    await _successPlayer.dispose();
    await _rewardPlayer.dispose();
  }
}
