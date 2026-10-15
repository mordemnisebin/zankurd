/// Sosyal yüzey — istemci bekçileri (2026-10-15 denetimi).
///
/// ## Kusur
///
/// Sekiz sessiz kusur, hiçbiri hata vermiyordu:
///
/// 1. **Ana ekran düello kartı bayatlıyordu.** `AppShell.didChangeAppLifecycle
///    State` ön plana dönüşte hiçbir sekmeyi tazelemiyordu; kart yalnız
///    tazeleme işareti değişince okur. Arka planda biten düello, uygulama
///    açılınca eski haliyle görünüyordu.
/// 2. **Davet bağlantısı canlı maçın üstüne açılıyordu** (bildirim dokunuşu
///    bunu zaten bekliyordu, bağlantı beklemiyordu).
/// 3. **Davet bağlantısı hataları yalnız ErrorReporter'a gidiyordu**: dolu
///    ya da bulunamayan odada oyuncu hiçbir şey olmadığını görüyordu.
/// 4. **Soğuk açılışta sosyal kilit varken bağlantı kayboluyordu**: kod
///    tüketilmeden dönülüyor ve tek seferlik planlama bayrağı bir daha
///    denemeyi engelliyordu.
/// 5. **Arkadaş ekranı durumu bilmiyordu**: zaten arkadaş olunan / bize istek
///    göndermiş / istek gönderilmiş kişi için "Ekle" görünüyor, dokunuş
///    sunucuda sessizce reddedilip genel hata çıkıyordu; "gönderildi" yalnız
///    ekranın belleğindeydi; arkadaşı silme ve isteği geri çekme yoktu.
/// 6. **Çıkışta FCM token'ı silinmiyordu**: cihazı devralan hesap öncekinin
///    bildirimlerini alırdı.
/// 7. **Yarım kalan düello ölü bir satırdı**: "Yarım kaldı" satırına
///    dokunmak sonuç ekranı açıyor, devam edilemiyordu.
/// 8. **Kimsenin katılmadığı düello geri çekilemiyordu.**
///
/// ## Niçin sessiz kalırdı
///
/// Her şey "çalışır" görünüyordu: kart yüklenir, bağlantı işlenir, "Ekle"
/// basılır. Yanlış olan zamanlama (ne zaman), üst rota (nerede) ve durum
/// (kimin kimle ne ilişkisi) idi; hiçbir test bunları kurmuyordu.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/referral_result.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/utils/join_deep_link.dart';

import 'support/widget_test_helpers.dart';

class _ShellRepository extends MockZanKurdRepository {
  final List<String> joinCalls = [];
  Object? joinError;
  int duelLoads = 0;

  @override
  Future<GameRoom> joinOnlineRoom(String code) async {
    joinCalls.add(code);
    final error = joinError;
    if (error != null) throw error;
    return createRoom().copyWith(code: code);
  }

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() {
    duelLoads++;
    return super.loadMyAsyncDuels();
  }
}

