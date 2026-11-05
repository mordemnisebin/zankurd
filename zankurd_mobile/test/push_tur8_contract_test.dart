/// Bildirim denetimi (GPT-6 Pro ALAN 4) — bant, Edge ve betik bekçisi.
///
/// ## Kusurlar
///
/// * Ön plan bandı gelen metni doğrudan gösteriyor, yerel anahtarı/tür
///   tercihini sormuyordu: tercih kapatılmadan önce gönderilmiş ya da tercih
///   eşitlemesi başarısızken gelen push, kapatılmış türde bile görünürdü.
/// * `apple-revoke` Apple jeton okuma hatasını "jeton yok" (200 `no_token`)
///   diye döndürüyordu; istemci hesabı silip (ON DELETE CASCADE) yeniden
///   deneme jetonunu da yok ediyordu. Apple kimliği olmayan oturum da özel
///   anahtarla JWT imzalatıp Apple takasını başlatabiliyordu.
/// * `send-push` aynı işi yeniden gönderdiğinde (ACK düşünce lease yeniden
///   alınır) Android'de ikinci sistem bildirimi doğuyordu (tag/collapse yok).
/// * `AppDelegate` UNUserNotificationCenter delegesini bağlamıyor: FCM
///   olmayan yerel bildirim dokunuşları Flutter'a ulaşmıyordu.
/// * `tool/bildirim_kur.sh` V1 göçünü uyguluyor, sıfır iş yanıtını teslimat
///   kanıtı sayıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbiri hata üretmez: bant "çalışır", 200 yanıt "başarılı" görünür, tek
/// sistem bildirimi yerine iki gelir, dokunuş sessizce düşer. Edge/Swift/betik
/// canlıya dağıtılmadan metin olarak sabitlenir; davranış Deno testleri
/// (`supabase/functions/*/lib_test.ts`) ve cihaz turuyla doğrulanır.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';
import 'package:zankurd_mobile/src/widgets/foreground_push_banner.dart';

class _Gateway implements LocalNotificationGateway {
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
  }) async {}
  @override
  Future<void> cancel(int id) async {}
  @override
  Future<void> cancelAll() async {}
}

class _Tr implements TimeZoneResolver {
  @override
  Future<String?> resolve() async => 'Europe/Berlin';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ön plan bandı yerel tercihi sorar', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'zankurd.language': 'tr'});
      NotificationService.resetInstance();
    });
    tearDown(NotificationService.resetInstance);

    Widget app(StreamController<ForegroundPush> events) => MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(initialLang: 'tr'),
        ),
      ],
      child: MaterialApp(
        builder: (context, child) =>
            ForegroundPushBanner(events: events.stream, child: child!),
        home: const Scaffold(body: Text('ana ekran')),
      ),
    );
    const request = ForegroundPush(
      title: 'ZanKurd',
      body: 'Diyar daxwaza hevaltiyê şand · Diyar arkadaşlık isteği gönderdi',
      data: {'kind': 'friend_request'},
    );
    final banner = find.byKey(const ValueKey('foreground-push-banner'));

    testWidgets('sosyal tercih kapalıyken bant açılmaz', (tester) async {
      final service = await tester.runAsync(() async {
        final s = await NotificationService.load(
          timeZoneResolver: _Tr(),
          gateway: _Gateway(),
        );
        await s.setEnabled(true);
        await s.setSocialOn(false);
        return s;
      });
      expect(service, isNotNull);
      final events = StreamController<ForegroundPush>.broadcast();
      await tester.pumpWidget(app(events));
      events.add(request);
      await tester.pump();
      expect(banner, findsNothing);
    });

    testWidgets('görünür bant, tercih kapanınca kalkar', (tester) async {
      final service = (await tester.runAsync(() async {
        final s = await NotificationService.load(
          timeZoneResolver: _Tr(),
          gateway: _Gateway(),
        );
        await s.setEnabled(true);
        return s;
      }))!;
      final events = StreamController<ForegroundPush>.broadcast();
      await tester.pumpWidget(app(events));
      events.add(request);
      await tester.pump();
      expect(banner, findsOneWidget);
      await tester.runAsync(() => service.setSocialOn(false));
      await tester.pump();
      expect(banner, findsNothing);
    });
  });

  group('Edge / Swift / betik sözleşmesi', () {
    String read(String path) => File(path).readAsStringSync();

    test(
      'apple-revoke: okuma hatası no_token değildir, Apple kimliği şart',
      () {
        final src = read('supabase/functions/apple-revoke/index.ts');
        expect(src, contains('readError'));
        expect(src, contains('token_read_failed'));
        expect(src, contains('hasAppleIdentity(user)'));
        expect(src, contains('apple_identity_required'));
        expect(src, contains('registerRecentlyDone'));
        // Hata dalı no_token dalından ÖNCE gelmeli.
        expect(
          src.indexOf('token_read_failed'),
          lessThan(src.indexOf('reason: "no_token"')),
        );
        // Eski istemciler: yanıt biçimleri (registered/revoked) değişmedi.
        expect(src, contains('json({ registered: true'));
        expect(src, contains('json({ revoked: true })'));
      },
    );

    test('send-push: aynı iş aynı Android tag + APNs collapse-id', () {
      final lib = read('supabase/functions/send-push/lib.ts');
      // 2026-11-16: aynı nesneye türe göre `channel_id` da eklenir (W4 #19).
      expect(lib, contains('tag: pushCollapseId(job.job_id)'));
      expect(lib, contains('"apns-collapse-id": pushCollapseId(job.job_id)'));
      final py = read('tool/send_push_outbox.py');
      expect(py, contains('"apns-collapse-id": collapse_id(job["job_id"])'));
      expect(
        py,
        contains('"notification": {"tag": collapse_id(job["job_id"])}'),
      );
    });

    test('AppDelegate yerel bildirim delegesini bağlar (super öncesi)', () {
      final swift = read('ios/Runner/AppDelegate.swift');
      expect(swift, contains('import UserNotifications'));
      final assign = swift.indexOf(
        'UNUserNotificationCenter.current().delegate = self',
      );
      expect(assign, greaterThan(0));
      expect(assign, lessThan(swift.indexOf('return super.application(')));
    });

    test(
      'bildirim_kur.sh V1 göçünü uygulamaz, V2 önkoşulu ve sıfır iş uyarısı',
      () {
        final sh = read('tool/bildirim_kur.sh');
        final code = sh
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('#'))
            .join('\n');
        expect(
          code,
          isNot(contains('-f supabase/2026-10-13_push_delivery.sql')),
        );
        expect(code, contains('claim_push_outbox_v2'));
        expect(code, contains("jobname = 'send-push' and active"));
        expect(code, contains('TESLİMAT KANITI DEĞİLDİR'));
        // Dağıtım, önkoşul denetiminden SONRA.
        expect(
          code.indexOf('claim_push_outbox_v2'),
          lessThan(code.indexOf('supabase functions deploy send-push')),
        );
      },
    );

    test('main.dart: Firebase geç hazır olunca da abonelikler kurulur', () {
      final main = read('lib/main.dart');
      expect(main, contains('onLateReady: wireFirebasePush'));
      expect(main, contains('Future<void> wireFirebasePush()'));
    });

    test('hesap değişiminde seri alarmı yeniden değerlendirilir', () {
      final auth = read('lib/src/providers/auth_provider.dart');
      final drop = auth.indexOf('void _dropProgressMemory()');
      final sync = auth.indexOf(
        'NotificationService.syncStreakWarning()',
        drop,
      );
      expect(drop, greaterThan(0));
      expect(sync, greaterThan(drop));
    });
  });
}
