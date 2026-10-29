import 'package:audioplayers/audioplayers.dart';

/// Uygulamanın iki ses türünün platform ses bağlamları.
///
/// Kapışma U16 (2026-10-29): efekt oynatıcısı audioplayers'ın varsayılan
/// bağlamıyla çalıyordu — iOS'ta `playback` kategorisi, seçeneksiz. Sonuç:
/// doğru/yanlış/jeton efektleri telefonun SESSİZ ANAHTARINI yok sayıyor ve
/// kullanıcının çalan müziğini/podcast'ini KESİYORDU. Oyun efektleri
/// "ortam" sesidir: sessiz anahtara uyar, dış sesle karışır.
///
/// Telaffuz ve ders dinleme ise kullanıcının bilerek bastığı içeriktir;
/// sessiz anahtar açıkken de duyulmalıdır (`playback`). iOS'ta ses
/// oturumu GENELdir (audioplayers_darwin: "iOS does not allow for
/// player-specific audio contexts"), bu yüzden her oynatıcı ÇALMADAN HEMEN
/// ÖNCE kendi bağlamını kurar; efekt bağlamı telaffuza sızmaz.
abstract final class AppAudioContexts {
  /// Oyun efektleri: iOS `ambient` (sessiz anahtara uyar ve doğası gereği
  /// dış sesle KARIŞIR — Apple bu kategoride `mixWithOthers` seçeneğini
  /// ayrıca kabul etmez, audioplayers da assert'le reddeder); Android oyun
  /// kullanımı, ses odağı istemez (dış ses durmaz).
  static final AudioContext effects = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );

  /// Telaffuz / ders sesi: iOS playback (sessiz anahtarda da duyulur);
  /// Android medya sesi, geçici odak (dış ses kısa süre kısılır).
  static final AudioContext speech = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.duckOthers},
    ),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );
}
