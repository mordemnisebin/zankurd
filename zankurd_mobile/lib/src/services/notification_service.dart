import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/strings.dart';
import '../utils/error_reporter.dart';
import 'local_notification_tap.dart';

abstract class TimeZoneResolver {
  Future<String?> resolve();
}

class DeviceTimeZoneResolver implements TimeZoneResolver {
  const DeviceTimeZoneResolver();

  @override
  Future<String?> resolve() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}

/// Yerel bildirim eklentisine tek ince geçit.
///
/// Zamanlama, iptal ve dokunuş kayıtları buradan geçer; böylece günlük
/// hatırlatıcı / seri uyarısı mantığı (dil, payload, iptal-yeniden kurma)
/// eklenti olmadan birim testte doğrulanabilir.
abstract class LocalNotificationGateway {
  /// Eklentiyi başlatır; bildirime dokunulunca [onTap] payload ile çağrılır.
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  );

  /// Uygulama bir bildirime dokunularak (soğuk) açıldıysa o bildirimin
  /// payload'u, değilse `null`.
  Future<String?> launchPayload();

  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

class PluginLocalNotificationGateway implements LocalNotificationGateway {
  const PluginLocalNotificationGateway(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  ) => _plugin.initialize(
    settings: settings,
    onDidReceiveNotificationResponse: (response) => onTap(response.payload),
  );

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    scheduledDate: tz.TZDateTime.from(at, tz.local),
    notificationDetails: details,
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    matchDateTimeComponents: DateTimeComponents.time,
    payload: payload,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();
}

/// Bildirim ayarlarını yöneten servis.
/// flutter_local_notifications kullanılarak yerel günlük hatırlatıcılar zamanlanır.
class NotificationService {
  /// Bildirim siluetinin marka rengi (Tîrêj).
  static const _accent = Color(0xFFC2560E);

  /// Arka planda gelen FCM iletilerinin düştüğü Android kanalı.
  ///
  /// `AndroidManifest.xml`deki `default_notification_channel_id` ile AYNI
  /// olmalı (bekçi: `fcm_manifest_defaults_test.dart`). Sunucu Android
  /// `channel_id` göndermediği için push'ları sistem bu kanala koyar.
  /// Kanal başlangıçta [init]te oluşturulur; yalnız ilk yerel bildirimde
  /// oluşsaydı hiç yerel bildirim göstermemiş bir cihazda push yedek
  /// "Miscellaneous" kanalına düşerdi.
  static const pushChannelId = 'zankurd_friend_requests';

  NotificationService._(
    this._preferences,
    this._enabled,
    this._hour,
    this._minute,
    this._timeZoneResolver,
    this._gateway,
  );

  static const _enabledKey = 'zankurd.notifications.enabled';
  static const _hourKey = 'zankurd.notifications.hour';
  static const _minuteKey = 'zankurd.notifications.minute';
  static const _nextFireKey = 'zankurd.notifications.nextFireAt';
  static const _streakNextFireKey = 'zankurd.notifications.streakNextFireAt';

  static NotificationService? _instance;
  static Future<NotificationService>? _loading;

