import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_audio_contexts.dart';
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

  // Kapışma U17 (2026-10-29): `win` `correct`'in, `wildcard` `coin`'in
  // bayt bayt kopyasıydı; geri sayım tıkı 2 saniyelik jeton sesini çalıyordu.
  // Yeni üç ses `tool/sounds/sentez.py` ile üretildi (assets/sounds/KAYNAK.md).
  Future<void> playCorrect() => _play(SoundAssets.correct);
  Future<void> playWrong() => _play(SoundAssets.wrong);
  Future<void> playWin() => _play(SoundAssets.win);
  Future<void> playCoin() => _play(SoundAssets.coin);
  Future<void> playWildcard() => _play(SoundAssets.wildcard);
  Future<void> playTick() => _play(SoundAssets.tick);

  Future<void> _play(String asset) async {
    if (!_enabled) return;
    if (kIsWeb) return;
    try {
      final playerFactory = _playerFactory;
      if (_player == null && playerFactory != null) {
        _player = playerFactory();
      }
      final player = _player;
      if (player != null) {
        // Bağlam HER çalışta kurulur: iOS'ta ses oturumu geneldir ve
        // telaffuz oynatıcısı onu `playback`e çeker; efekt yeniden
        // `ambient`e dönmezse sessiz anahtarı yok sayar, dış müziği keser
        // (kapışma U16, bkz. [AppAudioContexts]).
        await player.setAudioContext(AppAudioContexts.effects);
        await player.play(AssetSource(asset));
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

/// Efekt ses dosyaları (`assets/` önekisiz, `AssetSource` biçiminde).
abstract final class SoundAssets {
  static const correct = 'sounds/correct.mp3';
  static const wrong = 'sounds/wrong.mp3';
  static const win = 'sounds/win.mp3';
  static const coin = 'sounds/coin.mp3';
  static const wildcard = 'sounds/wildcard.mp3';
  static const tick = 'sounds/tick.mp3';

  static const all = [correct, wrong, win, coin, wildcard, tick];
}
