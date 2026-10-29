import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/quiz_question.dart';
import '../utils/error_reporter.dart';
import 'tts_service.dart';
import 'audio_session_coordinator.dart';

enum VerifiedAudioLocation { asset, network }

enum QuestionAudioKind { verifiedNative, kurmanjiTts, unavailable }

class VerifiedQuestionAudioClip {
  VerifiedQuestionAudioClip({
    required this.questionId,
    required this.source,
    required this.location,
    required this.provenance,
    required this.license,
  }) {
    if (questionId.trim().isEmpty ||
        source.trim().isEmpty ||
        provenance.trim().isEmpty ||
        license.trim().isEmpty) {
      throw ArgumentError(
        'Verified audio requires question id, source, provenance and license.',
      );
    }
  }

  final String questionId;
  final String source;
  final VerifiedAudioLocation location;
  final String provenance;
  final String license;
}

class VerifiedQuestionAudioCatalog {
  VerifiedQuestionAudioCatalog(Iterable<VerifiedQuestionAudioClip> clips)
    : _byQuestionId = {for (final clip in clips) clip.questionId.trim(): clip};

  VerifiedQuestionAudioCatalog._empty() : _byQuestionId = const {};

  static final empty = VerifiedQuestionAudioCatalog._empty();

  final Map<String, VerifiedQuestionAudioClip> _byQuestionId;

  bool get isEmpty => _byQuestionId.isEmpty;

  VerifiedQuestionAudioClip? clipFor(String questionId) =>
      _byQuestionId[questionId.trim()];
}

class QuestionAudioSelection {
  const QuestionAudioSelection._(this.kind, this.clip);

  const QuestionAudioSelection.verified(VerifiedQuestionAudioClip clip)
    : this._(QuestionAudioKind.verifiedNative, clip);

  const QuestionAudioSelection.tts()
    : this._(QuestionAudioKind.kurmanjiTts, null);

  const QuestionAudioSelection.unavailable()
    : this._(QuestionAudioKind.unavailable, null);

  final QuestionAudioKind kind;
  final VerifiedQuestionAudioClip? clip;
}

class QuestionAudioResolver {
  const QuestionAudioResolver({required this.catalog});

  final VerifiedQuestionAudioCatalog catalog;

  QuestionAudioSelection resolve(
    QuizQuestion question, {
    required bool kurmanjiTtsAvailable,
  }) {
    final verified = catalog.clipFor(question.id);
    if (verified != null) return QuestionAudioSelection.verified(verified);
    if (kurmanjiTtsAvailable) return const QuestionAudioSelection.tts();
    return const QuestionAudioSelection.unavailable();
  }
}

abstract interface class QuestionAudioTts {
  bool get available;
  bool get isPlaying;
  ValueListenable<bool> get playingListenable;

  Future<void> speak(String text);
  Future<void> stop();
}

class TtsQuestionAudioAdapter implements QuestionAudioTts {
  const TtsQuestionAudioAdapter(this._tts);

  final TtsService _tts;

  @override
  bool get available => _tts.isKurdishAvailable && _tts.isEnabled;

  @override
  bool get isPlaying => _tts.isSpeaking;

  @override
  ValueListenable<bool> get playingListenable => _tts.speakingNotifier;

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}

abstract interface class VerifiedQuestionAudioPlayer {
  bool get isPlaying;
  ValueListenable<bool> get playingListenable;

  /// [rate]: çalma hızı (1 = normal; yavaş dinleme için daha küçük).
  Future<void> play(VerifiedQuestionAudioClip clip, {double rate = 1.0});
  Future<void> stop();
  void dispose();
}

class AudioplayersVerifiedQuestionAudioPlayer
    implements VerifiedQuestionAudioPlayer {
  /// Ses motoru ilk [play]'de kurulur. 2026-10-22'de sözlük sesleri
  /// paketlenince oynatıcı ekran açılır açılmaz kuruluyordu: kimse dinlemese
  /// de platform kanalı açılıyor, test koşucusunda da (eklenti yok)
  /// `MissingPluginException` atıyordu (ekran turu, öğrenen sözlüğü).
  AudioplayersVerifiedQuestionAudioPlayer({AudioPlayer? player})
    : _injected = player;

  final AudioPlayer? _injected;
  AudioPlayer? _created;
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  StreamSubscription<PlayerState>? _stateSubscription;
  bool _disposed = false;

  SpeechPlaybackGuard? _guard;

  AudioPlayer get _player {
    final existing = _created;
    if (existing != null) return existing;
    final player = _injected ?? AudioPlayer();
    // Oturum (playback ↔ ambient) koruyucuda; bu dinleyici yalnız arayüzün
    // "çalıyor" durumunu taşır.
    _guard = SpeechPlaybackGuard(player);
    _stateSubscription = player.onPlayerStateChanged.listen((state) {
      if (_disposed) return;
      _playing.value = state == PlayerState.playing;
    });
    return _created = player;
  }

  @override
  bool get isPlaying => _playing.value;

  @override
  ValueListenable<bool> get playingListenable => _playing;

  @override
  Future<void> play(VerifiedQuestionAudioClip clip, {double rate = 1.0}) async {
    final source = switch (clip.location) {
      VerifiedAudioLocation.asset => AssetSource(
        clip.source.startsWith('assets/')
            ? clip.source.substring('assets/'.length)
            : clip.source,
      ),
      VerifiedAudioLocation.network => UrlSource(clip.source),
    };
    // Oynatıcı paylaşılır: hız her çalışta yeniden kurulur, yoksa bir
    // yavaş dinlemeden sonra normal ses de yavaş kalırdı.
    final player = _player;
    // Telaffuz bilerek dinlenir: sessiz anahtarda da duyulur (playback).
    // iOS oturumu genel olduğundan geçiş tek koordinatörden yapılır; bu ses
    // sürerken efektler atlanır, bitince oturum ambient'e döner (kapışma U16
    // + Astra F1 ve fd886658 incelemeleri). Sahiplik, nesil ve sıra
    // [SpeechPlaybackGuard]'da.
    await _guard!.play(() async {
      await player.setSource(source);
      await player.setPlaybackRate(rate);
      await player.resume();
    });
  }

  @override
  Future<void> stop() async {
    _playing.value = false;
    final guard = _guard;
    if (guard != null) await guard.stop();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_stateSubscription?.cancel());
    // Koruyucu bekleyen başlangıcı iptal eder, belirteci bırakır ve
    // oynatıcıyı kapatır.
    final guard = _guard;
    if (guard != null) unawaited(guard.dispose());
    _playing.dispose();
  }
}