  /// Kurulu değilse null. Bildirimler bir iyileştirmedir; servis
  /// yüklenmemişse (web, test, yapılandırmasız derleme) çağıran taraf
  /// sessizce devam etmeli.
  static NotificationService? get instance => _instance;

  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<NotificationService> load({
    TimeZoneResolver timeZoneResolver = const DeviceTimeZoneResolver(),
    LocalNotificationGateway? gateway,
  }) async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final loading = _loadFresh(
      timeZoneResolver,
      gateway ?? PluginLocalNotificationGateway(_localNotificationsPlugin),
    );
    _loading = loading;
    try {
      final service = await loading;
      return _instance ??= service;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  static Future<NotificationService> _loadFresh(
    TimeZoneResolver timeZoneResolver,
    LocalNotificationGateway gateway,
  ) async {
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
      gateway,
    );
    await service._initNotifications();
    if (service.enabled) {
      await service._scheduleDaily();
    }
    return service;
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() {
    _instance = null;
    _loading = null;
  }

  final SharedPreferences? _preferences;
  bool _enabled;
  int _hour;
  int _minute;
  final TimeZoneResolver _timeZoneResolver;
  final LocalNotificationGateway _gateway;

  /// Arayüz dili değişince [applyLanguage] ile bildirilen dil. Boşken kayıtlı
  /// dil okunur. Kayıt, dil sağlayıcısının eşzamansız yazımına bağlı olmasın
  /// diye bellekteki değer önceliklidir.
  bool? _languageIsKu;

  bool get _isKu =>
      _languageIsKu ??
      (_preferences?.getString('zankurd.language') ?? 'ku') != 'tr';

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

      await _gateway.initialize(
        initializationSettings,
        LocalNotificationTapRouter.offer,
      );
      // Bildirime dokunularak soğuk açılan uygulama: dokunuş
      // `onDidReceiveNotificationResponse`a ulaşmaz, burada okunur.
      try {
        LocalNotificationTapRouter.offer(await _gateway.launchPayload());
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'notification_launch');
      }
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              pushChannelId,
              'ZanKurd Daxwazên Hevaltiyê',
              description: 'Daxwazên hevaltiyê yên nû',
              importance: Importance.high,
            ),
          );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService init');
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
      await _gateway.cancel(0);

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

      // Bildirim, zamanlama anındaki uygulama diliyle tek dilde kurulur;
      // dil değişince [applyLanguage] yeniden kurar.
      await _gateway.zonedSchedule(
        id: 0,
        title: 'ZanKurd',
        // Altın yol öğrenmedir; yarış/etkinlik metni kullanıcıyı yanlış
        // sekmeye çağırırdı. Gövde [K.huhuGununSorulukEtkinligi] ile
        // ana sayfadaki günün dersine hizalıdır.
        body: Tr.forKu(K.huhuGununSorulukEtkinligi, _isKu),
        at: next,
        details: details,
        payload: LocalNotificationPayload.dailyReminder,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService schedule');
    }
  }

  Future<void> _cancelAll() async {
    await _preferences?.remove(_nextFireKey);
    await _preferences?.remove(_streakNextFireKey);
    if (kIsWeb) return;
    try {
      await _gateway.cancelAll();
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService cancel');
    }
  }

  /// Arkadaşlık isteği geldiğinde anlık bildirim gönderir.
  /// ⚠️ ÜRETİMDE ÇAĞRILMIYOR — ve yerel olarak çağrılamaz.
  ///
  /// Bu bildirimin anlamlı olduğu an, isteğin GELDİĞİ andır; o anda
  /// uygulama büyük ihtimalle kapalıdır. Yerel bildirimler yalnız cihazda
  /// zamanlanabilir, dışarıdan tetiklenemez — yani bu metot ancak push
  /// (FCM) altyapısıyla işe yarar.
  ///
  /// Yerel ön plan bildirimi. Üretimdeki asıl yol `push_outbox` +
  /// `claim_push_outbox` (FCM). Bu metot uygulama açıkken yedek kalır
  /// ve çağrılmaz; rozet `list_pending_friend_requests` ile gelir.
  Future<void> showFriendRequest(String fromName, {bool isKu = true}) async {
    if (kIsWeb || !_enabled) return;
    try {
      final title = Tr.forKu(K.zanaDiyorKiYeni, isKu);
      final body = Tr.forKu(K.huhuPSeninleYarismak, isKu, {'p0': fromName});

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
    }
  }

  /// Seri kaybetme uyarısı: kullanıcı bugün oynamazsa serisi kırılacak.
  /// Seri uyarısını bugün için kapatır.
  ///
  /// [scheduleStreakWarning] `matchDateTimeComponents: DateTimeComponents.
  /// time` kullanıyor, yani bildirim HER GÜN aynı saatte tekrarlar. Gövde
  /// metni ise koşulsuz: "Bugün hiç oynamadın! Serin kırılabilir."
  ///
  /// Yani uyarı, çağrılır çağrılmaz her akşam 21:00'de aynı cümleyi
  /// söylerdi — oyuncu o gün üç tur oynamış olsa bile. Bildirim yalan
  /// söyleyen bir uygulama, kapatılan bir uygulamadır (2026-07-31
  /// denetiminde bu, uyarıyı bağlayacak kişi için tuzak olarak işaretlendi).
  ///
  /// Doğru akış: tur bitince bugünün uyarısını iptal et, yarın için
  /// yeniden kur. Böylece uyarı yalnız gerçekten oynanmayan günde çalar.
  Future<void> cancelStreakWarning() async {
    if (kIsWeb) return;
    try {
      await _gateway.cancel(_streakWarningId);
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService streak cancel');
    }
  }

  /// Seri etkinliği kaydedilince çağrılır: bugünün uyarısı susar, yarınki
  /// kurulur. Seriyi yazan HER yol bunu çağırır ([noteStreakActivity]).
  Future<void> refreshStreakWarningAfterPlay() async {
    if (kIsWeb || !_enabled) return;
    await cancelStreakWarning();
    await scheduleStreakWarning(startTomorrow: true);
  }

  /// Seriyi kaydeden her yolun çağıracağı TEK giriş. Servis kurulu değilse
  /// (web, test, yapılandırmasız derleme) sessizce hiçbir şey yapmaz.
  static Future<void> noteStreakActivity() async {
    try {
      await _instance?.refreshStreakWarningAfterPlay();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_warning_refresh');
    }
  }

  static const int _streakWarningId = 2;

  /// [startTomorrow] true ise ilk çalma bugüne değil yarına kurulur —
  /// oyuncu bugün zaten oynadıysa akşam uyarı almamalı.
  Future<void> scheduleStreakWarning({bool startTomorrow = false}) async {
    if (kIsWeb || !_enabled) return;
    try {
      // Schedule for 21:00 (9 PM) - a gentle reminder
      final now = DateTime.now();
      var scheduledTime = DateTime(now.year, now.month, now.day, 21, 0);
      if (startTomorrow || !scheduledTime.isAfter(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }
      await _scheduleStreakWarningAt(scheduledTime);
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService streak');
    }
  }

  Future<void> _scheduleStreakWarningAt(DateTime scheduledTime) async {
    // Günlük seri zincîr'dir; `Rêz` tur içi doğru cevap dizisidir.
    // Kanal adı Android ayarlarında görünür; gövde zincîr derken
    // kanal "Bîranîna Rêzê" deyince oyuncu iki kavramı karıştırır.
    const androidDetails = AndroidNotificationDetails(
      'zankurd_streak_warning',
      'ZanKurd Bîranîna Zincîrê',
      channelDescription: 'Bîranîna parastina zincîra rojane',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );
    await _preferences?.setString(
      _streakNextFireKey,
      scheduledTime.toIso8601String(),
    );
    await _gateway.zonedSchedule(
      id: _streakWarningId,
      title: Tr.forKu(K.zanaUzgun, _isKu),
      body: Tr.forKu(K.huhuBugunHicOynamadin, _isKu),
      at: scheduledTime,
      details: details,
      payload: LocalNotificationPayload.streakWarning,
    );
  }

  /// Arayüz dili değişti: zamanlanmış metinler zamanlama anındaki dilde
  /// donmuştu; yeni dille yeniden kurulur (soğuk açılış beklenmez).
  ///
  /// Seri uyarısı yalnız KURULUYSA yeniden kurulur ve zamanını korur (bugün
  /// oynandıysa yarına kurulu kalır); kurulu değilse yeni uyarı doğmaz.
  Future<void> applyLanguage({required bool isKu}) async {
    if (_languageIsKu == isKu) return;
    _languageIsKu = isKu;
    if (kIsWeb || !_enabled) return;
    await _scheduleDaily();
    final raw = _preferences?.getString(_streakNextFireKey);
    final armed = raw == null ? null : DateTime.tryParse(raw);
    if (armed == null) return;
    try {
      final now = DateTime.now();
      var at = armed;
      while (!at.isAfter(now)) {
        at = at.add(const Duration(days: 1));
      }
      await _scheduleStreakWarningAt(at);
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService streak lang');
    }
  }

  /// Arkadaşlık isteği kabul edildi bildirimi.
  /// ⚠️ ÜRETİMDE ÇAĞRILMIYOR — bkz. [showFriendRequest].
  ///
  /// Aynı gerekçe: isteği kabul EDEN taraf zaten ekranda görüyor; bildirimi
  /// alması gereken, isteği gönderen taraftır ve o an başka bir cihazdadır.
  /// Push altyapısı olmadan yerel olarak tetiklenemez.
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
        title: Tr.forKu(K.zanaMutlu, isKu),
        body: Tr.forKu(K.huhuPArkadaslikIstegini, isKu, {'p0': friendName}),
        notificationDetails: details,
      );
    } catch (e, s) {
      ErrorReporter.record(e, s, reason: 'NotificationService friend accepted');
    }
  }
}
