import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../utils/error_reporter.dart';

abstract class TimeZoneResolver {
  Future<String?> resolve();
}

class DeviceTimeZoneResolver implements TimeZoneResolver {
  const DeviceTimeZoneResolver();

  @override
  Future<String?> resolve() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}

/// Bildirim ayarlarını yöneten servis.
/// flutter_local_notifications kullanılarak yerel günlük hatırlatıcılar zamanlanır.
class NotificationService {
  /// Bildirim siluetinin marka rengi (Tîrêj).
  static const _accent = Color(0xFFC2560E);

  NotificationService._(
    this._preferences,
    this._enabled,
    this._hour,
    this._minute,
    this._timeZoneResolver,
  );

  static const _enabledKey = 'zankurd.notifications.enabled';
  static const _hourKey = 'zankurd.notifications.hour';
  static const _minuteKey = 'zankurd.notifications.minute';
  static const _nextFireKey = 'zankurd.notifications.nextFireAt';

  static NotificationService? _instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<NotificationService> load({
    TimeZoneResolver timeZoneResolver = const DeviceTimeZoneResolver(),
  }) async {
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
      timeZoneResolver,
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
  final TimeZoneResolver _timeZoneResolver;

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
        final timeZoneName = await _timeZoneResolver.resolve();
        if (timeZoneName != null && timeZoneName.trim().isNotEmpty) {
          tz.setLocalLocation(tz.getLocation(timeZoneName));
        }
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'notification_timezone');
      }

      // Bildirim küçük ikonu **silueta** çevrilir: Android rengi atar,
      // yalnız alfayı kullanır. Başlatıcı simgesi verilince (ki onun zemini
      // mağaza şartı gereği opak beyazdır) bildirimde düz beyaz bir kare
      // çıkıyordu — günlük hatırlatıcının her gösteriminde (2026-07-27).
      // `ic_stat_zankurd` saydam zeminli beyaz amblemdir.
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@drawable/ic_stat_zankurd');
      const InitializationSettings initializationSettings =
          InitializationSettings(
            android: initializationSettingsAndroid,
            // Darwin varsayılanları izinleri *başlatma anında* ister; bu,
            // uygulama daha ilk kez çizilmeden sistem bildirim iznini
            // gösteriyordu (2026-07-25 canlı denetimi, iOS). Kullanıcı ne
            // istendiğini görmeden reddettiği için izin oranı düşüyor ve
            // iOS aynı istemi bir daha göstermiyor. İzin artık yalnız
            // "Günlük hatırlatıcı" açıldığında, [_requestPermissions]
            // üzerinden istenir.
            iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false,
            ),
          );

      await _localNotificationsPlugin.initialize(
        settings: initializationSettings,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService init');
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
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService');
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
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService check');
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
      await _localNotificationsPlugin.cancel(id: 0);

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'zankurd_daily_reminder',
            'ZanKurd Bîranîna Rojane',
            channelDescription: 'Bîranîna çalakiya rojane ya ZanKurd',
            importance: Importance.max,
            priority: Priority.high,
            // Siluet ikonu sistemin gri tonuyla çizilir; marka rengi
            // verilince bildirim ZanKurd'un turuncusuyla görünür.
            color: _accent,
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
        id: 0,
        title: 'ZanKurd',
        body: isKu
            ? 'Huhu! Çalakiya rojê ya 10 pirsan amade ye. Pêşketina xwe biceribîne!'
            : 'Huhu! Günün 10 soruluk etkinliği hazır. İlerlemeni ölç!',
        scheduledDate: scheduledTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService schedule');
      debugPrint('Failed to schedule local notification: $e');
    }
  }

  Future<void> _cancelAll() async {
    await _preferences?.remove(_nextFireKey);
    if (kIsWeb) return;
    try {
      await _localNotificationsPlugin.cancelAll();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService cancel');
      debugPrint('Failed to cancel notifications: $e');
    }
  }

  /// Arkadaşlık isteği geldiğinde anlık bildirim gönderir.
  Future<void> showFriendRequest(String fromName, {bool isKu = true}) async {
    if (kIsWeb || !_enabled) return;
    try {
      final title = isKu
          ? 'Zana Dibêje: Hevalek Nû'
          : 'Zana Diyor ki: Yeni Bir Arkadaş';
      final body = isKu
          ? 'Huhu! $fromName dixwaze bi te re pêşbaziyê bike!'
          : 'Huhu! $fromName seninle yarışmak istiyor!';

      const androidDetails = AndroidNotificationDetails(
        'zankurd_friend_requests',
        'ZanKurd Daxwazên Hevaltiyê',
        channelDescription: 'Daxwazên hevaltiyê yên nû',
        color: _accent,
        importance: Importance.high,
        priority: Priority.high,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _localNotificationsPlugin.show(
        id: 1,
        title: title,
        body: body,
        notificationDetails: details,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService friend request');
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
        id: 2,
        title: isKu ? 'Zana Xemgîn e...' : 'Zana Üzgün...',
        body: isKu
            ? 'Huhu! Te îro qet nelîst! Seriya te dikare bişkê. Zana li benda te ye!'
            : 'Huhu! Bugün hiç oynamadın! Serin kırılabilir. Zana seni bekliyor!',
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService streak');
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
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _localNotificationsPlugin.show(
        id: 3,
        title: isKu ? 'Zana Kêfxweş e!' : 'Zana Mutlu!',
        body: isKu
            ? 'Huhu! $friendName daxwaza hevaltiya te qebûl kir! Wexta pêşbaziyê ye!'
            : 'Huhu! $friendName arkadaşlık isteğini kabul etti! Yarış zamanı!',
        notificationDetails: details,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService friend accepted');
      debugPrint('Failed to show friend accepted notification: $e');
    }
  }
}
