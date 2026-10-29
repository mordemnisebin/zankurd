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
/// 1. Telaffuz/kayıt ([beginSpeech] … [endSpeech]) AKTİFKEN efekt çalınmaz —
///    atlanır, kuyruğa alınmaz (geç gelen "doğru" sesi anlamsızdır).
/// 2. Son telaffuz bitince oturum `ambient`e döner.
/// 3. Bağlam geçişi + çalma bir KRİTİK BÖLGEdir: istekler sırayla, birbirinin
///    arasına girmeden yürür.
class AudioSessionCoordinator {
  AudioSessionCoordinator({
    Future<void> Function(AudioContext ctx)? setGlobalContext,
  }) : _setGlobal = setGlobalContext ?? AudioPlayer.global.setAudioContext;

  /// Uygulama genelinde paylaşılan örnek.
  static AudioSessionCoordinator instance = AudioSessionCoordinator();

  final Future<void> Function(AudioContext ctx) _setGlobal;
  Future<void> _tail = Future<void>.value();
  int _speech = 0;

  /// Telaffuz/kayıt şu an çalıyor mu?
  bool get speechActive => _speech > 0;

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

  /// Telaffuz/kayıt başlar: oturum `playback`e geçer, [start] (kaynak +
  /// çalma) aynı kritik bölgede yürür. Çağıran, ses bitince/durunca TAM
  /// BİR KEZ [endSpeech] çağırır.
  Future<void> beginSpeech(AudioPlayer player, Future<void> Function() start) =>
      _locked(() async {
        _speech++;
        try {
          await player.setAudioContext(AppAudioContexts.speech);
          await start();
        } catch (_) {
          _speech--;
          if (_speech == 0) await _restoreAmbient();
          rethrow;
        }
      });

  /// Telaffuz/kayıt bitti; sonuncusuysa oturum `ambient`e döner.
  Future<void> endSpeech() => _locked(() async {
    if (_speech == 0) return;
    _speech--;
    if (_speech == 0) await _restoreAmbient();
  });

  Future<void> _restoreAmbient() async {
    try {
      await _setGlobal(AppAudioContexts.effects);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'audio_session_restore');
    }
  }
}
