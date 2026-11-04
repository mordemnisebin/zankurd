/// Yerel bildirimler — GPT-6 Pro ALAN 4 bulguları (2026-11-06).
///
/// ## Kusurlar
///
/// 1. Bildirimleri kapatırken alarm işaretleri silinip native `cancelAll()`
///    hatası yutuluyordu: arayüz kapalı, eski tekrarlı alarm çalmaya devam;
///    anahtar kapalı olduğundan iptal bir daha denenmiyordu.
/// 2. `refreshTimeZone()` günlük alarmı yeniden kurarken native hatayı
///    yutup "yeniden kurma bekliyor" işaretini temizliyordu; sonraki
///    resume'da dilim "değişmemiş" göründüğünden alarm kayboluyordu.
/// 3. Tercih/saat yazımlarının `false` sonucu denetlenmiyordu; saat ve dakika
///    ayrı iki yazımdı (yarım kayıt eski saati yeni dakikayla getirirdi).
/// 4. Ön plan bandı yerel anahtarı/tür tercihini hiç sormuyordu.
/// 5. Dil anahtarı yazılmamış yeni kurulumda servis Kurmancî, arayüz Türkçe
///    varsayıyordu; Android push kanalı adı dil değişince güncellenmiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hepsinde hata yutulur ya da sonuç okunmaz: ekranda her şey "doğru" görünür,
/// sapma yalnız gerçek cihazda saatler/günler sonra (ya da yeniden açılışta)
/// ortaya çıkar. Eklenti geçidi sahte olduğu için burada gözlenebilir.
library;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';

class _Resolver implements TimeZoneResolver {
  String name = 'Europe/Berlin';
  @override
  Future<String?> resolve() async => name;
}

class _Gateway implements LocalNotificationGateway {
  bool failCancelAll = false;
  bool failSchedule = false;
  int cancelAllCalls = 0;
  int scheduleCalls = 0;
  final scheduled = <int>[];
  final bodies = <int, String>{};

  @override
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  ) async {}
  @override
  Future<String?> launchPayload() async => null;
  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
    bool repeatDaily = true,
  }) async {
    scheduleCalls++;
    if (failSchedule) throw PlatformException(code: 'schedule_failed');
    scheduled.add(id);
    bodies[id] = body;
  }

  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    if (failCancelAll) throw PlatformException(code: 'cancel_failed');
  }
}

class _FailingStore extends SharedPreferencesStorePlatform {
  _FailingStore(this.values, this.failingKey);
  final Map<String, Object> values;
  final String failingKey;
  @override
  Future<Map<String, Object>> getAll() async => Map.of(values);
  @override
  Future<bool> clear() async => true;
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (key == failingKey) return false;
    values[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    values.remove(key);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesStorePlatform originalStore;

  setUp(() {
    originalStore = SharedPreferencesStorePlatform.instance;
    SharedPreferences.setMockInitialValues({'zankurd.language': 'tr'});
    NotificationService.resetInstance();
  });
  tearDown(() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = originalStore;
    SharedPreferences.setMockInitialValues({});
    NotificationService.resetInstance();
  });

