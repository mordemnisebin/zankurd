import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/error_reporter.dart';
import 'question_audio_service.dart';
import 'recorded_clip_catalog.dart';
import 'tts_service.dart';

/// Ders dinleme alıştırmasının ve sözlüğün ihtiyaç duyduğu en küçük ses
/// sözleşmesi.
///
/// Ses iki kaynaktan gelir: ana dili Kurmancî olanların kayıtları
/// ([RecordedClipCatalog]) ve cihazda gerçekten kurulu Kurmancî (`ku`) TTS
/// sesi. Türkçe/Soranî sesini Kurmancî telaffuz yerine geçirmek bu
/// sözleşmenin parçası değildir.
abstract interface class LessonListeningSpeaker {
  /// En az bir ifade seslendirilebiliyor mu (kayıt var ya da TTS var).
  bool get available;

  /// [text] için kayıt var ya da `ku` TTS kullanılabilir mi. Kayıt ifade
  /// başınadır; arayüz ses düğmesini bu değere göre gösterir.
  bool availableFor(String text);

  ValueListenable<bool> get speakingListenable;

  /// [slow]: öğrenen için yavaş çalma ("kaplumbağa"). Kayıt
  /// [kSlowPlaybackRate] hızla, TTS [kSlowSpeechFactor] kat yavaş okunur.
  ///
  /// Dönüş: ses GERÇEKTEN başlatıldıysa `true`. Kayıt çalmadı ve TTS de yoksa
  /// `false`: eskiden hatasız dönüyordu ve dinleme kartı bunu "dinlendi"
  /// sayıp kullanıcıyı duymadığı sesin anlamını seçmeye yönlendiriyordu
  /// (Codex denetimi 2026-10-29).
  Future<bool> speak(String text, {bool slow = false});
  Future<void> stop();
}

/// Yavaş dinlemede kaydın çalma hızı. 0,7'nin altında kayıt bozulmaya
/// (perde/yankı) başlıyor; Duolingo'nun kaplumbağası da bu civarda.
const double kSlowPlaybackRate = 0.7;

/// Yavaş dinlemede TTS konuşma hızı çarpanı (kullanıcının hız ayarına göre).
const double kSlowSpeechFactor = 0.6;

class TtsLessonListeningSpeaker implements LessonListeningSpeaker {
  const TtsLessonListeningSpeaker(this._tts);

  final TtsService _tts;

  static Future<TtsLessonListeningSpeaker> load() async {
    return TtsLessonListeningSpeaker(await TtsService.load());
  }

  @override
  bool get available => _tts.isKurdishAvailable && _tts.isEnabled;

  @override
  bool availableFor(String text) => available;

  @override
  ValueListenable<bool> get speakingListenable => _tts.speakingNotifier;

  @override
  Future<bool> speak(String text, {bool slow = false}) async {
    if (!available) return false;
    await _tts.speak(text, rateFactor: slow ? kSlowSpeechFactor : 1.0);
    return true;
  }

  @override
  Future<void> stop() => _tts.stop();
}

/// Önce kayıt, yoksa `ku` TTS.
///
/// ## Niçin var
///
/// Cihazlarda Kurmancî TTS sesi neredeyse hiç kurulu değil (iPhone ve
/// çoğu Android); yalnız TTS'e bağlı seslendirme fiilen ölüydü. Sıra:
/// kayıt > TTS > yok. Kayıt çalmazsa (dosya eksik, çözücü hatası) hata
/// yazılır ve TTS varsa ona düşülür.
class RecordedFirstLessonListeningSpeaker implements LessonListeningSpeaker {
  RecordedFirstLessonListeningSpeaker({
    required this.catalog,
    required this.player,
    required this.fallback,
  }) {
    fallback.speakingListenable.addListener(_sync);
    player.playingListenable.addListener(_sync);
    _sync();
  }

  final RecordedClipCatalog catalog;
  final VerifiedQuestionAudioPlayer player;
  final LessonListeningSpeaker fallback;
  final ValueNotifier<bool> _speaking = ValueNotifier(false);

  @override
  bool get available => !catalog.isEmpty || fallback.available;

  @override
  bool availableFor(String text) =>
      catalog.clipForText(text) != null || fallback.availableFor(text);

  @override
  ValueListenable<bool> get speakingListenable => _speaking;

  @override
  Future<bool> speak(String text, {bool slow = false}) async {
    final clip = catalog.clipForText(text);
    if (clip != null) {
      try {
        await fallback.stop();
        await player.play(
          clip.toVerifiedClip(),
          rate: slow ? kSlowPlaybackRate : 1.0,
        );
        return true;
      } catch (error, stack) {
        ErrorReporter.record(
          error,
          stack,
          reason: 'recorded clip playback failed',
        );
      }
    }
    if (fallback.availableFor(text)) {
      await player.stop();
      return fallback.speak(text, slow: slow);
    }
    return false;
  }

  @override
  Future<void> stop() async {
    await Future.wait([fallback.stop(), player.stop()]);
  }

  void _sync() {
    _speaking.value = fallback.speakingListenable.value || player.isPlaying;
  }
}

/// Uygulama boyunca paylaşılan ders/sözlük seslendiricisi.
///
/// Ders ekranı, sözlük listesi ve kelime balonu aynı örneği kullanır; böylece
/// katalog bir kez okunur ve aynı anda iki ses çalmaz.
class LessonAudio {
  const LessonAudio._();

  static Future<LessonListeningSpeaker>? _future;
  static LessonListeningSpeaker? _loaded;

  /// Yüklenmişse hemen verilir (liste satırları beklemesin).
  static LessonListeningSpeaker? get loaded => _loaded;

  static Future<LessonListeningSpeaker> shared() =>
      _future ??= _createOrReset();

  static Future<LessonListeningSpeaker> _createOrReset() async {
    try {
      return await _create();
    } catch (_) {
      // Kalıcı hata önbelleğe alınmaz; sonraki çağrı yeniden dener.
      _future = null;
      rethrow;
    }
  }

  static Future<LessonListeningSpeaker> _create() async {
    final catalog = await RecordedClipCatalog.shared();
    final tts = await TtsLessonListeningSpeaker.load();
    final speaker = RecordedFirstLessonListeningSpeaker(
      catalog: catalog,
      // Kayıt yokken ses motoru hiç kurulmaz.
      player: catalog.isEmpty
          ? NoopVerifiedQuestionAudioPlayer()
          : AudioplayersVerifiedQuestionAudioPlayer(),
      fallback: tts,
    );
    return _loaded = speaker;
  }

  @visibleForTesting
  static void overrideForTesting(LessonListeningSpeaker? speaker) {
    _loaded = speaker;
    _future = speaker == null ? null : Future.value(speaker);
  }
}
