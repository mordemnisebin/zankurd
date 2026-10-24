/// Bildirim tercihleri: kalıcılık, yerel zamanlamayı kapılama, günün
/// yarışması 19:00 hatırlatması ve sunucu eşitlemesi.
///
/// ## Kusur
///
/// Bildirimler tek anahtardı ("Günlük hatırlatıcı"): kapatınca seri uyarısı
/// da susuyor, açık bırakınca düello/arkadaş push'larından yalnız birini
/// kapatmanın yolu yoktu; kullanıcı ya hepsini ya hiçbirini alıyordu.
/// Günün yarışması için hiç hatırlatma yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// Yerel zamanlama eklenti arkasında; hangi kimliğin kurulup iptal edildiğini
/// hiçbir test görmüyordu. Düello/arkadaş türleri sunucudan gelir: tercihin
/// SUNUCUYA ulaşıp ulaşmadığı (kirli işaret, çevrimdışı yeniden deneme)
/// yalnız cihazda bakılınca anlaşılmazdı.
///
/// ## Kural
///
/// * Her tür bağımsız ve varsayılan AÇIKTIR; ana anahtar kapalıyken hiçbiri
///   çalışmaz.
/// * Bir türü kapatmak yalnız o türün kurulu bildirimini iptal eder.
/// * Günün yarışması hatırlatması bugün 19:00'dır, yalnız bugünün yarışması
///   OYNANMADIYSA; oynanınca yarına kurulur, tercih kapalıysa kurulmaz.
/// * Düello/arkadaş tercihi sunucuya yazılamazsa "kirli" kalır, sunucu
///   değeri onu ezmez.
library;

import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/contest_play_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/local_notification_tap.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'package:zankurd_mobile/src/services/notification_sync.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

class _Resolver implements TimeZoneResolver {
  const _Resolver();

  @override
  Future<String?> resolve() async => 'Europe/Berlin';
}

class _Call {
  _Call(this.id, this.at, this.payload, this.title);
  final int id;
  final DateTime at;
  final String? payload;
  final String title;
}

class _Gateway implements LocalNotificationGateway {
  final scheduled = <_Call>[];
  final cancelled = <int>[];

  _Call? lastFor(int id) => scheduled.where((s) => s.id == id).lastOrNull;

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
    scheduled.add(_Call(id, at, payload, title));
  }

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelled.add(-1);
}