  test(
    '1: native iptal düşerse işaretler kalır, açılışta yeniden denenir',
    () async {
      final gateway = _Gateway();
      final service = await NotificationService.load(
        timeZoneResolver: _Resolver(),
        gateway: gateway,
      );
      await service.setEnabled(true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zankurd.notifications.nextFireAt'), isNotNull);

      gateway.failCancelAll = true;
      await service.setEnabled(false);
      expect(
        prefs.getString('zankurd.notifications.nextFireAt'),
        isNotNull,
        reason: 'native iptal onaylanmadan alarm işareti silinmemeli',
      );
      expect(prefs.getBool('zankurd.notifications.cancelAllPending'), isTrue);

      // Sonraki açılış/resume: iptal artık başarılı.
      gateway.failCancelAll = false;
      final before = gateway.cancelAllCalls;
      await service.reconcilePendingCancel();
      expect(gateway.cancelAllCalls, before + 1);
      expect(prefs.getString('zankurd.notifications.nextFireAt'), isNull);
      expect(prefs.getBool('zankurd.notifications.cancelAllPending'), isNull);
    },
  );

  test(
    '1b: bu arada bildirimler yeniden açıldıysa bekleyen iptal çalışmaz',
    () async {
      final gateway = _Gateway();
      final service = await NotificationService.load(
        timeZoneResolver: _Resolver(),
        gateway: gateway,
      );
      await service.setEnabled(true);
      gateway.failCancelAll = true;
      await service.setEnabled(false);
      gateway.failCancelAll = false;
      await service.setEnabled(true);
      final calls = gateway.cancelAllCalls;
      await service.reconcilePendingCancel();
      expect(gateway.cancelAllCalls, calls, reason: 'yeni kurulum silinmemeli');
    },
  );

  test(
    '2: dilim değişimi sonrası kurulum düşerse işaret kalır, sonraki resume dener',
    () async {
      final gateway = _Gateway();
      final resolver = _Resolver();
      final service = await NotificationService.load(
        timeZoneResolver: resolver,
        gateway: gateway,
      );
      await service.setEnabled(true);

      resolver.name = 'Asia/Tokyo';
      gateway.failSchedule = true;
      expect(await service.refreshTimeZone(), isTrue);
      final failedCalls = gateway.scheduleCalls;

      // Dilim artık "aynı": eskiden yeniden kurma bir daha denenmezdi.
      gateway.failSchedule = false;
      expect(await service.refreshTimeZone(), isFalse);
      expect(
        gateway.scheduleCalls,
        failedCalls + 1,
        reason: 'bekleyen yeniden kurma sonraki resume’da tekrar denenmeli',
      );
      expect(gateway.scheduled, isNotEmpty);
      // Başarıdan sonra işaret kalkar: bir sonraki resume yeniden kurmaz.
      final okCalls = gateway.scheduleCalls;
      await service.refreshTimeZone();
      expect(gateway.scheduleCalls, okCalls);
    },
  );

  test('3: başarısız tercih yazımı hata verir, alarm değişmez', () async {
    const key = 'flutter.zankurd.notifications.pref.daily';
    final disk = _FailingStore({
      'flutter.zankurd.notifications.enabled': true,
    }, key);
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = disk;
    final gateway = _Gateway();
    final service = await NotificationService.load(
      timeZoneResolver: _Resolver(),
      gateway: gateway,
    );
    final calls = gateway.scheduleCalls;
    expect(service.dailyOn, isTrue);
    await expectLater(service.setDailyOn(false), throwsA(isA<StateError>()));
    expect(service.dailyOn, isTrue, reason: 'diskteki gerçek değer korunur');
    expect(gateway.scheduleCalls, calls);
  });

  test('3b: saat/dakika tek kayıt; başarısızsa eski saat korunur', () async {
    const key = 'flutter.zankurd.notifications.time';
    final disk = _FailingStore({'flutter.zankurd.notifications.hour': 8}, key);
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = disk;
    final service = await NotificationService.load(
      timeZoneResolver: _Resolver(),
      gateway: _Gateway(),
    );
    expect(service.hour, 8, reason: 'eski iki anahtar hâlâ okunur');
    await expectLater(service.setTime(21, 30), throwsA(isA<StateError>()));
    expect(service.timeDisplay, '08:00');
  });

  test('3c: saat tek anahtarla yazılır ve açılışta geri okunur', () async {
    var service = await NotificationService.load(
      timeZoneResolver: _Resolver(),
      gateway: _Gateway(),
    );
    await service.setTime(7, 5);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.notifications.time'), '07:05');
    NotificationService.resetInstance();
    service = await NotificationService.load(
      timeZoneResolver: _Resolver(),
      gateway: _Gateway(),
    );
    expect(service.timeDisplay, '07:05');
  });

  test(
    '4: ön plan bandı ana anahtar ve tür tercihini gösterim anında sorar',
    () async {
      expect(
        NotificationService.allowsForegroundPush('friend_request'),
        isTrue,
        reason: 'servis kurulu değilken engellenmez',
      );
      final service = await NotificationService.load(
        timeZoneResolver: _Resolver(),
        gateway: _Gateway(),
      );
      expect(
        NotificationService.allowsForegroundPush('friend_request'),
        isFalse,
        reason: 'ana anahtar kapalı',
      );
      await service.setEnabled(true);
      expect(
        NotificationService.allowsForegroundPush('friend_request'),
        isTrue,
      );
      await service.setSocialOn(false);
      expect(
        NotificationService.allowsForegroundPush('friend_request'),
        isFalse,
      );
      expect(NotificationService.allowsForegroundPush('room_invite'), isFalse);
      expect(
        NotificationService.allowsForegroundPush('async_duel_turn'),
        isTrue,
      );
      await service.setDuelOn(false);
      expect(
        NotificationService.allowsForegroundPush('async_duel_invite'),
        isFalse,
      );
      expect(NotificationService.allowsForegroundPush('bilinmeyen'), isTrue);
    },
  );

  test(
    '5: kayıtlı dil yokken servis arayüzle aynı varsayılanı (Türkçe) kullanır',
    () async {
      SharedPreferences.setMockInitialValues({});
      final gateway = _Gateway();
      final service = await NotificationService.load(
        timeZoneResolver: _Resolver(),
        gateway: gateway,
      );
      await service.setEnabled(true);
      // Dil anahtarı yok: günlük gövde Türkçe kurulmalı (eskiden Kurmancî).
      expect(gateway.bodies[0], Tr.forKu(K.huhuGununSorulukEtkinligi, false));
      expect(
        gateway.bodies[0],
        isNot(Tr.forKu(K.huhuGununSorulukEtkinligi, true)),
      );
    },
  );
}
