import 'package:flutter/foundation.dart';

import 'tts_service.dart';

/// Ders dinleme alıştırmasının ihtiyaç duyduğu en küçük ses sözleşmesi.
///
/// Üretimde yalnız cihazda gerçekten kurulu Kurmancî (`ku`) TTS sesi
/// kullanılabilir. Türkçe/Soranî sesini Kurmancî telaffuz yerine geçirmek
/// bu sözleşmenin parçası değildir.
abstract interface class LessonListeningSpeaker {
  bool get available;
  ValueListenable<bool> get speakingListenable;

  Future<void> speak(String text);
  Future<void> stop();
}

class TtsLessonListeningSpeaker implements LessonListeningSpeaker {
  const TtsLessonListeningSpeaker(this._tts);

  final TtsService _tts;

  static Future<TtsLessonListeningSpeaker> load() async {
    return TtsLessonListeningSpeaker(await TtsService.load());
  }

  @override
  bool get available => _tts.isKurdishAvailable && _tts.isEnabled;

  @override
  ValueListenable<bool> get speakingListenable => _tts.speakingNotifier;

  @override
  Future<void> speak(String text) => _tts.speak(text);

  @override
  Future<void> stop() => _tts.stop();
}
