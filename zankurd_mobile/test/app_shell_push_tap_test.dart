/// [AppShell]in bekleyen bildirim dokunuşunu ([PushTapRouter]) doğru sekmeye
/// ve gerektiğinde doğru ekrana uyguladığını doğrular.
///
/// ## Kusur
///
/// `PushTapRouter` yalnızca `kind`i bir [PushTapTarget]e çözüp `pending`e
/// yazıyordu; kabuk tarafında onu OKUYAN ve UYGULAYAN hiçbir kod yoksa
/// oyuncu yine ana ekranda kalırdı — tıpkı `JoinDeepLink.incoming`in
/// `AppShell` dinlemeden önceki hâli gibi (bkz.
/// `test/app_shell_join_deep_link_test.dart`).
///
/// ## Niçin sessiz kalırdı
///
/// `push_tap_router_test.dart` yalnız yönlendiricinin KENDİSİNİ (eşleme,
/// `pending` kanalı) ölçer; kabuğun bunu `_selectTab`e ve `FriendsScreen`e
/// çevirdiğini hiçbir test doğrulamazsa iki taraf birbirinden habersiz
/// bayatlayabilir — biri değişip diğeri değişmeden kalabilir.
///
/// Bu dosya `test/app_shell_join_deep_link_test.dart` kurulumunu izler:
/// hedef kabuk henüz KURULMADAN `PushTapRouter.offer` ile `pending`e
/// konur (soğuk açılışta `getInitialMessage`in yapacağının aynısı), kabuk
/// kurulup "hazır" noktasına ulaşınca hedefin tüketildiği ve doğru
/// sekmenin/ekranın açıldığı denetlenir. Gerçek bir FCM dokunuşunun
/// `onMessageOpenedApp` akışından geçmesi yalnız cihazda doğrulanabilir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

import 'support/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PushTapRouter.resetForTest);
  tearDown(PushTapRouter.resetForTest);

  /// Kabuğun seçili sekmesi (`_tab`) — bkz. `test/app_shell_initial_tab_test.dart`
  /// teki aynı yardımcı.
  ///
  /// `skipOffstage: false` şart: `friend_request` durumunda [FriendsScreen]
  /// kabuğun ÜSTÜNE itilir ve geçiş tamamlanınca alttaki kabuk rotası
  /// `Offstage` olur (durumu — dolayısıyla `_tab` — korunur, yalnız
  /// çizilmez). Varsayılan `skipOffstage: true` bu durumda `IndexedStack`i
  /// hiç BULAMAZDI; bu, sekmenin seçilmediği anlamına gelmez.
  int? visibleTabIndex(WidgetTester tester) => tester
      .widget<IndexedStack>(find.byType(IndexedStack, skipOffstage: false))
      .index;

  testWidgets('bekleyen async_duel_result hedefi kabuk hazır olunca Yarış '
      'sekmesini açar', (tester) async {
    final repository = freshMockRepository();
    // Kabuk henüz yok — tıpkı soğuk açılışta `getInitialMessage`in
    // dokunuşu `AppShell` kurulmadan ÖNCE `pending`e koyacağı gibi.
    expect(PushTapRouter.offer({'kind': 'async_duel_result'}), isTrue);

    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(visibleTabIndex(tester), 1);
    expect(find.byType(PlayHubScreen), findsOneWidget);
    expect(find.byType(FriendsScreen), findsNothing);
    // Hedef tüketildi; ikinci bir tazelemede tekrar uygulanmaz.
    expect(PushTapRouter.pending.value, isNull);
  });

  testWidgets('bekleyen friend_request hedefi Liderlik sekmesini seçer ve '
      'FriendsScreeni üstüne açar', (tester) async {
    final repository = freshMockRepository();
    expect(PushTapRouter.offer({'kind': 'friend_request'}), isTrue);

    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(visibleTabIndex(tester), 2);
    expect(find.byType(FriendsScreen), findsOneWidget);
    expect(PushTapRouter.pending.value, isNull);
  });

  testWidgets('bekleyen hedef yoksa kabuk her zamanki gibi Öğren de açılır', (
    tester,
  ) async {
    final repository = freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(visibleTabIndex(tester), 0);
    expect(find.byType(PlayHubScreen, skipOffstage: false), findsNothing);
    expect(find.byType(FriendsScreen), findsNothing);
  });

  testWidgets(
    'kabuğun üstünde bir sayfa açıkken hedef bekler, dönünce uygulanır',
    (tester) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: AppShell(
            repository: repository,
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Oyuncu bir maçın içinde (kabuğun üstüne itilmiş bir sayfa).
      final navigator = Navigator.of(tester.element(find.byType(AppShell)));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('maç sürüyor')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(PushTapRouter.offer({'kind': 'friend_request'}), isTrue);
      await tester.pumpAndSettle();

      expect(find.text('maç sürüyor'), findsOneWidget);
      expect(find.byType(FriendsScreen), findsNothing);
      expect(PushTapRouter.pending.value, PushTapTarget.friends);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(find.byType(FriendsScreen), findsOneWidget);
      expect(PushTapRouter.pending.value, isNull);
    },
  );

  test('kind dize değilse hedef yok sayılır, hata atılmaz', () {
    expect(PushTapRouter.offer({'kind': 42}), isFalse);
    expect(PushTapRouter.pending.value, isNull);
  });
}
