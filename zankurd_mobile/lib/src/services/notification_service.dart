import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Bildirim ayarlarını yöneten servis.
/// flutter_local_notifications kullanılarak yerel günlük hatırlatıcılar zamanlanır.
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
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

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
    await service._initNotifications();
    if (service.enabled) {
      await service._scheduleDaily();
    }
    return _instance = service;
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() {
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

  /// Hesaplanan bir sonraki bildirim anı (kalıcı).
  DateTime? get nextFireAt {
    final raw = _preferences?.getString(_nextFireKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> _initNotifications() async {
    if (kIsWeb) return;
    try {
      tz.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      } catch (_) {}

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: DarwinInitializationSettings(),
          );

      await _localNotificationsPlugin.initialize(initializationSettings);
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) return;
    try {
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Failed to request notifications permission: $e');
    }
  }

  Future<void> setEnabled(bool value) async {
    _enabled = value;
    await _preferences?.setBool(_enabledKey, value);
    if (value) {
      await _requestPermissions();
      await _scheduleDaily();
    } else {
      await _cancelAll();
    }
  }

  Future<void> setTime(int hour, int minute) async {
    _hour = hour;
    _minute = minute;
    await _preferences?.setInt(_hourKey, hour);
    await _preferences?.setInt(_minuteKey, minute);
    if (_enabled) {
      await _scheduleDaily();
    }
  }

  /// Günlük hatırlatıcının bir sonraki anını hesaplayıp zamanlar.
  Future<void> _scheduleDaily() async {
    final next = nextFireTime();
    await _preferences?.setString(_nextFireKey, next.toIso8601String());

    if (kIsWeb) return;
    try {
      await _localNotificationsPlugin.cancel(
        0,
      ); // Cancel previous daily notification

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'zankurd_daily_reminder',
            'ZanKurd Bîranîna Rojane',
            channelDescription: 'Bîranîna pêşbirka rojane ya ZanKurd',
            importance: Importance.max,
            priority: Priority.high,
          );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final scheduledTime = tz.TZDateTime.from(next, tz.local);
      await _localNotificationsPlugin.zonedSchedule(
        0,
        'ZanKurd',
        'Pêşbirka rojê li benda te ye! Hêza hişê xwe biceribîne! / Günün yarışması seni bekliyor! Zihnini test et!',
        scheduledTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule local notification: $e');
    }
  }

  Future<void> _cancelAll() async {
    await _preferences?.remove(_nextFireKey);
    if (kIsWeb) return;
    try {
      await _localNotificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint('Failed to cancel notifications: $e');
    }
  }
}