Future<(NotificationService, _Gateway)> _service({bool enable = true}) async {
  final gateway = _Gateway();
  final service = await NotificationService.load(
    timeZoneResolver: const _Resolver(),
    gateway: gateway,
  );
  if (enable) await service.setEnabled(true);
  return (service, gateway);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.language': 'tr'});
    NotificationService.resetInstance();
    PushTapRouter.resetForTest();
  });
  tearDown(NotificationService.resetInstance);

  group('tercihler', () {
    test('hepsi varsayılan AÇIK', () async {
      final (service, _) = await _service(enable: false);
      expect(service.dailyOn, isTrue);
      expect(service.contestOn, isTrue);
      expect(service.streakOn, isTrue);
      expect(service.duelOn, isTrue);
      expect(service.socialOn, isTrue);
    });

    test('kapatılan tercih yeniden yüklemede de kapalı kalır', () async {
      final (service, _) = await _service();
      await service.setContestOn(false);
      await service.setStreakOn(false);
      await service.setDailyOn(false);
      await service.setDuelOn(false);
      await service.setSocialOn(false);

      NotificationService.resetInstance();
      final reloaded = await NotificationService.load(
        timeZoneResolver: const _Resolver(),
        gateway: _Gateway(),
      );
      expect(reloaded.contestOn, isFalse);
      expect(reloaded.streakOn, isFalse);
      expect(reloaded.dailyOn, isFalse);
      expect(reloaded.duelOn, isFalse);
      expect(reloaded.socialOn, isFalse);
    });
  });

  group('yerel zamanlamayı kapılama', () {
    test(
      'günlük hatırlatma kapalıysa ana anahtar açılsa da kurulmaz',
      () async {
        SharedPreferences.setMockInitialValues({
          'zankurd.notifications.pref.daily': false,
        });
        final (_, gateway) = await _service();
        expect(gateway.lastFor(0), isNull);
      },
    );

    test(
      'günlük hatırlatmayı kapatmak yalnız kimlik 0\'ı iptal eder',
      () async {
        final (service, gateway) = await _service();
        expect(gateway.lastFor(0), isNotNull);
        gateway.cancelled.clear();

        await service.setDailyOn(false);

        expect(gateway.cancelled, [0]);
        expect(service.nextFireAt, isNull);
      },
    );

    test('günlük hatırlatma kapalıyken saat değişimi kurmaz', () async {
      final (service, gateway) = await _service();
      await service.setDailyOn(false);
      gateway.scheduled.clear();

      await service.setTime(8, 30);

      expect(gateway.lastFor(0), isNull);
    });

    test('seri uyarısı kapalıysa kurulmaz, kapatınca iptal edilir', () async {
      final (service, gateway) = await _service();
      await service.scheduleStreakWarning();
      expect(gateway.lastFor(2), isNotNull);

      await service.setStreakOn(false);
      expect(gateway.cancelled, contains(2));

      gateway.scheduled.clear();
      await service.scheduleStreakWarning();
      await service.armStreakWarning(hasLiveStreak: true, playedToday: false);
      await service.refreshStreakWarningAfterPlay();
      expect(gateway.lastFor(2), isNull);
    });

    test('seri uyarısı kapalıyken günlük hatırlatma etkilenmez', () async {
      final (service, gateway) = await _service();
      gateway.scheduled.clear();
      await service.setStreakOn(false);
      await service.setTime(7, 15);
      expect(gateway.lastFor(0), isNotNull);
    });

    test('ana anahtar kapalıyken hiçbir tür kurulmaz', () async {
      final (service, gateway) = await _service(enable: false);
      await service.scheduleStreakWarning();
      await service.armContestReminder(
        contestAvailable: true,
        playedToday: false,
      );
      expect(gateway.scheduled, isEmpty);
    });
  });

  group('günün yarışması 19:00 hatırlatması', () {
    final morning = DateTime(2026, 10, 24, 9, 30);
    final evening = DateTime(2026, 10, 24, 20, 5);

    test('oynanmadı ve saat gelmedi: bugün 19:00', () {
      expect(
        NotificationService.contestReminderTime(morning, playedToday: false),
        DateTime(2026, 10, 24, 19),
      );
    });

    test('oynandı: bugünkü susar, yarın 19:00', () {
      expect(
        NotificationService.contestReminderTime(morning, playedToday: true),
        DateTime(2026, 10, 25, 19),
      );
    });

    test('19:00 geçti: yarın 19:00', () {
      expect(
        NotificationService.contestReminderTime(evening, playedToday: false),
        DateTime(2026, 10, 25, 19),
      );
    });

    test('tam 19:00\'da kurulursa ertesi güne kayar', () {
      expect(
        NotificationService.contestReminderTime(
          DateTime(2026, 10, 24, 19),
          playedToday: false,
        ),
        DateTime(2026, 10, 25, 19),
      );
    });

    test('kurulur: kimlik 4, yarışma payload\'ı, tek atış', () async {
      final (service, gateway) = await _service();
      await service.armContestReminder(
        contestAvailable: true,
        playedToday: false,
        now: morning,
      );
      final call = gateway.lastFor(4)!;
      expect(call.at, DateTime(2026, 10, 24, 19));
      expect(call.payload, LocalNotificationPayload.contestReminder);
    });

    test('tercih kapalıyken kurulmaz ve kurulu olan iptal edilir', () async {
      final (service, gateway) = await _service();
      await service.armContestReminder(
        contestAvailable: true,
        playedToday: false,
        now: morning,
      );
      await service.setContestOn(false);
      expect(gateway.cancelled, contains(4));

      gateway.scheduled.clear();
      await service.armContestReminder(
        contestAvailable: true,
        playedToday: false,
        now: morning,
      );
      expect(gateway.lastFor(4), isNull);
    });

    test('yarışma yoksa kurulmaz', () async {
      final (service, gateway) = await _service();
      await service.armContestReminder(
        contestAvailable: false,
        playedToday: false,
        now: morning,
      );
      expect(gateway.lastFor(4), isNull);
    });

    test('eşitleme: oynanmadıysa bugün 19:00, oynandıysa yarın', () async {
      final (_, gateway) = await _service();
      await NotificationService.syncContestReminder(
        contestAvailable: () async => true,
        now: morning,
      );
      expect(gateway.lastFor(4)!.at, DateTime(2026, 10, 24, 19));

      await ContestPlayStore.markPlayed(now: morning);
      await NotificationService.syncContestReminder(
        contestAvailable: () async => true,
        now: morning,
      );
      expect(gateway.lastFor(4)!.at, DateTime(2026, 10, 25, 19));
    });

    test('yarışma oynanınca bugünkü susar, yarına kurulur', () async {
      final (_, gateway) = await _service();
      await NotificationService.syncContestReminder(
        contestAvailable: () async => true,
        now: morning,
      );
      await NotificationService.noteContestPlayed(now: morning);
      expect(gateway.lastFor(4)!.at, DateTime(2026, 10, 25, 19));
      expect(await ContestPlayStore.playedToday(now: morning), isTrue);
      // Ertesi gün aynı kayıt "oynandı" saymaz.
      expect(
        await ContestPlayStore.playedToday(now: DateTime(2026, 10, 25, 9)),
        isFalse,
      );
    });

    test('bilinmiyor (null) kurulu hatırlatmayı OLDUĞU GİBİ bırakır', () async {
      final (_, gateway) = await _service();
      await NotificationService.syncContestReminder(
        contestAvailable: () async => true,
        now: morning,
      );
      final before = gateway.scheduled.length;
      gateway.cancelled.clear();

      await NotificationService.syncContestReminder(
        contestAvailable: () async => null,
        now: morning,
      );

      expect(gateway.scheduled.length, before);
      expect(gateway.cancelled, isNot(contains(4)));
    });

    test('tercih kapalıyken eşitleme kalmış hatırlatmayı kaldırır', () async {
      final (service, gateway) = await _service();
      await NotificationService.syncContestReminder(
        contestAvailable: () async => true,
        now: morning,
      );
      await service.setContestOn(false);
      gateway.cancelled.clear();

      await NotificationService.syncContestReminder(
        contestAvailable: () async => true,
        now: morning,
      );
      expect(gateway.lastFor(4)!.at, DateTime(2026, 10, 24, 19));
      // setContestOn(false) zaten iptal etti; yeni kurulum doğmadı.
      expect(
        gateway.scheduled.where((c) => c.id == 4).length,
        1,
        reason: 'tercih kapalıyken yeni hatırlatma kurulmamalı',
      );
    });

    test('dokunuş Yarış sekmesine yönlenir', () {
      expect(
        LocalNotificationTapRouter.targetForPayload(
          LocalNotificationPayload.contestReminder,
        ),
        PushTapTarget.playTab,
      );
    });
  });

  group('sunucu tercihleri', () {
    test(
      'düello/arkadaş değişikliği kirli işaretlenir, push başarırsa temizlenir',
      () async {
        final (service, _) = await _service();
        final repo = MockZanKurdRepository();
        await service.setDuelOn(false);
        expect(service.serverPrefsDirty, isTrue);

        expect(await PushPrefsSync.push(service, repo), isTrue);

        expect(service.serverPrefsDirty, isFalse);
        final flags = (await repo.loadAccountFlags())!;
        expect(flags.pushDuel, isFalse);
        expect(flags.pushSocial, isTrue);
      },
    );

    test('kirli yerel değişiklik sunucu değeriyle EZİLMEZ', () async {
      final (service, _) = await _service();
      final repo = MockZanKurdRepository();
      await repo.setPushPreferences(duel: true, social: true);
      await service.setSocialOn(false);

      await PushPrefsSync.reconcile(service, repo);

      // Kirli değişiklik sunucuya yazıldı, yerel değer korundu.
      expect(service.socialOn, isFalse);
      expect((await repo.loadAccountFlags())!.pushSocial, isFalse);
      expect(service.serverPrefsDirty, isFalse);
    });

    test('kirli değilken sunucudaki değer yerele alınır', () async {
      final (service, _) = await _service();
      final repo = MockZanKurdRepository();
      await repo.setPushPreferences(duel: false, social: false);

      await PushPrefsSync.reconcile(service, repo);

      expect(service.duelOn, isFalse);
      expect(service.socialOn, isFalse);
    });

    test('NotificationSync servis kurulu değilse sessizce döner', () async {
      NotificationService.resetInstance();
      await NotificationSync.run(MockZanKurdRepository());
    });
  });

  group('kanal adı', () {
    test('arkadaş kanalı sabit Kurmancî yazılmaz, K anahtarından gelir', () {
      final source = File(
        'lib/src/services/notification_service.dart',
      ).readAsStringSync();
      expect(source, isNot(contains("'ZanKurd Daxwazên Hevaltiyê'")));
      expect(source, contains('K.notifChannelFriendName'));
    });
  });
}
