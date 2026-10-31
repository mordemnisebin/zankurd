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
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/room_invite.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
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

  testWidgets('bekleyen async_duel_invite hedefi Yarış sekmesini seçer ve '
      'Düellolarım listesini üstüne açar', (tester) async {
    final repository = freshMockRepository()..addIncomingChallengeForTesting();
    expect(PushTapRouter.offer({'kind': 'async_duel_invite'}), isTrue);

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
    expect(find.byType(AsyncDuelListScreen), findsOneWidget);
    // Gelen meydan okuma listenin başında "Sıra sende".
    expect(find.text('Sıra sende'), findsOneWidget);
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
      expect(PushTapRouter.pending.value?.target, PushTapTarget.friends);

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

  // Kimliksiz eski bir bildirim, sonradan gelen farklı daveti kabul edemez.
  // Davet listesi yenilenir; katılım kararı karttan açıkça verilir.
  Future<void> tapRoomInvite(
    WidgetTester tester,
    MockZanKurdRepository repository,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(PushTapRouter.offer({'kind': 'room_invite'}), isTrue);
    await tester.pumpAndSettle();
  }

  testWidgets('soğuk açılışta en yeni yerine dokunulan daveti gösterir', (
    tester,
  ) async {
    final repository = freshMockRepository()
      ..seedRoomInviteForTesting(_invite(id: 'other', name: 'Şîlan'))
      ..seedRoomInviteForTesting(_invite());
    PushTapRouter.offer({'kind': 'room_invite', 'invite_id': 'inv1'});
    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Rojda'), findsOneWidget);
    expect(find.textContaining('Şîlan'), findsNothing);
    expect(await repository.loadMyRoomInvites(), hasLength(2));
    await tester.tap(find.byKey(const ValueKey('room-invite-decline')));
    await tester.pumpAndSettle();
    expect((await repository.loadMyRoomInvites()).single.id, 'other');
    expect(
      find.text('Bu davetin süresi doldu ya da oda kapandı.'),
      findsNothing,
    );
  });

  testWidgets(
    'kimlikli bildirim çevrimdışı bekler ve bağlantı dönünce açılır',
    (tester) async {
      final repository = freshMockRepository()
        ..seedRoomInviteForTesting(_invite(id: 'other', name: 'Şîlan'))
        ..seedRoomInviteForTesting(_invite());
      final availability = RemoteAvailability(reachable: false);
      addTearDown(availability.dispose);
      PushTapRouter.offer({'kind': 'room_invite', 'invite_id': 'inv1'});
      await tester.pumpWidget(
        testShell(
          remoteAvailability: availability,
          child: AppShell(
            repository: repository,
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(PushTapRouter.pending.value?.inviteId, 'inv1');
      availability.update(true);
      await tester.pumpAndSettle();
      expect(find.textContaining('Rojda'), findsOneWidget);
      expect(find.textContaining('Şîlan'), findsNothing);
      expect(PushTapRouter.pending.value, isNull);
    },
  );

  testWidgets('üst rota kapanınca eski davetin yerine başka davet açılmaz', (
    tester,
  ) async {
    final repository = freshMockRepository()
      ..seedRoomInviteForTesting(_invite());
    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nav = Navigator.of(tester.element(find.byType(AppShell)));
    unawaited(
      nav.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('maç sürüyor')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    PushTapRouter.offer({'kind': 'room_invite', 'invite_id': 'gone'});
    await tester.pumpAndSettle();
    expect(find.text('maç sürüyor'), findsOneWidget);
    nav.pop();
    await tester.pumpAndSettle();
    expect(
      find.text('Bu davetin süresi doldu ya da oda kapandı.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('room-invite-join')), findsNothing);
    expect(find.textContaining('Rojda'), findsNothing);
  });

  testWidgets('room_invite dokunuşu: yükleme hatası genel davet hatasını '
      'gösterir', (tester) async {
    final repository = freshMockRepository()
      ..loadMyRoomInvitesErrorForTesting = StateError('ağ yok');
    await tapRoomInvite(tester, repository);
    expect(find.text('Davet gönderilemedi. Tekrar dene.'), findsOneWidget);
  });

  testWidgets('eski room_invite dokunuşu tek kalan yeni daveti kabul etmez', (
    tester,
  ) async {
    final repository = freshMockRepository()
      ..seedRoomInviteForTesting(_invite());
    await tapRoomInvite(tester, repository);
    expect(visibleTabIndex(tester), 0);
    expect((await repository.loadMyRoomInvites()).single.id, 'inv1');
    expect(PushTapRouter.pending.value, isNull);
  });

  testWidgets('room_invite dokunuşu kabul isteği veya kabul hatası üretmez', (
    tester,
  ) async {
    final repository = freshMockRepository()
      ..seedRoomInviteForTesting(_invite())
      ..respondRoomInviteFailureForTesting = RoomInviteFailure.expired;
    await tapRoomInvite(tester, repository);
    expect((await repository.loadMyRoomInvites()).single.id, 'inv1');
    expect(
      find.text('Bu davetin süresi doldu ya da oda kapandı.'),
      findsNothing,
    );
  });
}

RoomInvite _invite({String id = 'inv1', String name = 'Rojda'}) => RoomInvite(
  id: id,
  roomId: 'room-1',
  roomCode: 'ZK-TEST',
  inviterId: 'u2',
  inviterName: name,
  categoryName: 'Ziman',
  playerCount: 2,
  maxPlayers: 8,
  createdAt: DateTime(2026, 10, 18),
);
