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

/// Telaffuz çalışlarının oturum yaşam döngüsü.
///
/// Astra 48bf4b86 incelemesi: tek oynatıcı örneği paylaşıldığında önceki
/// çalışın geç gelen olayları yeni çalışın belirtecine ulaşabiliyordu ve
/// bekleyen başlangıcın iptali ile çalan sesin bırakılması aynı adımdı.
/// Yarış YAPISAL olarak kapatılır:
///
/// * HER çalış kendi [AudioPlayer] örneğini ve dinleyicisini alır; bitince ya
///   da durdurulunca o örnek kapatılır. Eski çalışın olayları ayrı örnekten
///   geldiği için yeni belirtece hiçbir yoldan ulaşamaz.
/// * İPTAL (bayrak) ile BIRAKMA (belirteç) ayrıdır: başlamış çalışın
///   belirteci, fiziksel stop + dispose TAMAMLANINCA bırakılır. Asenkron
///   hazırlıktan (setSource) sonra, `resume`dan hemen önce iptal yeniden
///   denetlenir; iptalse `resume` hiç çağrılmaz.
class SpeechPlaybackGuard {
  SpeechPlaybackGuard(this._createPlayer, {this.onState});

  final AudioPlayer Function() _createPlayer;

  /// Geçerli çalışın oynatıcı durumları (arayüzün "çalıyor" göstergesi).
  final void Function(PlayerState state)? onState;

  _SpeechRun? _current;
  bool _disposed = false;

  AudioSessionCoordinator get _c => AudioSessionCoordinator.instance;

  /// Önceki çalışı iptal eder ve kapatır; yeni bir örnekle [prepare]
  /// (kaynak, hız …) sonra `resume` yürütür. İptal edilmiş bir çalışın
  /// hataları yutulur.
  Future<void> play(Future<void> Function(AudioPlayer player) prepare) async {
    if (_disposed) return;
    final token = _c.acquireSpeech();
    final run = _SpeechRun(_createPlayer(), token);
    final previous = _current;
    _current = run;
    run.sub = run.player.onPlayerStateChanged.listen((state) {
      if (identical(_current, run)) onState?.call(state);
      if (state == PlayerState.completed) unawaited(run.finish());
    });
    if (previous != null) {
      previous.cancelled = true;
      await previous.finish();
    }
    try {
      await _c.startSpeech(token, run.player, () async {
        if (run.cancelled) return;
        await prepare(run.player);
        // Hazırlık asenkron: bu arada stop/dispose/yeni play gelmiş olabilir.
        if (run.cancelled) return;
        await run.player.resume();
      });
    } catch (_) {
      if (!run.cancelled) {
        await run.finish();
        rethrow;
      }
    }
    if (run.cancelled) await run.finish();
  }

  /// Geçerli çalışı iptal eder; belirteç fiziksel durdurma bitince bırakılır.
  Future<void> stop() async {
    final run = _current;
    _current = null;
    if (run == null) return;
    run.cancelled = true;
    onState?.call(PlayerState.stopped);
    await run.finish();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }
}

/// Bir telaffuz çalışı: kendi oynatıcı örneği, dinleyicisi ve belirteci.
class _SpeechRun {
  _SpeechRun(this.player, this.token);

  final AudioPlayer player;
  final SpeechToken token;
  StreamSubscription<PlayerState>? sub;
  bool cancelled = false;
  Future<void>? _finishing;

  /// Örneği durdurup kapatır, SONRA belirteci bırakır. TAM BİR KEZ.
  Future<void> finish() => _finishing ??= () async {
    await sub?.cancel();
    try {
      await player.stop();
    } catch (_) {}
    try {
      await player.dispose();
    } catch (_) {}
    await token.release();
  }();
}