Future<void> _pumpShell(
  WidgetTester tester,
  _ShellRepository repository, {
  RemoteAvailability? availability,
}) async {
  await tester.pumpWidget(
    JoinDeepLinkScope(
      child: testShell(
        authProvider: FakeAuthProvider(),
        remoteAvailability: availability,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(JoinDeepLink.resetForTest);
  tearDown(JoinDeepLink.resetForTest);

  group('AppShell', () {
    setUp(freshMockRepository);

    testWidgets('ön plana dönüş görünen sekmeyi (ana ekran) tazeler', (
      tester,
    ) async {
      final repository = _ShellRepository();
      await _pumpShell(tester, repository);
      final before = repository.duelLoads;
      expect(before, greaterThan(0), reason: 'ana ekran kartı yüklenmeliydi');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(repository.duelLoads, before, reason: 'arka plan tazelemez');

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        repository.duelLoads,
        greaterThan(before),
        reason: 'uygulama açılınca düello kartı yeniden okunmalı',
      );
    });

    testWidgets('canlı bir sayfa üstteyken davet bekler, dönünce açılır', (
      tester,
    ) async {
      final repository = _ShellRepository();
      await _pumpShell(tester, repository);

      // Maç/lobi yerine geçen herhangi bir üst rota.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('canlı maç')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('canlı maç'), findsOneWidget);

      await tester.binding.handlePushRoute('/join/ZK-ABCDEF0123');
      await tester.pumpAndSettle();
      expect(
        repository.joinCalls,
        isEmpty,
        reason: 'davet, üstte canlı bir rota varken odaya katılmamalı',
      );
      expect(find.text('canlı maç'), findsOneWidget);

      navigator.pop();
      await tester.pumpAndSettle();

      expect(repository.joinCalls, ['ZK-ABCDEF0123']);
      expect(find.byType(RoomScreen), findsOneWidget);
    });

    testWidgets('katılma hatası oda menüsüyle aynı metinle gösterilir', (
      tester,
    ) async {
      final repository = _ShellRepository()
        ..joinError = const RoomJoinException(RoomJoinFailureReason.full);
      await _pumpShell(tester, repository);

      await tester.binding.handlePushRoute('/join/ZK-ABCDEF0123');
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Oda dolu.'), findsOneWidget);
    });

    testWidgets('soğuk açılışta sosyal kilit varken kod kaybolmaz, kilit '
        'kalkınca açılır', (tester) async {
      final repository = _ShellRepository();
      final availability = RemoteAvailability(reachable: false);
      addTearDown(availability.dispose);
      JoinDeepLink.pendingCode = 'ZK-ABCDEF0123';

      await _pumpShell(tester, repository, availability: availability);
      expect(repository.joinCalls, isEmpty);
      expect(find.byType(RoomScreen), findsNothing);

      availability.update(true);
      await tester.pumpAndSettle();

      expect(repository.joinCalls, ['ZK-ABCDEF0123']);
      expect(find.byType(RoomScreen), findsOneWidget);
    });
  });

  group('FriendsScreen', () {
    Widget wrap(Widget child) => MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(initialLang: 'tr'),
        ),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

    PlayerSearchResult player(String id, String name) =>
        PlayerSearchResult(id: id, displayName: name);

    Friend friend(String id, String name) => Friend(
      id: 'row-$id',
      userId: 'me',
      friendId: id,
      friendName: name,
      createdAt: DateTime(2026, 10, 1),
    );

    Future<void> pumpFriends(
      WidgetTester tester,
      _SocialRepository repository,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrap(FriendsScreen(repository: repository, asyncDuelEnabled: false)),
      );
      await tester.pumpAndSettle();
    }

    Future<void> search(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).first, 'Ro');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
    }

    testWidgets('arama sonucu durumu yansıtır: arkadaş / gelen / gönderilen / '
        'yeni', (tester) async {
      final repository = _SocialRepository(
        results: [
          player('u-friend', 'Arkadaş Kişi'),
          player('u-incoming', 'Gelen Kişi'),
          player('u-sent', 'Gönderilen Kişi'),
          player('u-new', 'Yeni Kişi'),
        ],
        friends: [friend('u-friend', 'Arkadaş Kişi')],
        pending: [
          FriendRequest(
            id: 'req-1',
            fromUserId: 'u-incoming',
            fromUserName: 'Gelen Kişi',
            toUserId: 'me',
            createdAt: DateTime(2026, 10, 14),
          ),
        ],
        sent: [
          SentFriendRequest(
            id: 'req-2',
            toUserId: 'u-sent',
            toUserName: 'Gönderilen Kişi',
            createdAt: DateTime(2026, 10, 14),
          ),
        ],
      );
      await pumpFriends(tester, repository);
      await search(tester);

      expect(find.byKey(const ValueKey('search-friend-u-friend')), findsOne);
      expect(find.byKey(const ValueKey('search-add-u-friend')), findsNothing);
      expect(find.byKey(const ValueKey('search-accept-u-incoming')), findsOne);
      expect(find.byKey(const ValueKey('search-add-u-incoming')), findsNothing);
      expect(find.byKey(const ValueKey('search-add-u-sent')), findsNothing);
      expect(find.byKey(const ValueKey('search-add-u-new')), findsOne);
    });

    testWidgets('gönderilen istekler sunucudan gelir ve geri çekilir', (
      tester,
    ) async {
      final repository = _SocialRepository(
        sent: [
          SentFriendRequest(
            id: 'req-2',
            toUserId: 'u-sent',
            toUserName: 'Gönderilen Kişi',
            createdAt: DateTime(2026, 10, 14),
          ),
        ],
      );
      await pumpFriends(tester, repository);

      expect(find.byKey(const ValueKey('friends-sent-requests')), findsOne);
      expect(find.text('Gönderilen Kişi'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('sent-cancel-u-sent')));
      await tester.pumpAndSettle();

      expect(repository.cancelledRequestTargets, ['u-sent']);
      expect(find.byKey(const ValueKey('friends-sent-requests')), findsNothing);
    });

    testWidgets('arkadaşı silme onay ister; vazgeçince silinmez', (
      tester,
    ) async {
      final repository = _SocialRepository(
        friends: [friend('u-rojda', 'Rojda')],
        sent: const [],
      );
      await pumpFriends(tester, repository);

      await tester.tap(find.byKey(const ValueKey('friend-remove-Rojda')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('friend-remove-confirm')), findsOne);

      await tester.tap(find.byKey(const ValueKey('friend-remove-cancel')));
      await tester.pumpAndSettle();
      expect(repository.removedFriendIds, isEmpty);

      await tester.tap(find.byKey(const ValueKey('friend-remove-Rojda')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('friend-remove-confirm')));
      await tester.pumpAndSettle();
      expect(repository.removedFriendIds, ['u-rojda']);
    });

    testWidgets('sunucuda RPC yoksa silme ve geri çekme sessizce gizlenir', (
      tester,
    ) async {
      final repository = _SocialRepository(
        friends: [friend('u-rojda', 'Rojda')],
        sent: null,
      );
      await pumpFriends(tester, repository);

      expect(find.text('Rojda'), findsOneWidget);
      expect(find.byKey(const ValueKey('friend-remove-Rojda')), findsNothing);
      expect(find.byKey(const ValueKey('friends-sent-requests')), findsNothing);
    });
  });

  group('Sırayla düello gelen kutusu', () {
    testWidgets('yarım kalan düello ölü satır değil, devam edilebilir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      final start = await repository.startAsyncDuel();
      // Yalnız ilk soru cevaplandı: tur yarım.
      await repository.answerAsyncDuel(
        duelId: start.duelId,
        questionIndex: 0,
        choice: 'A',
        responseMs: 1000,
      );

      await tester.pumpWidget(
        testShell(
          child: Scaffold(body: AsyncDuelInboxSection(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();

      final summary = (await repository.loadMyAsyncDuels()).single;
      expect(summary.canResume, isTrue);
      expect(find.text('Devam et'), findsOneWidget);

      await tester.tap(find.byKey(ValueKey('async-duel-row-${start.duelId}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(repository.resumedAsyncDuelIds, [start.duelId]);
      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
    });

    testWidgets('kimsenin katılmadığı düello geri çekilir', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      final start = await repository.startAsyncDuel();
      for (var i = 0; i < start.questions.length; i++) {
        await repository.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }

      await tester.pumpWidget(
        testShell(
          child: Scaffold(body: AsyncDuelInboxSection(repository: repository)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('async-duel-row-${start.duelId}')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('async-duel-result-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('async-duel-cancel-confirm')));
      await tester.pumpAndSettle();

      expect(repository.cancelledAsyncDuelIds, [start.duelId]);
      expect(await repository.loadMyAsyncDuels(), isEmpty);
    });

    test('canResume / canCancel yalnız ilgili durumlarda', () {
      AsyncDuelSummary s({
        AsyncDuelStatus status = AsyncDuelStatus.open,
        AsyncDuelRole role = AsyncDuelRole.creator,
        int? myCorrect,
        String? opponent,
        bool incoming = false,
      }) => AsyncDuelSummary(
        duelId: 'd',
        status: status,
        role: role,
        opponentName: opponent,
        myCorrect: myCorrect,
        createdAt: DateTime.utc(2026, 10, 15),
        seen: true,
        incomingChallenge: incoming,
      );

      expect(s().canResume, isTrue);
      expect(s(status: AsyncDuelStatus.matched).canResume, isTrue);
      expect(s(myCorrect: 3).canResume, isFalse, reason: 'turum bitti');
      expect(s(status: AsyncDuelStatus.expired).canResume, isFalse);
      expect(s(incoming: true).canResume, isFalse, reason: 'önce kabul');

      expect(s(myCorrect: 3).canCancel, isTrue);
      expect(s().canCancel, isFalse, reason: 'turu bitmemiş: devam edilir');
      expect(s(myCorrect: 3, opponent: 'Rojda').canCancel, isFalse);
      expect(
        s(myCorrect: 3, status: AsyncDuelStatus.matched).canCancel,
        isFalse,
      );
      expect(s(myCorrect: 3, role: AsyncDuelRole.opponent).canCancel, isFalse);
    });
  });

  group('davet ödülü hata kodları', () {
    test('yeni sunucu kodları dürüst durumlara eşlenir', () {
      ReferralStatus status(String error) =>
          ReferralResult.fromMap({'success': false, 'error': error}).status;
      expect(status('limit_reached'), ReferralStatus.notFound);
      expect(status('not_active'), ReferralStatus.notActive);
      expect(status('already_redeemed'), ReferralStatus.alreadyRedeemed);
    });
  });

  group('çıkışta FCM token', () {
    test('clear_my_fcm_token oturum kapanmadan ÖNCE çağrılır', () {
      final source = File(
        'lib/src/providers/auth_provider.dart',
      ).readAsStringSync();
      final clear = source.indexOf("'clear_my_fcm_token'");
      final signOut = source.indexOf('await client.auth.signOut()');
      expect(clear, isNonNegative);
      expect(signOut, isNonNegative);
      expect(
        clear,
        lessThan(signOut),
        reason: 'RPC auth.uid() ister: oturum kapandıktan sonra çalışmaz',
      );
      expect(source, contains('isMissingRpcError'));
    });

    test('depo sözleşmesi: clearFcmToken token\'ı bırakır', () async {
      final repository = freshMockRepository();
      await repository.setFcmToken('abc');
      expect(repository.lastFcmToken, 'abc');
      await repository.clearFcmToken();
      expect(repository.fcmTokenCleared, isTrue);
      expect(repository.lastFcmToken, isNull);
    });
  });
}

/// Arkadaş ekranı için sahte depo: arama sonucu, arkadaşlar, gelen ve
/// gönderilen istekler verilir. `sent: null` → sunucuda yönetim RPC'leri yok.
class _SocialRepository extends MockZanKurdRepository {
  _SocialRepository({
    this.results = const [],
    this.friends = const [],
    this.pending = const [],
    List<SentFriendRequest>? sent = const [],
  }) {
    sentFriendRequestsForTesting = sent == null ? null : List.of(sent);
  }

  final List<PlayerSearchResult> results;
  final List<Friend> friends;
  final List<FriendRequest> pending;

  @override
  Future<List<PlayerSearchResult>> searchPlayers(String query) async => results;

  @override
  Future<List<Friend>> loadFriends() async => friends;

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => pending;
}
