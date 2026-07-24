import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Kürtçe (Kurmancî) soru ve şiroveleri seslendirmek için TTS servisi.
///
/// Android'de Google TTS motoru bazı Kürtçe locale'lerini (ku, ckb)
/// destekleyebilir; iOS yüzeyinde destek sınırlıdır. Destek yoksa
/// [isKurdishAvailable] false döner ve UI butonu gizlenir.
///
/// Singleton; [load] ile başlatılır, [instance] üzerinden çağrılır.
/// Konuşma hızı ve ses seviyesi ayarları SharedPreferences'te saklanır.
class TtsService {
  TtsService._(this._tts, this._prefs);

  static const _enabledKey = 'zankurd.tts.enabled';
  static const _rateKey = 'zankurd.tts.rate';
  static const _volumeKey = 'zankurd.tts.volume';
  static const _languageKey = 'zankurd.tts.language';

  static TtsService? _instance;

  static const _defaultRate = 0.5;
  static const _defaultVolume = 1.0;
  // Kürtçe kadar ckb (Soranî) ve ku (Kurmancî) ve Kürdistan Türkçe'sinden
  // önce TR de denenebilir; ama öncelikli olarak Kürtçe yazışım kullanılır.
  static const _candidateLocales = ['ku', 'ckb', 'ku-IQ', 'ku-TR', 'tr-TR'];

  final FlutterTts _tts;
  final SharedPreferences? _prefs;

  bool _kurdishAvailable = false;
  bool _enabled = true;
  double _rate = _defaultRate;
  double _volume = _defaultVolume;
  String _activeLanguage = 'tr-TR';

  /// Dinleme durumunu UI'a yaymak için ValueNotifier. true iken TTS
  /// aktif olarak konuşuyor; UI buton durumunu bu değere bağlar.
  final ValueNotifier<bool> speakingNotifier = ValueNotifier<bool>(false);

  static TtsService? get instance => _instance;

  bool get isKurdishAvailable => _kurdishAvailable;
  bool get isEnabled => _enabled;
  double get rate => _rate;
  double get volume => _volume;
  String get activeLanguage => _activeLanguage;
  bool get isSpeaking => speakingNotifier.value;

  /// Servisi başlat. Web'de TTS çalışmaz — [FlutterTts] yine de güvenli
  /// şekilde instantiate olur ama konuşma sessizce başarısız olur.
  static Future<TtsService> load() async {
    final cached = _instance;
    if (cached != null) return cached;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts_service prefs');
    }

    final tts = FlutterTts();
    final service = TtsService._(tts, prefs);
    await service._initialize();
    return _instance = service;
  }

  static void resetInstance() {
    _instance?.speakingNotifier.dispose();
    _instance?._dispose();
    _instance = null;
  }

  Future<void> _initialize() async {
    try {
      _enabled = _prefs?.getBool(_enabledKey) ?? true;
      _rate = (_prefs?.getDouble(_rateKey) ?? _defaultRate).clamp(0.0, 1.0)
          .toDouble();
      _volume = (_prefs?.getDouble(_volumeKey) ?? _defaultVolume)
          .clamp(0.0, 1.0)
          .toDouble();

      _tts.setStartHandler(() {
        speakingNotifier.value = true;
      });
      _tts.setCompletionHandler(() {
        speakingNotifier.value = false;
      });
      _tts.setErrorHandler((msg) {
        speakingNotifier.value = false;
      });
      _tts.setCancelHandler(() {
        speakingNotifier.value = false;
      });

      // Kürtçe dil desteğini tespit et.
      await _detectKurdishSupport();
      await _applySettings();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts initialize');
    }
  }

  Future<void> _detectKurdishSupport() async {
    if (kIsWeb) {
      _kurdishAvailable = false;
      return;
    }
    try {
      final languages = await _tts.getLanguages ?? <Object>[];
      final langStrs = languages.map((e) => '$e'.toLowerCase()).toList();
      _kurdishAvailable = langStrs.any(
        (l) => l == 'ku' || l.startsWith('ku_') || l.startsWith('ku-') || l == 'ckb' || l.startsWith('ckb_') || l.startsWith('ckb-'),
      );
      // Kürtçe varsa onu, yoksa TR'yi (son çare) seç.
      if (_kurdishAvailable) {
        _activeLanguage = _prefs?.getString(_languageKey) ?? _matchLocale(langStrs);
      } else {
        _activeLanguage = _prefs?.getString(_languageKey) ?? 'tr-TR';
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts language detect');
      _kurdishAvailable = false;
    }
  }

  String _matchLocale(List<String> available) {
    for (final candidate in _candidateLocales) {
      final lower = candidate.toLowerCase();
      if (available.contains(lower)) return candidate;
      final underscore = lower.replaceAll('-', '_');
      if (available.contains(underscore)) return candidate;
    }
    return 'tr-TR';
  }

  Future<void> _applySettings() async {
    try {
      await _tts.setLanguage(_activeLanguage);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(1.0);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts apply settings');
    }
  }

  /// [text]'i seslendirir. Zaten konuşuyorsa kesip yeniden başlar.
  /// Servis kapalıysa veya dil desteklenmiyorsa hiçbir şey yapmaz.
  Future<void> speak(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    try {
      if (speakingNotifier.value) {
        await _tts.stop();
      }
      await _applySettings();
      await _tts.speak(text);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts speak');
      speakingNotifier.value = false;
    }
  }

  /// Konuşmayı durdurur.
  Future<void> stop() async {
    try {
      await _tts.stop();
      speakingNotifier.value = false;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts stop');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    if (!value) await stop();
    await _prefs?.setBool(_enabledKey, value);
  }

  Future<void> setRate(double value) async {
    _rate = value.clamp(0.0, 1.0).toDouble();
    await _tts.setSpeechRate(_rate);
    await _prefs?.setDouble(_rateKey, _rate);
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0.0, 1.0).toDouble();
    await _tts.setVolume(_volume);
    await _prefs?.setDouble(_volumeKey, _volume);
  }

  void _dispose() {
    try {
      _tts.stop();
    } catch (_) {}
  }
}

