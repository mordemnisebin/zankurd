/// Uygulama açıkken ve soğuk açılışta gelen `/join/<KOD>` bağlantısı.
///
/// ## Kusur
///
/// `main.dart` `MaterialApp`'i adlı-rota tablosu olmadan (`onGenerateRoute`
/// yok, `routes` yalnız "/" içerir) kuruyordu. Flutter 3.44'te mobil deep
/// linking varsayılan açık olduğundan:
///
/// * SOĞUK açılışta platform `defaultRouteName`i `/join/KOD` gibi bir yol
///   yapabiliyordu; Navigator ilk rotayı `/`, `/join`, `/join/KOD` parçalarına
///   bölüp her biri için rota üretmeye çalışıyor, üretemeyince
///   `FlutterError.reportError` ile bildirip `/`e düşüyordu.
/// * SICAK açılışta (uygulama zaten önplandayken bağlantıya dokunma)
///   `WidgetsApp`'in dahili `didPushRouteInformation` gözlemcisi
///   `Navigator.pushNamed('/join/KOD')` çağırıyor, bu da "Could not find a
///   generator for route" hatasıyla fırlıyordu — kod hiç tüketilmiyordu.
///
/// İkisinde de uygulama "çökmüyordu" (hata yalnız raporlanıyordu) ama davet
/// bağlantısı sessizce hiçbir şey yapmıyordu: oda hiç açılmıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Uygulama her iki durumda da "düzgün" bir ekranla açıldığı (ana sayfa)
/// için kimse bunu fark etmiyordu — yalnız davet ETKİSİZDİ. Ne
/// `defaultRouteName` özelleştirilerek ne de `didPushRouteInformation`
/// simüle edilerek test edilmiyordu.
///
/// Bu dosya iki düzeltmeyi birden sabitler: `ZanKurdApp._buildInitialRoutes`
/// (soğuk açılış, `main.dart`) ve `JoinDeepLinkScope` + `AppShell`in
/// `JoinDeepLink.incoming` dinleyicisi (sıcak açılış). Kapsam `MaterialApp`in
/// ÜSTÜNDE durduğu için gözlemcisi `WidgetsApp`inkinden önce sorulur;
/// `pushNamed` denemesi hiç yapılmaz ve çökme raporlamasına sahte hata
/// düşmez — sıcak açılış testleri bu yüzden `takeException()`in null
/// olduğunu da denetler.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/utils/join_deep_link.dart';

import 'support/widget_test_helpers.dart';

