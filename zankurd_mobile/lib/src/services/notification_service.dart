import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/error_reporter.dart';

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
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'notification_init');
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
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'notification_cancel');
      }

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

  /// Sistem düzeyinde bildirim izni verilmiş mi?
  /// Web'de (yerel bildirim yok) ve izin sorgulanamayan platformlarda
  /// engel çıkarmamak için true döner.
  Future<bool> hasSystemPermission() async {
    if (kIsWeb) return true;
    try {
      final android = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) {
        return await android.areNotificationsEnabled() ?? true;
      }
      final ios = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (ios != null) {
        final options = await ios.checkPermissions();
        return options?.isEnabled ?? true;
      }
    } catch (e) {
      debugPrint('Failed to check notification permission: $e');
    }
    return true;
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
      // Bildirim, zamanlama anında kayıtlı uygulama diliyle tek dilde kurulur
      // (anahtar LanguageProvider._storageKey ile aynı olmalı).
      final isKu =
          (_preferences?.getString('zankurd.language') ?? 'ku') != 'tr';
      await _localNotificationsPlugin.zonedSchedule(
        0,
        'ZanKurd',
        isKu
            ? 'Pêşbirka rojê li benda te ye! Hêza hişê xwe biceribîne!'
            : 'Günün yarışması seni bekliyor! Zihnini test et!',
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

  /// Arkadaşlık isteği geldiğinde anlık bildirim gönderir.
  Future<void> showFriendRequest(String fromName, {bool isKu = true}) async {
    if (kIsWeb || !_enabled) return;
    try {
      final title = isKu ? 'Daxwaza Hevaltiyê' : 'Arkadaşlık İsteği';
      final body = isKu
          ? '$fromName dixwaze hevalê te be!'
          : '$fromName seninle arkadaş olmak istiyor!';

      const androidDetails = AndroidNotificationDetails(
        'zankurd_friend_requests',
        'ZanKurd Daxwazên Hevaltiyê',
        channelDescription: 'Daxwazên hevaltiyê yên nû',
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _localNotificationsPlugin.show(
        1, // Different ID from daily reminder
        title,
        body,
        details,
      );
    } catch (e) {
      debugPrint('Failed to show friend request notification: $e');
    }
  }

  /// Seri kaybetme uyarısı: kullanıcı bugün oynamazsa serisi kırılacak.
  Future<void> scheduleStreakWarning({bool isKu = true}) async {
    if (kIsWeb || !_enabled) return;
    try {
      // Schedule for 21:00 (9 PM) - a gentle reminder
      final now = DateTime.now();
      var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
      if (!scheduledTime.isAfter(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      const androidDetails = AndroidNotificationDetails(
        'zankurd_streak_warning',
        'ZanKurd Bîranîna Rêzê',
        channelDescription: 'Bîranîna parastina rêza rojane',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      final tzTime = tz.TZDateTime.from(scheduledTime, tz.local);
      await _localNotificationsPlugin.zonedSchedule(
        2, // Different ID
        isKu ? 'Rêza Te' : 'Serin',
        isKu
            ? 'Îro nelîstî! Seriya te dikare bişkê. Hema niha bilîze!'
            : 'Bugün oynamadın! Serin kırılabilir. Hemen şimdi oyna!',
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Failed to schedule streak warning: $e');
    }
  }

  /// Arkadaşlık isteği kabul edildi bildirimi.
  Future<void> showFriendAccepted(String friendName, {bool isKu = true}) async {
    if (kIsWeb || !_enabled) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        'zankurd_friend_requests',
        'ZanKurd Daxwazên Hevaltiyê',
        channelDescription: 'Daxwazên hevaltiyê yên nû',
        importance: Importance.high,
        priority: Priority.high,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _localNotificationsPlugin.show(
        3,
        isKu ? 'Hevaltiya Nû' : 'Yeni Arkadaşlık',
        isKu
            ? '$friendName daxwaza te qebûl kir!'
            : '$friendName isteğini kabul etti!',
        details,
      );
    } catch (e) {
      debugPrint('Failed to show friend accepted notification: $e');
    }
  }
}
