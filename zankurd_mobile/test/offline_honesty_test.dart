// 2026-09-29 Şahnê: "Rakip bul" `SahneButton.primary`dir (kilitliyken
// `onPressed: null`); ilk içerik ölçümü marka satırının logosundan yapılır;
// düello manşeti ve süresi iki ayrı satırdır.
/// "Çevrimdışı / sunucuya ulaşılamıyor" durumunda kabuğun dürüstlüğü:
/// yerleşim ikiye katlanmasın, metin yalan söylemesin, pasif düğme etkin
/// görünmesin.
///
/// ## Kusur
///
/// 2026-09-27 simülatör turunda aynı kökten dört kusur görüldü
/// (`RemoteAvailability(reachable: false)` — sunucuya HİÇ ulaşılamıyor):
///
/// 1. `AppShell._buildScaffold`: bant (`OfflineBanner`) görünürken üst
///    güvenli alanı bandın KENDİSİ karşılıyor (dekorasyonu kendi
///    `SafeArea`sını dıştan sarar), ama paylaşılan `content` bunu bilmeden
///    aynı boşluğu ikinci kez ekliyordu — bant ile ilk içerik arasında
///    boş, dokunulmamış bir şerit kalıyor, kaydırılan içerik de altta o
///    kadarlık kısmı kırpılıyordu.
/// 2. `ProfileScreen._SyncStatusChip`: sunucuya hiç ulaşılamıyorken de
///    (çevrimdışı misafir) bekleyen/başarısız kayıt olmayınca "Bulutla
///    senkronize" diyordu — bulut hiç yokken bulutla senkronize olduğunu
///    iddia ediyordu.
/// 3. `PlayHubScreen`teki `_QuickDuelHero`: kilitliyken (`onTap == null`)
///    tam turuncu ve etkin görünmeye devam ediyordu; dokununca hiçbir şey
///    olmuyordu ama kullanıcı bunu göremiyordu.
/// 4. `K.leaderboardHowTo`: öğrenme sorularının sıralamaya saydığını
///    söylüyordu — oysa yalnız yarış puanı sayılır (boş durum metni zaten
///    doğrusunu söylüyordu: "Bir yarış başlat; puanların burada görünür.").
///
/// ## Niçin sessiz kalırdı
///
/// 1-3 yalnız kilit modunda (`RemoteAvailability(reachable: false)`) görünür
/// hâle gelir; mevcut widget testlerinin büyük çoğunluğu erişilebilir
/// varsayılan durumu ölçer ve `AppShell` testleri gerçek cihaz güvenli alan
/// dolgusu (`withDeviceInsets`) olmadan koşar — sıfır dolguda iki kez
/// eklenen "sıfır" da sıfırdır, kusur görünmez. 4 saf bir metin yanlışıydı;
/// hiçbir test `K.leaderboardHowTo`nun DEĞERİNİ sabitlemiyordu, yalnız
/// varlığını.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction;
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/widgets/offline_banner.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