/// `joinOnlineRoom`a giden KODU birebir kaydeder — sonuç ekranındaki oda
/// koduna bakarak dolaylı çıkarım yapmak yerine çağrının kendisini doğrular.
class _JoinRepository extends MockZanKurdRepository {
  final List<String> joinCalls = [];
  Object? joinError;

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    joinCalls.add(code);
    final error = joinError;
    if (error != null) throw error;
    return createRoom().copyWith(code: code);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // `JoinDeepLink`in durumu statik/işlem-genelidir; önceki bir testte
    // tüketilmeden kalmış bir kod ya da tekrar-penceresi kaydı bu testi
    // sessizce etkileyebilir.
    JoinDeepLink.resetForTest();
  });

  tearDown(JoinDeepLink.resetForTest);

  group('sıcak açılış (didPushRouteInformation)', () {
    late _JoinRepository repository;
    late FakeAuthProvider authProvider;

    setUp(() {
      // Ortak yardımcı hem paylaşımlı tercih bayraklarını (onboarding,
      // profil adı) hem de kullanıcıya bağlı yerel depoları sıfırlar —
      // dönüş değeri kullanılmasa da yan etkisi için çağrılır (bkz.
      // `app_shell_room_resume_test.dart`taki aynı desen).
      freshMockRepository();
      repository = _JoinRepository();
      authProvider = FakeAuthProvider();
    });

    Future<void> pumpShell(WidgetTester tester) async {
      await tester.pumpWidget(
        JoinDeepLinkScope(
          child: testShell(
            authProvider: authProvider,
            child: AppShell(
              repository: repository,
              connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'join koduna çözülen yol joinOnlineRoomu doğru kodla çağırır ve '
      'RoomScreen açar',
      (tester) async {
        await pumpShell(tester);

        final handled = await tester.binding.handlePushRoute(
          '/join/ZK-ABCDEF0123',
        );
        await tester.pumpAndSettle();

        // Kapsam `WidgetsApp`in gözlemcisinden önce sorulduğu için
        // `pushNamed` denemesi hiç yapılmaz: raporlanan hata YOK.
        expect(tester.takeException(), isNull);

        expect(handled, isTrue);
        expect(repository.joinCalls, ['ZK-ABCDEF0123']);
        expect(find.byType(RoomScreen), findsOneWidget);
        final screen = tester.widget<RoomScreen>(find.byType(RoomScreen));
        expect(screen.initialRoom.code, 'ZK-ABCDEF0123');
      },
    );

    testWidgets('küçük harfli yol da büyütülüp işlenir', (tester) async {
      await pumpShell(tester);

      await tester.binding.handlePushRoute('/join/zk-abcdef0123');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(repository.joinCalls, ['ZK-ABCDEF0123']);
    });

    testWidgets('ilgisiz yol false döner ve hiçbir şey açılmaz', (
      tester,
    ) async {
      await pumpShell(tester);

      final handled = await tester.binding.handlePushRoute('/ayarlar');
      await tester.pumpAndSettle();
      // Davet olmayan yol kapsamdan geçer (`false`) ve `WidgetsApp`e
      // bırakılır; onun bilinmeyen bir adla başarısız `pushNamed` denemesi
      // çerçevenin kendi davranışıdır, bu dosyanın konusu değil.
      tester.takeException();

      expect(handled, isFalse);
      expect(repository.joinCalls, isEmpty);
      expect(find.byType(RoomScreen), findsNothing);
    });

    testWidgets(
      'aynı bağlantı iki kez iletilirse joinOnlineRoom bir kez çağrılır',
      (tester) async {
        await pumpShell(tester);

        await tester.binding.handlePushRoute('/join/ZK-ABCDEF0123');
        await tester.pumpAndSettle();
        await tester.binding.handlePushRoute('/join/ZK-ABCDEF0123');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        expect(repository.joinCalls, ['ZK-ABCDEF0123']);
        expect(find.byType(RoomScreen), findsOneWidget);
      },
    );

    testWidgets('sosyal kilit açıkken bağlantı katılmaya çevrilmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        JoinDeepLinkScope(
          child: testShell(
            authProvider: authProvider,
            remoteAvailability: RemoteAvailability(reachable: false),
            child: AppShell(
              repository: repository,
              connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePushRoute(
        '/join/ZK-ABCDEF0123',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Yol yine de bir join koduna ÇÖZÜLÜR (true) — yalnız asıl katılma
      // (sosyal kilit yüzünden) tetiklenmez. Bu, mevcut soğuk açılış
      // davranışıyla (`_tryOpenJoinCode`) aynı sözleşmedir.
      expect(handled, isTrue);
      expect(repository.joinCalls, isEmpty);
      expect(find.byType(RoomScreen), findsNothing);
    });
  });

  group('tekrar penceresi (JoinDeepLink.offer)', () {
    // Aynı kodun kısa aralıkla ikinci kez gelmesi (Android'in öne getirilen
    // etkinliğe intent'i yeniden yollaması) tek davettir; ama oyuncu odadan
    // çıkıp AYNI davete sonradan yeniden dokunabilmeli. İlk uygulama aynı
    // yolu oturum boyunca kalıcı olarak yok sayıyordu.
    test('pencere içinde tekrar yok sayılır, sonrasında yeniden işlenir', () {
      final t0 = DateTime(2026, 9, 27, 12);
      const route = '/join/ZK-ABCDEF0123';

      expect(JoinDeepLink.offer(route, now: t0), isTrue);
      expect(JoinDeepLink.takeIncoming(), 'ZK-ABCDEF0123');

      expect(
        JoinDeepLink.offer(route, now: t0.add(const Duration(seconds: 1))),
        isTrue,
      );
      expect(JoinDeepLink.takeIncoming(), isNull);

      expect(
        JoinDeepLink.offer(route, now: t0.add(const Duration(seconds: 5))),
        isTrue,
      );
      expect(JoinDeepLink.takeIncoming(), 'ZK-ABCDEF0123');
    });

    test('davet olmayan yol işlenmez', () {
      expect(JoinDeepLink.offer('/ayarlar'), isFalse);
      expect(JoinDeepLink.takeIncoming(), isNull);
    });
  });

  group('kod ve alan adı süzgeci (JoinDeepLink.parse)', () {
    // Eskiden her `/join/<metin>` büyük harfe çevrilip doğrudan
    // `join_room_by_code` RPC'sine gidiyordu; bozuk ya da yabancı alan adlı
    // bir bağlantı sunucuya boşuna istek ve oyuncuya anlamsız "oda
    // bulunamadı" hatası üretiyordu. Hiçbir test bunu yakalamıyordu çünkü
    // bütün testler geçerli kodla çalışıyordu.
    test('geçerli oda ve meydan okuma kodları kabul edilir', () {
      expect(
        JoinDeepLink.parse('https://www.zankurd.com/join/zk-abcdef0123'),
        'ZK-ABCDEF0123',
      );
      expect(
        JoinDeepLink.parse('https://zankurd.com/join/DK7M2Q9XA'),
        'DK7M2Q9XA',
      );
      expect(JoinDeepLink.parse('/join/ZK-ABCDEF0123'), 'ZK-ABCDEF0123');
    });

    test('6 rakamlı oda kodu kabul edilir ve meydan okumayla karışmaz', () {
      expect(
        JoinDeepLink.parse('https://www.zankurd.com/join/482913'),
        '482913',
      );
      expect(JoinDeepLink.isChallengeCode('482913'), isFalse);
      expect(JoinDeepLink.isChallengeCode('DK7M2Q9XA'), isTrue);
      // Rakamla başlayan kod hiçbir koşulda meydan okuma kodu değildir.
      expect(JoinDeepLink.parse('/join/48291'), isNull);
      expect(JoinDeepLink.parse('/join/4829131'), isNull);
    });

    test('biçimi tutmayan kod reddedilir', () {
      expect(JoinDeepLink.parse('/join/MERHABA'), isNull);
      expect(JoinDeepLink.parse('/join/ZK-'), isNull);
      expect(JoinDeepLink.parse('/join/D'), isNull);
      expect(JoinDeepLink.parse("/join/ZK-1';drop"), isNull);
    });

    test('yabancı alan adı reddedilir, web kendi adresine güvenir', () {
      const foreign = 'https://evil.example/join/ZK-ABCDEF0123';
      expect(JoinDeepLink.parse(foreign), isNull);
      expect(JoinDeepLink.parse(foreign, anyHost: true), 'ZK-ABCDEF0123');
    });

    test('geçersiz kodlu /join/ yolu yutulur ama davet üretmez', () {
      // `false` dönseydi WidgetsApp yolu pushNamed ile dener ve
      // Crashlytics'e sahte "route bulunamadı" hatası düşerdi.
      expect(JoinDeepLink.offer('/join/MERHABA'), isTrue);
      expect(JoinDeepLink.takeIncoming(), isNull);
    });
  });

  group('soğuk açılış (defaultRouteName)', () {
    testWidgets(
      'ilk rota /join/ZK-... iken uygulama hatasız açılır ve odaya katılır',
      (tester) async {
        freshMockRepository();
        final repository = _JoinRepository();

        tester.binding.platformDispatcher.defaultRouteNameTestValue =
            '/join/ZK-ABCDEF0123';
        addTearDown(() {
          tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
        });

        await tester.pumpWidget(
          ZanKurdApp(
            repository: repository,
            authProvider: FakeAuthProvider(),
            languageProvider: turkishLang(),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason:
              'ZanKurdApp._buildInitialRoutes ilk rotayı doğrudan üretir; '
              'Navigator’ın yol-parçalama denemesi hiç çalışmamalı.',
        );
        expect(repository.joinCalls, ['ZK-ABCDEF0123']);
        expect(find.byType(RoomScreen), findsOneWidget);
      },
    );

    testWidgets('ilk rota bilinmeyen bir yol iken de uygulama hatasız açılır', (
      tester,
    ) async {
      freshMockRepository();
      final repository = _JoinRepository();

      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/bilinmeyen/yol';
      addTearDown(() {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      });

      await tester.pumpWidget(
        ZanKurdApp(
          repository: repository,
          authProvider: FakeAuthProvider(),
          languageProvider: turkishLang(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(repository.joinCalls, isEmpty);
      expect(find.byType(RoomScreen), findsNothing);
    });
  });

  group('meydan okuma bağlantısı (/join/D…)', () {
    // Oyun ekranının 20 sn'lik sayacı `pumpAndSettle`ı bitirmez; ekran
    // görünene dek kısa adımlarla pompalanır.
    Future<void> pumpUntilPlay(WidgetTester tester) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        if (find.byType(AsyncDuelPlayScreen).evaluate().isNotEmpty) return;
      }
    }

    // Oda kodu ile meydan okuma kodu AYNI /join/ yolunu paylaşır; yanlış
    // ayrım bağlantıyı yanlış RPC'ye (oda katılımı) götürürdü.
    testWidgets('sıcak açılış: kabul edilir, oda katılımına GİTMEZ', (
      tester,
    ) async {
      freshMockRepository();
      final repository = _JoinRepository()
        ..addIncomingChallengeForTesting(friendChallenge: false);
      await tester.pumpWidget(
        JoinDeepLinkScope(
          child: testShell(
            authProvider: FakeAuthProvider(),
            child: AppShell(
              repository: repository,
              connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handled = await tester.binding.handlePushRoute('/join/dk7m2q9xa');
      await pumpUntilPlay(tester);

      expect(tester.takeException(), isNull);
      expect(handled, isTrue);
      expect(repository.joinCalls, isEmpty);
      expect(find.byType(RoomScreen), findsNothing);
      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
      final screen = tester.widget<AsyncDuelPlayScreen>(
        find.byType(AsyncDuelPlayScreen),
      );
      expect(screen.entry?.code, 'DK7M2Q9XA');
    });

    testWidgets('soğuk açılış: kabul edilir, oda katılımına GİTMEZ', (
      tester,
    ) async {
      freshMockRepository();
      final repository = _JoinRepository()
        ..addIncomingChallengeForTesting(friendChallenge: false);
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/join/DK7M2Q9XA';
      addTearDown(() {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      });

      await tester.pumpWidget(
        ZanKurdApp(
          repository: repository,
          authProvider: FakeAuthProvider(),
          languageProvider: turkishLang(),
        ),
      );
      await pumpUntilPlay(tester);

      expect(tester.takeException(), isNull);
      expect(repository.joinCalls, isEmpty);
      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
    });

    testWidgets('henüz oturum yokken gelen bağlantı girişten sonra açılır', (
      tester,
    ) async {
      freshMockRepository();
      final repository = _JoinRepository()
        ..addIncomingChallengeForTesting(friendChallenge: false);
      final auth = GateAuthProvider();
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/join/DK7M2Q9XA';
      addTearDown(() {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      });

      await tester.pumpWidget(
        ZanKurdApp(
          repository: repository,
          authProvider: auth,
          languageProvider: turkishLang(),
        ),
      );
      await tester.pumpAndSettle();
      // Giriş kapısındayız: oyun ekranı da hata da yok, kod bekliyor.
      expect(find.byType(AsyncDuelPlayScreen), findsNothing);
      expect(tester.takeException(), isNull);

      await auth.signInAsGuest();
      await pumpUntilPlay(tester);

      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
      expect(repository.joinCalls, isEmpty);
    });
  });
}
