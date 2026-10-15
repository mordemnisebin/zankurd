/// Yerel bildirimler: seri uyarısı, dil değişimi ve dokunuş yönlendirmesi.
///
/// ## Kusurlar (2026-10-16 denetimi)
///
/// 1. **Seri uyarısı yalnız bir ekrandan susturuluyordu.** "Bugün hiç
///    oynamadın" uyarısı `quiz_result_screen.dart`ın sonunda iptal edilip
///    yarına kuruluyordu; seriyi yazan `StreakStore.recordPlay` kendisi
///    bunu yapmıyordu. Üstelik çağrı alıştırma turunda da çalışıyordu
///    (alıştırma seri yazmaz): uyarı susuyor, seri ise gerçekten
///    kırılıyordu. Artık seriyi yazan her yol tek yardımcıyı çağırır.
/// 2. **Dil zamanlama anında donuyordu.** Günlük hatırlatıcı ve seri uyarısı
///    kurulduğu andaki dille yazılır; ayarlarda dil değişince metin yalnız
///    soğuk açılışta (günlük) ya da bir sonraki turda (uyarı) yenileniyordu.
/// 3. **Yerel bildirim dokunuşu hiçbir yere gitmiyordu.** FCM dokunuşları
///    `PushTapRouter` ile yönleniyor, yerel bildirimlerin dokunuşunu
///    dinleyen kod yoktu; `payload`sız kurulduklarından dinlense bile neye
///    dokunulduğu bilinmezdi.
///
/// ## Niçin sessizdi
///
/// Eklenti statik olduğundan `NotificationService` testte hiç zamanlama
/// yapmıyordu (hata yutulup geçiliyordu); zamanlanan metin, saat ve payload
/// hiçbir testte görülemedi. `LocalNotificationGateway` bu boşluğu kapatır.
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/services/local_notification_tap.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

class _Resolver implements TimeZoneResolver {
  const _Resolver();

  @override
  Future<String?> resolve() async => 'Europe/Berlin';
}

class _Scheduled {
  _Scheduled(this.id, this.title, this.body, this.at, this.payload);

  final int id;
  final String title;
  final String body;
  final DateTime at;
  final String? payload;
}

class _FakeGateway implements LocalNotificationGateway {
  final scheduled = <_Scheduled>[];
  final cancelled = <int>[];
  void Function(String? payload)? onTap;
  String? launch;

  _Scheduled? lastFor(int id) => scheduled.where((s) => s.id == id).lastOrNull;

  @override
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  ) async {
    this.onTap = onTap;
  }

  @override
  Future<String?> launchPayload() async => launch;

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
  }) async {
    scheduled.add(_Scheduled(id, title, body, at, payload));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelled.add(-1);
}

