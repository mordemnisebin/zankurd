import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/error_reporter.dart';

/// Kürtçe (Kurmancî) soru ve şiroveleri seslendirmek için TTS servisi.
///
/// Yalnız kurulu Kurmancî (ku) sesi kullanılır; Soranî veya Türkçe
/// sesi Kurmancî telaffuz yerine geçirilmez. Destek yoksa
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

  final FlutterTts _tts;
  final SharedPreferences? _prefs;

  bool _kurdishAvailable = false;
  bool _enabled = true;
  double _rate = _defaultRate;
  double _volume = _defaultVolume;
  String _activeLanguage = '';
  Completer<bool>? _pendingStart;
  bool _starting = false;
  bool _disposed = false;
  int _speechGeneration = 0;

  static const _startTimeout = Duration(seconds: 3);

  void _finishStart(bool started) {
    final pending = _pendingStart;
    if (pending != null && !pending.isCompleted) pending.complete(started);
  }

  void _speechEnded() {
    if (_disposed) return;
    _finishStart(false);
    speakingNotifier.value = false;
  }

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
  static Future<TtsService> load() {
    final cached = _instance;
    if (cached != null) return Future<TtsService>.value(cached);
    // H4 (Pro denetimi 2026-11-05): devam eden başlatma paylaşılmıyordu;
    // iki eşzamanlı `load()` (ör. ana ekran + alıştırma) `_instance`
    // atanmadan ikisi de geçip iki `FlutterTts` ve iki işleyici kümesi
    // kuruyordu, ikinci atama ilkini sahipsiz bırakıp çifte konuşmaya yol
    // açabiliyordu. Aynı Future'ı paylaşırız; hata olursa sonraki çağrı
    // yeniden denesin diye temizlenir.
    final pending = _loading ??= _loadOnce().whenComplete(
      () => _loading = null,
    );
    return pending;
  }

  static Future<TtsService>? _loading;

  static Future<TtsService> _loadOnce() async {
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
    _loading = null;
    _instance?._dispose();
    _instance?.speakingNotifier.dispose();
    _instance = null;
  }

  Future<void> _initialize() async {
    try {
      _enabled = _prefs?.getBool(_enabledKey) ?? true;
      _rate = (_prefs?.getDouble(_rateKey) ?? _defaultRate)
          .clamp(0.0, 1.0)
          .toDouble();
      _volume = (_prefs?.getDouble(_volumeKey) ?? _defaultVolume)
          .clamp(0.0, 1.0)
          .toDouble();

      _tts.setStartHandler(() {
        if (_disposed || _pendingStart == null) return;
        _finishStart(true);
        speakingNotifier.value = true;
      });
      _tts.setCompletionHandler(_speechEnded);
      _tts.setErrorHandler((msg) => _speechEnded());
      _tts.setCancelHandler(_speechEnded);

      // Kürtçe dil desteğini tespit et.
      await _detectKurdishSupport();
      await _applySettings();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts initialize');
    }
  }

  Future<void> _detectKurdishSupport() async {
    // iOS'ta Kurmancî ses hiç yok (AVSpeechSynthesis desteklemez), yani
    // sorgu hiçbir zaman işe yaramaz; üstelik eklenti dilleri ANA iş
    // parçacığında eşzamanlı sayar ve simülatörde her quiz başında uygulamayı
    // kilitledi (eşleşme ekranında "Dest pê dike…"da donma, 2026-10-17).
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) {
      _kurdishAvailable = false;
      return;
    }
    try {
      final languages = await _tts.getLanguages ?? <Object>[];
      final installed = languages.map((e) => '$e').where((locale) {
        final normalized = locale.toLowerCase().replaceAll('_', '-');
        return normalized == 'ku' || normalized.startsWith('ku-');
      }).toList();
      final saved = _prefs?.getString(_languageKey);
      _activeLanguage = installed.contains(saved)
          ? saved!
          : installed.isEmpty
          ? ''
          : installed.first;
      _kurdishAvailable = _activeLanguage.isNotEmpty;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts language detect');
      _kurdishAvailable = false;
    }
  }

  Future<bool> _applySettings() async {
    if (!_kurdishAvailable) return false;
    try {
      await _tts.setLanguage(_activeLanguage);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(1.0);
      return true;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts apply settings');
      return false;
    }
  }

  /// Yalnız motor isteği kabul edip başlangıç olayını bildirdiğinde true.
  /// Ret, sessiz dönüş, hata ve zaman aşımı dinlenmiş sayılmaz.
  /// [rateFactor] kayıtlı hızı değiştirmeden bu okumayı yavaşlatır.
  Future<bool> speak(String text, {double rateFactor = 1.0}) async {
    if (_disposed ||
        _starting ||
        !_enabled ||
        !_kurdishAvailable ||
        _volume == 0 ||
        text.trim().isEmpty) {
      return false;
    }
    _starting = true;
    final generation = ++_speechGeneration;
    bool current() => !_disposed && generation == _speechGeneration;
    Future<bool> start() async {
      if (speakingNotifier.value) await _tts.stop();
      if (!current() || !await _applySettings() || !current()) return false;
      if (rateFactor != 1.0) {
        await _tts.setSpeechRate((_rate * rateFactor).clamp(0.05, 1.0));
      }
      if (!current()) return false;
      final pending = Completer<bool>();
      _pendingStart = pending;
      final accepted = await _tts.speak(text);
      if (!current() || accepted != 1) return false;
      return await pending.future && current();
    }

    var started = false;
    try {
      started = await start().timeout(_startTimeout, onTimeout: () => false);
      return started;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts speak');
      return false;
    } finally {
      _finishStart(false);
      _pendingStart = null;
      if (!started && current()) {
        // Geç dönen platform çağrısı bu denemeyi yeniden başlatamaz.
        ++_speechGeneration;
        speakingNotifier.value = false;
        unawaited(_stopEngine());
      }
      _starting = false;
    }
  }

  Future<void> _stopEngine() async {
    try {
      await _tts.stop();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'tts stop');
    }
  }

  /// Bekleyen başlatmayı da iptal eder; geç yanıt başarıya dönüşmez.
  Future<void> stop() async {
    ++_speechGeneration;
    _finishStart(false);
    _pendingStart = null;
    if (!_disposed) speakingNotifier.value = false;
    await _stopEngine();
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
    _disposed = true;
    ++_speechGeneration;
    _finishStart(false);
    _pendingStart = null;
    unawaited(_stopEngine());
  }
}
