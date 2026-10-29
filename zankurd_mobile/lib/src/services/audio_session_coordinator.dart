import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import '../utils/error_reporter.dart';
import 'app_audio_contexts.dart';

/// Uygulamanın TEK ses oturumu koordinatörü.
///
/// Astra incelemesi (F1, 2026-10-29, ÖNEMLİ): iOS'ta ses oturumu geneldir.
/// Her oynatıcının çalmadan önce kendi bağlamını kurması yetmiyordu:
///
/// * telaffuz sürerken bir efekt oturumu `ambient`e çekiyordu → sessiz
///   anahtar açıkken telaffuz da susuyor, dış müziğin kısılması kalkıyordu;
/// * ters sırada efektin `setAudioContext` ile `play` arasına telaffuzun
///   `playback` ayarı girerse efekt sessiz anahtarı yok sayıyordu.
///
/// Kurallar:
/// 1. Telaffuz/kayıt ([acquireSpeech] → [SpeechToken.release]) AKTİFKEN
///    efekt çalınmaz — atlanır, kuyruğa alınmaz.
/// 2. Son belirteç bırakılınca oturum `ambient`e döner.
/// 3. Bağlam geçişi + çalma bir KRİTİK BÖLGEdir: istekler sırayla yürür.
///
/// Astra fd886658 incelemesi: oturum bir boolean ile izleniyordu; başlangıç
/// beklerken gelen stop/dispose kapanışı kaçırıyor, eşzamanlı iki play sayacı
/// iki artırıp bir azaltıyordu (kalıcı `speechActive`). Artık oturum,
/// başlangıçtan ÖNCE alınan ve TAM BİR KEZ bırakılan bir belirteçtir.
class AudioSessionCoordinator {
  AudioSessionCoordinator({
    Future<void> Function(AudioContext ctx)? setGlobalContext,
  }) : _setGlobal = setGlobalContext ?? AudioPlayer.global.setAudioContext;

  /// Uygulama genelinde paylaşılan örnek.
  static AudioSessionCoordinator instance = AudioSessionCoordinator();

  final Future<void> Function(AudioContext ctx) _setGlobal;
  Future<void> _tail = Future<void>.value();
  int _held = 0;

  /// Telaffuz/kayıt oturumu tutuluyor mu?
  bool get speechActive => _held > 0;

  /// [action]'ı öncekiler bittikten sonra, tek başına yürütür.
  Future<T> _locked<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  /// Efekt: telaffuz yoksa efekt bağlamını kurar ve çalar; varsa atlar.
  /// Çalındıysa `true`.
  Future<bool> playEffect(AudioPlayer player, Source source) =>
      _locked(() async {
        if (speechActive) return false;
        try {
          await player.setAudioContext(AppAudioContexts.effects);
          await player.play(source);
          return true;
        } catch (error, stack) {
          ErrorReporter.record(error, stack, reason: 'audio_session_effect');
          return false;
        }
      });

  /// Telaffuz oturumunu HEMEN sahiplenir (eşzamanlı; başlangıçtan önce).
  /// Bu andan sonra gelen efektler atlanır.
  SpeechToken acquireSpeech() {
    _held++;
    return SpeechToken._(this);
  }

  /// [token] hâlâ geçerliyse oturumu `playback`e çevirir ve [start]'ı aynı
  /// kritik bölgede yürütür. Belirteç bu arada bırakıldıysa (stop, dispose)
  /// hiçbir şey yapılmaz. Hata olursa belirteç bırakılır ve hata iletilir.
  Future<void> startSpeech(
    SpeechToken token,
    AudioPlayer player,
    Future<void> Function() start,
  ) => _locked(() async {
    if (token.released) return;
    try {
      await player.setAudioContext(AppAudioContexts.speech);
      if (token.released) return;
      await start();
    } catch (_) {
      token._releaseLocked();
      if (_held == 0) await _restoreAmbient();
      rethrow;
    }
  });

  Future<void> _release() => _locked(() async {
    if (_held == 0) await _restoreAmbient();
  });

  Future<void> _restoreAmbient() async {
    try {
      await _setGlobal(AppAudioContexts.effects);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'audio_session_restore');
    }
  }
}