class NoopVerifiedQuestionAudioPlayer implements VerifiedQuestionAudioPlayer {
  final ValueNotifier<bool> _playing = ValueNotifier(false);

  @override
  bool get isPlaying => false;

  @override
  ValueListenable<bool> get playingListenable => _playing;

  @override
  Future<void> play(
    VerifiedQuestionAudioClip clip, {
    double rate = 1.0,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {
    _playing.dispose();
  }
}

/// Uygulamada doğrulanmış insan sesi olarak kabul edilen tek kaynak.
///
/// Yeni kayıt ancak köken ve lisans bilgisi doğrulandıktan sonra bu kataloğa
/// eklenir. `QuizQuestion.audioUrl` tek başına doğrulama sinyali değildir.
final verifiedQuestionAudioCatalog = VerifiedQuestionAudioCatalog.empty;

class QuestionAudioService {
  factory QuestionAudioService({
    required QuestionAudioResolver resolver,
    required QuestionAudioTts tts,
    required VerifiedQuestionAudioPlayer verifiedPlayer,
  }) => QuestionAudioService._(
    resolver: resolver,
    tts: tts,
    verifiedPlayer: verifiedPlayer,
  );

  QuestionAudioService._({
    required this.resolver,
    required this._tts,
    required this._verifiedPlayer,
  }) {
    _tts.playingListenable.addListener(_syncPlaying);
    _verifiedPlayer.playingListenable.addListener(_syncPlaying);
    _syncPlaying();
  }

  final QuestionAudioResolver resolver;
  final QuestionAudioTts _tts;
  final VerifiedQuestionAudioPlayer _verifiedPlayer;
  final ValueNotifier<bool> _playing = ValueNotifier(false);
  bool _disposed = false;

  static Future<QuestionAudioService> load({
    VerifiedQuestionAudioCatalog? catalog,
  }) async {
    final resolvedCatalog = catalog ?? verifiedQuestionAudioCatalog;
    final tts = await TtsService.load();
    return QuestionAudioService(
      resolver: QuestionAudioResolver(catalog: resolvedCatalog),
      tts: TtsQuestionAudioAdapter(tts),
      verifiedPlayer: resolvedCatalog.isEmpty
          ? NoopVerifiedQuestionAudioPlayer()
          : AudioplayersVerifiedQuestionAudioPlayer(),
    );
  }

  bool get isPlaying => _playing.value;
  ValueListenable<bool> get playingListenable => _playing;

  QuestionAudioSelection selectionFor(QuizQuestion question) =>
      resolver.resolve(question, kurmanjiTtsAvailable: _tts.available);

  bool canPlay(QuizQuestion question) =>
      selectionFor(question).kind != QuestionAudioKind.unavailable;

  Future<void> toggle(QuizQuestion question) async {
    if (_disposed) return;
    if (isPlaying) {
      await stop();
      return;
    }

    final selection = selectionFor(question);
    switch (selection.kind) {
      case QuestionAudioKind.verifiedNative:
        try {
          await _verifiedPlayer.play(selection.clip!);
        } catch (error, stack) {
          ErrorReporter.record(
            error,
            stack,
            reason: 'verified question audio playback failed',
          );
          if (_tts.available) {
            await _tts.speak(question.promptText);
          }
        }
      case QuestionAudioKind.kurmanjiTts:
        await _tts.speak(question.promptText);
      case QuestionAudioKind.unavailable:
        return;
    }
    _syncPlaying();
  }

  Future<void> stop() async {
    if (_disposed) return;
    await Future.wait([_tts.stop(), _verifiedPlayer.stop()]);
    _syncPlaying();
  }

  void _syncPlaying() {
    if (_disposed) return;
    _playing.value = _tts.isPlaying || _verifiedPlayer.isPlaying;
  }

  void dispose() {
    if (_disposed) return;
    _tts.playingListenable.removeListener(_syncPlaying);
    _verifiedPlayer.playingListenable.removeListener(_syncPlaying);
    _disposed = true;
    unawaited(_tts.stop());
    _verifiedPlayer.dispose();
    _playing.dispose();
  }
}
