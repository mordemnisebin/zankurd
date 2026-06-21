import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bildirim ayarlarını yöneten servis.
/// Firebase Messaging bağımlılığı projeye eklendiğinde
/// gerçek push bildirimleri burada yapılandırılır.
class NotificationService {
  NotificationService._(
    this._preferences,
    this._enabled,
    this._hour,
    this._minute,
  );

  static const _enabledKey = 'zankurd.notifications.enabled';
  static const _hourKey = 'zankurd.notifications.hour';
  static const _minuteKey = 'zankurd.notifications.minute';
  static const _nextFireKey = 'zankurd.notifications.nextFireAt';

  static NotificationService? _instance;
  Timer? _mockTimer;

  static Future<NotificationService> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final service = NotificationService._(
      preferences,
      preferences?.getBool(_enabledKey) ?? false,
      preferences?.getInt(_hourKey) ?? 19,
      preferences?.getInt(_minuteKey) ?? 0,
    );
    if (service.enabled) {
      service.startMockScheduler();
    }
    return _instance = service;
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() {
    _instance?._mockTimer?.cancel();
    _instance = null;
  }

  final SharedPreferences? _preferences;
  bool _enabled;
  int _hour;
  int _minute;

  bool get enabled => _enabled;
  int get hour => _hour;
  int get minute => _minute;
  String get timeDisplay =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  /// Ayarlı saat/dakikaya göre bir sonraki bildirim anını hesaplar.
  /// [from] verilmezse şu an kullanılır. Hedef saat bugün için geçmişse
  /// (veya tam denk gelmişse) ertesi güne kayar.
  DateTime nextFireTime({DateTime? from}) {
    final now = from ?? DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, _hour, _minute);
    if (!candidate.isAfter(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  /// Hesaplanan bir sonraki bildirim anı (kalıcı). Native bildirim katmanı
  /// (flutter_local_notifications) eklendiğinde bu değer okunup zamanlanır.
  DateTime? get nextFireAt {
    final raw = _preferences?.getString(_nextFireKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Yerel zamanlayıcı ile bildirim simülasyonunu başlatır.
  void startMockScheduler() {
    _mockTimer?.cancel();
    _mockTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_enabled) return;
      final target = nextFireAt;
      if (target != null && DateTime.now().isAfter(target)) {
        debugPrint('[NOTIFICATION_SIMULATION] Hatırlatıcı: ZanKurd\'a hoş geldiniz! Günlük yarışmanızı tamamlamayı unutmayın!');
        _scheduleDaily();
      }
    });
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _preferences?.setBool(_enabledKey, value);
    if (value) {
      await _scheduleDaily();
      startMockScheduler();
    } else {
      await _cancelAll();
      _mockTimer?.cancel();
    }
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    await _preferences?.setInt(_hourKey, hour);
    await _preferences?.setInt(_minuteKey, minute);
    if (_enabled) {
      await _scheduleDaily();
      startMockScheduler();
    }
  }

  /// Günlük hatırlatıcının bir sonraki anını hesaplayıp kalıcı saklar.
  ///
  /// Native bildirim katmanı (flutter_local_notifications) eklendiğinde,
  /// burada hesaplanan [nextFireAt] değeri `zonedSchedule` ile işletim
  /// sistemine bildirilir. Cihaz adımları için bkz. docs/bildirim-entegrasyonu.md
  Future<void> _scheduleDaily() async {
    final next = nextFireTime();
    await _preferences?.setString(_nextFireKey, next.toIso8601String());
  }

  Future<void> _cancelAll() async {
    await _preferences?.remove(_nextFireKey);
  }
}