Future<(NotificationService, _FakeGateway)> _enabledService({
  String? launch,
}) async {
  final gateway = _FakeGateway()..launch = launch;
  final service = await NotificationService.load(
    timeZoneResolver: const _Resolver(),
    gateway: gateway,
  );
  await service.setEnabled(true);
  return (service, gateway);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.language': 'ku'});
    NotificationService.resetInstance();
    PushTapRouter.resetForTest();
  });
  tearDown(() {
    NotificationService.resetInstance();
    PushTapRouter.resetForTest();
  });

  group('seri uyarısı', () {
    test('seriyi yazan recordPlay uyarıyı susturur, yarına kurar', () async {
      final (_, gateway) = await _enabledService();
      final store = await StreakStore.load();

      await store.recordPlay();

      expect(gateway.cancelled, contains(2));
      final warning = gateway.lastFor(2)!;
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(warning.at.day, tomorrow.day);
      expect(warning.at.hour, 21);
      expect(warning.payload, LocalNotificationPayload.streakWarning);
    });

    test('dondurmayla seriyi koruyan yol da uyarıyı yeniler', () async {
      final (_, gateway) = await _enabledService();
      final store = await StreakStore.load();
      await store.recordPlay(now: DateTime(2026, 1, 1));
      gateway.scheduled.clear();
      gateway.cancelled.clear();
      await store.addFreeze();

      // Dondurma uygunsa seriyi köprüler, değilse düz oyun sayılır; iki
      // yolda da uyarı yenilenmelidir.
      await store.freezeAndRecordPlay(now: DateTime.now());

      expect(gateway.cancelled, contains(2));
      expect(gateway.lastFor(2), isNotNull);
    });

    test('bildirimler kapalıyken hiçbir şey kurulmaz', () async {
      final gateway = _FakeGateway();
      await NotificationService.load(
        timeZoneResolver: const _Resolver(),
        gateway: gateway,
      );
      final store = await StreakStore.load();

      await store.recordPlay();

      expect(gateway.scheduled, isEmpty);
    });
  });

  group('dil değişimi', () {
    test('günlük hatırlatıcı yeni dille yeniden kurulur', () async {
      final (service, gateway) = await _enabledService();
      expect(
        gateway.lastFor(0)!.body,
        Tr.forKu(K.huhuGununSorulukEtkinligi, true),
      );

      await service.applyLanguage(isKu: false);

      final daily = gateway.lastFor(0)!;
      expect(daily.body, Tr.forKu(K.huhuGununSorulukEtkinligi, false));
      expect(daily.payload, LocalNotificationPayload.dailyReminder);
    });

    test('kurulu seri uyarısı zamanını koruyarak yeni dille kurulur', () async {
      final (service, gateway) = await _enabledService();
      await service.refreshStreakWarningAfterPlay();
      final before = gateway.lastFor(2)!;

      await service.applyLanguage(isKu: false);

      final after = gateway.lastFor(2)!;
      expect(after.at, before.at);
      expect(after.body, Tr.forKu(K.huhuBugunHicOynamadin, false));
      expect(after.title, Tr.forKu(K.zanaUzgun, false));
    });

    test('kurulu olmayan seri uyarısı dil değişince doğmaz', () async {
      final (service, gateway) = await _enabledService();

      await service.applyLanguage(isKu: false);

      expect(gateway.lastFor(2), isNull);
    });
  });

  group('dokunuş yönlendirmesi', () {
    test('iki yerel bildirim de ana ekrana çözülür', () {
      expect(
        LocalNotificationTapRouter.targetForPayload(
          LocalNotificationPayload.dailyReminder,
        ),
        PushTapTarget.home,
      );
      expect(
        LocalNotificationTapRouter.targetForPayload(
          LocalNotificationPayload.streakWarning,
        ),
        PushTapTarget.home,
      );
    });

    test('bilinmeyen ya da boş payload yok sayılır', () {
      expect(LocalNotificationTapRouter.targetForPayload(null), isNull);
      expect(LocalNotificationTapRouter.targetForPayload('x'), isNull);
      expect(LocalNotificationTapRouter.offer('x'), isFalse);
      expect(PushTapRouter.pending.value, isNull);
    });

    test('çalışırken dokunulan bildirim bekleyen hedefe yazılır', () async {
      final (_, gateway) = await _enabledService();

      gateway.onTap!(LocalNotificationPayload.streakWarning);

      expect(PushTapRouter.take(), PushTapTarget.home);
    });

    test('bildirimle soğuk açılış başlatmada yönlendirilir', () async {
      await _enabledService(launch: LocalNotificationPayload.dailyReminder);

      expect(PushTapRouter.take(), PushTapTarget.home);
    });

    test('zamanlanan her iki bildirim payload taşır', () async {
      final (service, gateway) = await _enabledService();
      await service.scheduleStreakWarning();

      expect(
        gateway.lastFor(0)!.payload,
        LocalNotificationPayload.dailyReminder,
      );
      expect(
        gateway.lastFor(2)!.payload,
        LocalNotificationPayload.streakWarning,
      );
    });
  });
}
