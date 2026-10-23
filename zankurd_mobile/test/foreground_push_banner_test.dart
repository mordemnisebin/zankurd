/// Uygulama AÇIKKEN gelen push'un üstte bant olarak gösterilmesi.
///
/// ## Kusur
///
/// Kodda `FirebaseMessaging.onMessage` dinleyicisi yoktu ve iOS ön plan
/// sunum seçenekleri açık değildi: uygulama açıkken arkadaşlık isteği, oda
/// daveti ya da düello daveti geldiğinde işletim sistemi bildirimi göstermez
/// ve uygulama da kendisi göstermezdi. Oyuncu en çok açıkken davet
/// beklerken hiçbir şey görmüyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Sunucu "gönderildi" der, FCM teslim eder; ileti ön plandaki uygulamaya
/// ulaşır ve sessizce düşer. Ne hata ne log çıkar. Bandı eklerken de iki
/// hata sessiz kalabilir: iki dilli gövdenin ("KU · TR") ham halde
/// gösterilmesi ve "Aç"ın dokunuşla farklı bir yere götürmesi.
///
/// ## Bekçi
///
/// Bu dosya: iletinin bant olarak görünmesini, arayüz diline göre
/// bölünmesini, "Aç"ın [PushTapRouter] hedefine gitmesini, görünür metni
/// olmayan (yalnız veri) iletinin bant açmamasını ve iOS'ta sistem afişi ile
/// çift gösterim doğuracak ön plan sunum seçeneğinin hiç açılmadığını ölçer.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/services/foreground_push_center.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';
import 'package:zankurd_mobile/src/widgets/foreground_push_banner.dart';

import 'social_push_prompt_test.dart' show FakePushGateway;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PushTapRouter.resetForTest);
  tearDown(() {
    PushTapRouter.resetForTest();
    ForegroundPushCenter.resetForTest();
    PushMessaging.resetForTest();
  });

  Widget app(StreamController<ForegroundPush> events, {String lang = 'tr'}) =>
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(initialLang: lang),
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
  final open = find.byKey(const ValueKey('foreground-push-open'));

  testWidgets('ileti bant olarak görünür; gövde Türkçe arayüzde TR yarısı', (
    tester,
  ) async {
    final events = StreamController<ForegroundPush>.broadcast();
    await tester.pumpWidget(app(events));
    expect(banner, findsNothing);

    events.add(request);
    await tester.pump();

    expect(banner, findsOneWidget);
    expect(find.text('Diyar arkadaşlık isteği gönderdi'), findsOneWidget);
    expect(find.textContaining('daxwaza'), findsNothing);
    expect(find.text('ZanKurd'), findsOneWidget);
    // Süre dolunca kendiliğinden kapanır.
    await tester.pump(const Duration(seconds: 7));
    expect(banner, findsNothing);
  });

  testWidgets('Kurmancî arayüzde KU yarısı gösterilir', (tester) async {
    final events = StreamController<ForegroundPush>.broadcast();
    await tester.pumpWidget(app(events, lang: 'ku'));
    events.add(request);
    await tester.pump();
    expect(find.text('Diyar daxwaza hevaltiyê şand'), findsOneWidget);
    expect(find.textContaining('arkadaşlık'), findsNothing);
    await tester.pump(const Duration(seconds: 7));
  });

  test('iki dilli gövde ayrıştırma: ayrılamazsa tamamı', () {
    expect(splitBilingualPushText('A · B', ku: true), 'A');
    expect(splitBilingualPushText('A · B', ku: false), 'B');
    expect(splitBilingualPushText('Tek dilli', ku: false), 'Tek dilli');
    expect(splitBilingualPushText('A · B · C', ku: false), 'A · B · C');
    expect(splitBilingualPushText('A ·  ', ku: false), 'A ·  ');
  });

  testWidgets('"Aç" dokunuşla aynı hedefe götürür ve bandı kapatır', (
    tester,
  ) async {
    final events = StreamController<ForegroundPush>.broadcast();
    await tester.pumpWidget(app(events));
    events.add(request);
    await tester.pump();

    await tester.tap(open);
    await tester.pump();

    expect(PushTapRouter.pending.value, PushTapTarget.friends);
    expect(banner, findsNothing);
  });

  testWidgets('oda ve düello davetleri kendi hedeflerine gider', (
    tester,
  ) async {
    final events = StreamController<ForegroundPush>.broadcast();
    await tester.pumpWidget(app(events));
    for (final (kind, target) in [
      ('room_invite', PushTapTarget.roomInvite),
      ('async_duel_invite', PushTapTarget.duelInbox),
    ]) {
      events.add(
        ForegroundPush(title: 'ZanKurd', body: 'x', data: {'kind': kind}),
      );
      await tester.pump();
      await tester.tap(open);
      await tester.pump();
      expect(PushTapRouter.take(), target, reason: kind);
    }
  });

  testWidgets('yalnız veri taşıyan ileti bant açmaz; bilinmeyen tür "Aç" '
      'göstermez', (tester) async {
    final events = StreamController<ForegroundPush>.broadcast();
    await tester.pumpWidget(app(events));
    events.add(const ForegroundPush(data: {'kind': 'friend_request'}));
    await tester.pump();
    expect(banner, findsNothing);

    events.add(const ForegroundPush(title: 'ZanKurd', body: 'Duyuru'));
    await tester.pump();
    // Akış olayı mikro görevle ulaşır; ikinci kare setState'in çizimini verir.
    await tester.pump();
    expect(banner, findsOneWidget);
    expect(open, findsNothing);
    await tester.pump(const Duration(seconds: 7));
  });

  test(
    'ForegroundPushCenter ağ geçidinin ön plan iletilerini yayınlar',
    () async {
      final gateway = FakePushGateway();
      PushMessaging.gateway = gateway;
      ForegroundPushCenter.wire();
      final next = ForegroundPushCenter.events.first;
      gateway.controller.add(request);
      expect((await next).kind, 'friend_request');
    },
  );

  test('iOS ön plan sunum seçeneği açılmaz (çift gösterim olurdu)', () {
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      expect(
        entity.readAsStringSync(),
        isNot(contains('setForegroundNotificationPresentationOptions(')),
        reason: entity.path,
      );
    }
  });
}
