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
      // davranışıyla (`_consumeJoinDeepLink`) aynı sözleşmedir.
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
}
