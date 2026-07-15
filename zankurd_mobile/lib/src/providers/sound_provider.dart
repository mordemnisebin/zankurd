import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

class SoundProvider extends ChangeNotifier {
  // Sync default constructor — MultiProvider fallback ve testler için.
  SoundProvider() : _enabled = true, _playerFactory = null;

  SoundProvider._({required this._enabled, this._playerFactory});

  static const _enabledKey = 'zankurd.sound.enabled';

  AudioPlayer? _player;
  final AudioPlayer Function()? _playerFactory;
  bool _enabled;

  bool get enabled => _enabled;

  /// SharedPreferences'ten önceki ayarı okuyarak başlatır.
  static Future<SoundProvider> load({AudioPlayer? player}) async {
    final prefs = await SharedPreferences.getInstance();
    return SoundProvider._(
      enabled: prefs.getBool(_enabledKey) ?? true,
      playerFactory: () => player ?? AudioPlayer(),
    );
  }

  /// Ses ayarını tersine çevirir ve kalıcı olarak kaydeder.
  Future<void> toggle() async {
    _enabled = !_enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, _enabled);
  }

  Future<void> playCorrect() => _play('sounds/correct.mp3');
  Future<void> playWrong() => _play('sounds/wrong.mp3');
  Future<void> playWin() => _play('sounds/win.mp3');
  Future<void> playCoin() => _play('sounds/coin.mp3');
  Future<void> playWildcard() => _play('sounds/wildcard.mp3');
  Future<void> playTick() => _play('sounds/coin.mp3');

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    if (kIsWeb) return;
    try {
      final playerFactory = _playerFactory;
      if (_player == null && playerFactory != null) {
        _player = playerFactory();
      }
      if (_player != null) {
        await _player!.play(AssetSource(asset));
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'sound_provider');
      // Platform ses desteği yoksa veya dosya eksikse sessizce geç.
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }
}