/// Bir telaffuz oturumunun sahipliği. [release] idempotenttir: kaç kez
/// çağrılırsa çağrılsın sayaç bir kez azalır.
class SpeechToken {
  SpeechToken._(this._owner);

  final AudioSessionCoordinator _owner;
  bool _released = false;

  bool get released => _released;

  /// Sayacı EŞZAMANLI azaltır (sonraki efekt kontrolü hemen görür); oturum
  /// son belirteçse kilit içinde `ambient`e döner.
  Future<void> release() {
    if (_released) return Future<void>.value();
    _released = true;
    _owner._held--;
    return _owner._release();
  }

  /// Kilit içinden çağrılır: yalnız sayacı düşürür (geri dönüşü çağıran
  /// yapar; kilit içinde yeniden kilit beklenmez).
  void _releaseLocked() {
    if (_released) return;
    _released = true;
    _owner._held--;
  }
}

/// Tek bir telaffuz oynatıcısının oturum yaşam döngüsü.
///
/// * play/stop/dispose bu oynatıcı için SIRALIDIR;
/// * her çalış yeni bir NESİLdir (kendi belirteci); doğal bitiş yalnız o
///   neslin belirtecini bırakır. Bitiş sayılmadan önce o neslin `playing`
///   olayı görülmüş olmalıdır: önceki çalışın geç gelen `completed` olayı
///   (akış sırası korunur, yeni `playing`den ÖNCE gelir) yeni oturumu
///   kapatamaz;
/// * dispose bekleyen başlangıcı iptal eder ve belirteci bırakır.
class SpeechPlaybackGuard {
  SpeechPlaybackGuard(this.player) {
    _sub = player.onPlayerStateChanged.listen(_onState);
  }

  final AudioPlayer player;
  late final StreamSubscription<PlayerState> _sub;
  Future<void> _chain = Future<void>.value();
  bool _sawPlaying = false;
  SpeechToken? _token;
  bool _disposed = false;

  AudioSessionCoordinator get _c => AudioSessionCoordinator.instance;

  Future<void> _serial(Future<void> Function() action) {
    final result = _chain.then((_) => action());
    _chain = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  void _onState(PlayerState state) {
    if (state == PlayerState.playing) {
      _sawPlaying = true;
      return;
    }
    if (state == PlayerState.completed && _sawPlaying) {
      final token = _token;
      _token = null;
      _sawPlaying = false;
      if (token != null) unawaited(token.release());
    }
  }

  Future<void> _releaseCurrent() async {
    final token = _token;
    _token = null;
    _sawPlaying = false;
    if (token != null) await token.release();
  }

  /// Durdurma dönemi: [stop]/[dispose] çağrıldığı AN artar. Bir [play]
  /// çağrıldığı andaki dönemi yakalar; dönem değiştiyse (arada stop/dispose
  /// geldiyse) başlangıç iptal olur — kuyrukta beklese bile.
  int _epoch = 0;

  /// Önceki çalışı bırakır, yeni nesil için oturumu sahiplenir ve [start]'ı
  /// `playback` bağlamında yürütür.
  Future<void> play(Future<void> Function() start) {
    final epoch = _epoch;
    return _serial(() async {
      if (_disposed || epoch != _epoch) return;
      await player.stop();
      await _releaseCurrent();
      if (_disposed || epoch != _epoch) return;
      final token = _c.acquireSpeech();
      _token = token;
      try {
        await _c.startSpeech(token, player, () async {
          if (epoch != _epoch) return;
          await start();
        });
      } catch (_) {
        if (identical(_token, token)) _token = null;
        await token.release();
        rethrow;
      }
    });
  }

  /// Durdurur. Belirteç ÇAĞRI ANINDA bırakılır: başlangıç koordinatör
  /// kuyruğunda bekliyorsa iptal olur ve oturum açılmaz.
  Future<void> stop() {
    _epoch++;
    final release = _releaseCurrent();
    return _serial(() async {
      await release;
      await player.stop();
    });
  }

  /// Bekleyen başlangıcı iptal eder (belirteç hemen bırakılır), sonra
  /// oynatıcıyı kapatır.
  Future<void> dispose() {
    if (_disposed) return Future<void>.value();
    _disposed = true;
    _epoch++;
    final release = _releaseCurrent();
    return _serial(() async {
      await release;
      await _sub.cancel();
      await player.dispose();
    });
  }
}