void main() {
  group('1) Çift üst boşluk: bant + kilitli kabuk', () {
    testWidgets(
      'kilitliyken bant ile ana ekranın ilk içeriği arasında boş şerit kalmaz',
      (tester) async {
        await tester.binding.setSurfaceSize(kPhoneSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          testShell(
            remoteAvailability: RemoteAvailability(reachable: false),
            child: withDeviceInsets(
              AppShell(
                repository: freshMockRepository(),
                // Gerçek monitör koşucuda çözülmeyen bir future bırakır.
                connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Kilit modunda `_statusBanner` her zaman `isOffline: true` döner
        // (bkz. `RemoteAvailability.socialLockedIn`); bant gerçekten çizilir.
        final bannerBottom = tester
            .getBottomLeft(find.byType(OfflineBanner))
            .dy;
        // 2026-09-29 Şahnê: ekranın ilk içeriği A iskeletinin marka
        // satırıdır; ölçüm onun logo işaretinden ("ZanKurd") yapılır. Eski
        // anahtar (`home-profile-header`) artık marka satırının SAĞINDAKİ
        // çiplerdedir ve dar telefonda (375) çipler ikinci satıra inebilir —
        // bu bir boşluk değil, tasarımın kendi sarması.
        final contentTop = tester.getTopLeft(find.text('ZanKurd').first).dy;
        final gap = contentTop - bannerBottom;

        expect(
          gap,
          lessThanOrEqualTo(32),
          reason:
              'Bant görünürken üst güvenli alanı ZATEN karşılıyor; '
              '`content`teki `SafeArea` aynı boşluğu ikinci kez eklerse '
              'bant ile ilk içerik arasında boş bir şerit kalır (kusur '
              '~59pt üretiyordu) ve kaydırılan içerik altta kırpılır.',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bant görünmüyorken davranış değişmez: tek güvenli alan uygulanır',
      (tester) async {
        await tester.binding.setSurfaceSize(kPhoneSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          testShell(
            remoteAvailability: RemoteAvailability(reachable: true),
            child: withDeviceInsets(
              AppShell(
                repository: freshMockRepository(),
                connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Bant `isOffline: false` ile çizilir: `AnimatedSize` onu 0 yüksekliğe
        // katlar ama widget ağaçta kalır (bkz. `offline_banner.dart`).
        expect(
          tester.getSize(find.byType(OfflineBanner)).height,
          0,
          reason: 'Bant görünmüyorken hiçbir dikey alan kaplamamalı.',
        );

        final contentTop = tester
            .getTopLeft(find.byKey(const ValueKey('home-profile-header')))
            .dy;

        // Tek karşılayıcı `content`teki `SafeArea`dır: üst boşluk cihazın
        // çentik/durum çubuğu yüksekliği (59pt) kadar olmalı — ne SIFIR
        // (yanlışlıkla `removePadding` bant yokken de uygulanmış olur), ne
        // de ÇİFT (~118pt, düzeltmeden önceki kusurun aynısı).
        expect(
          contentTop,
          inInclusiveRange(kPhoneInsets.top, kPhoneInsets.top + 40),
          reason:
              'Bant yokken `rawContent` DOKUNULMADAN kullanılır; üst boşluk '
              'tek bir güvenli alan dolgusu kadar olmalı.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('2) Yalan "Bulutla senkronize"', () {
    setUp(() async {
      // İki testin de "bekleyen/başarısız kayıt yok" (isSynced) tabanından
      // başladığından emin ol; statik `ValueNotifier`lar süreç genelindedir.
      await SyncManager.resetForTesting();
    });

    testWidgets(
      'kilitliyken çip "Yalnız bu cihazda" der; "Bulutla senkronize" YOK',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(
          testShell(
            remoteAvailability: RemoteAvailability(reachable: false),
            child: Scaffold(
              body: ProfileScreen(repository: MockZanKurdRepository()),
            ),
          ),
        );
        for (
          var i = 0;
          i < 40 && find.text('Yalnız bu cihazda').evaluate().isEmpty;
          i++
        ) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(
          find.text('Yalnız bu cihazda'),
          findsOneWidget,
          reason: 'Sunucuya hiç ulaşılamıyorken çip nötr/dürüst olmalı.',
        );
        expect(
          find.text('Bulutla senkronize'),
          findsNothing,
          reason: 'Bulut hiç yokken "bulutla senkronize" YALAN söyler.',
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('erişilebilirken eski davranış korunur: "Bulutla senkronize"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: true),
          child: Scaffold(
            body: ProfileScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      for (
        var i = 0;
        i < 40 && find.text('Bulutla senkronize').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Bulutla senkronize'), findsOneWidget);
      expect(find.text('Yalnız bu cihazda'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('3) Etkin görünen ama çalışmayan "Rakip bul"', () {
    testWidgets('kilitliyken alt satır "Sunucuya ulaşılamadı" ve düğme pasif', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: false),
          child: PlayHubScreen(repository: MockZanKurdRepository()),
        ),
      );
      await tester.pumpAndSettle();

      final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
      expect(
        find.descendant(of: hero, matching: find.text('Sunucuya ulaşılamadı')),
        findsOneWidget,
        reason:
            'Oda kartlarıyla aynı desen: kilitliyken alt satır dürüst olmalı.',
      );
      expect(
        find.descendant(of: hero, matching: find.text('Seviyene yakın rakip')),
        findsNothing,
      );

      // 2026-09-29 Şahnê: düğme `SahneButton.primary`; kilitliyken
      // `onPressed: null` — bileşenin pasif hâli (Perde + üçüncül metin,
      // gölgesiz), turuncu değil. Kartın ekran okuyucu düğümü de kapalı.
      final button = tester.widget<SahneButton>(
        find.descendant(
          of: find.byKey(const ValueKey('play-hub-quick-duel-cta')),
          matching: find.byType(SahneButton),
        ),
      );
      expect(
        button.onPressed,
        isNull,
        reason: 'Dokununca hiçbir şey olmamalı; buton gerçekten kapalı.',
      );
      final data = tester.getSemantics(hero).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erişilebilirken eski davranış korunur: turuncu ve etkin', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: true),
          child: PlayHubScreen(repository: MockZanKurdRepository()),
        ),
      );
      await tester.pumpAndSettle();

      // Manşet ve süre maketteki gibi iki satır ("Seviyene yakın rakip",
      // "~2 dakika").
      final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
      expect(
        find.descendant(of: hero, matching: find.text('Seviyene yakın rakip')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.text('~2 dakika')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: hero, matching: find.text('Sunucuya ulaşılamadı')),
        findsNothing,
      );

      final button = tester.widget<SahneButton>(
        find.descendant(
          of: find.byKey(const ValueKey('play-hub-quick-duel-cta')),
          matching: find.byType(SahneButton),
        ),
      );
      expect(button.onPressed, isNotNull);
      final data = tester.getSemantics(hero).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  group('4) Yanıltıcı Liderlik alt başlığı', () {
    test(
      'K.leaderboardHowTo artık yalnız yarışların puan verdiğini söyler',
      () {
        expect(
          Tr.of(K.leaderboardHowTo, AppLanguage.tr),
          'Yarışlarda puan topla, sıralamada yüksel.',
        );
        expect(
          Tr.of(K.leaderboardHowTo, AppLanguage.ku),
          'Di pêşbirkan de pûanan kom bike, bilind bibe.',
        );
        // Öğrenme soruları sıralamaya saymadığı hâlde "soru çöz" diye vaat
        // eden eski dile bir daha izin verilmez.
        expect(
          Tr.of(K.leaderboardHowTo, AppLanguage.tr),
          isNot(contains('Soru çöz')),
        );
        expect(
          Tr.of(K.leaderboardHowTo, AppLanguage.ku),
          isNot(contains('Pirsan çareser bike')),
        );
      },
    );
  });

  group('5) Çevrimdışı sıralama "henüz puan yok" demez', () {
    // 2026-09-27 simülatör turu: sunucuya ulaşılamazken çevrimdışı depo boş
    // liste döndürüyor, sıralama da "Henüz puan yok, bir yarış başlat"
    // diyordu. Sunucuda puanı olan oyuncuya bu yanlış: liste boş değil,
    // okunamadı.
    Future<void> pumpBoard(WidgetTester tester, {required bool locked}) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          remoteAvailability: RemoteAvailability(reachable: !locked),
          child: Scaffold(body: LeaderboardScreen(repository: _EmptyBoard())),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('kilitliyken "yüklenemedi" ve yeniden dene gösterilir', (
      tester,
    ) async {
      await pumpBoard(tester, locked: true);
      expect(find.text('Henüz puan yok'), findsNothing);
      expect(find.text('Yüklenemedi'), findsOneWidget);
      expect(find.text('Bağlantıyı kontrol edip tekrar dene.'), findsOneWidget);
    });

    testWidgets('bağlıyken boş liste yine "henüz puan yok" der', (
      tester,
    ) async {
      await pumpBoard(tester, locked: false);
      expect(find.text('Henüz puan yok'), findsOneWidget);
      expect(find.text('Yüklenemedi'), findsNothing);
    });
  });
}

class _EmptyBoard extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => const [];

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}
