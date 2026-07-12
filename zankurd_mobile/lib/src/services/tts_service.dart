import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ZanKurd metin-okuma (TTS) servisi.
///
/// Soruları seslendirmek için kullanılır. Kürtçe dil desteği varsa onu,
/// yoksa Türkçeyi kullanır. Otomatik okuma ayarı SharedPreferences'te
/// `zankurd.tts_auto_read` anahtarı altında saklanır.
class TTSService {
  TTSService._(this._flutterTts, {required this._autoRead});

  static const _autoReadKey = 'zankurd.tts_auto_read';

  static Future<TTSService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final tts = FlutterTts();

    // Kürtçe TTS desteğini kontrol et, yoksa Türkçeye düş.
    // flutter_tts dil kodları: BCP-47
    await tts.setLanguage('ku-TR');
    // Kürtçe desteklenmiyorsa Türkçeye geç
    final lang = await tts.getLanguages;
    if (!lang.contains('ku-TR') && !lang.contains('ku')) {
      await tts.setLanguage('tr-TR');
    }

    // Konuşma hızı ve ses yüksekliği
    await tts.setSpeechRate(0.45); // yavaş ve anlaşılır
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);

    final autoRead = prefs.getBool(_autoReadKey) ?? false;

    return TTSService._(tts, autoRead: autoRead);
  }

  final FlutterTts _flutterTts;
  bool _autoRead;

  /// Otomatik okuma aktif mi?
  bool get autoRead => _autoRead;

  /// Otomatik okumayı aç/kapat.
  Future<void> setAutoRead(bool value) async {
    _autoRead = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoReadKey, value);
  }

  /// Metni seslendir.
  ///
  /// Halihazırda konuşma devam ediyorsa önce durdurur, sonra yenisini okur.
  Future<void> speak(String text) async {
    await _flutterTts.stop();
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  /// Konuşmayı durdur.
  Future<void> stop() async {
    await _flutterTts.stop();
  }

  /// Kaynakları serbest bırak.
  void dispose() {
    _flutterTts.stop();
  }
}
