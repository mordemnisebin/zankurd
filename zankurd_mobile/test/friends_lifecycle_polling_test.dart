import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/services/foreground_push_center.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';

/// Arkadaş listesini kaç kez okuduğunu sayan depo.
class _CountingFriendsRepository extends MockZanKurdRepository {
  int loadFriendsCalls = 0;
  Completer<List<Friend>>? blockedFriends;
  List<FriendRequest> requests = [];

  @override
  Future<List<Friend>> loadFriends() async {
    loadFriendsCalls++;
    return blockedFriends?.future ?? <Friend>[];
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async =>
      List.of(requests);
}

/// Arkadaşlar ekranının 20 sn'lik yoklaması uygulama arka plandayken
/// durur; dönüşte bir kez tazelenir ve TEK zamanlayıcıyla sürer.
///
/// Eskiden yalnız `resumed` dinleniyordu: zamanlayıcı arka planda da
/// Supabase'e istek atmaya devam ediyordu (pil, veri, kota).
// Gerçek platform sırası: AppLifecycleListener geçersiz geçişte assert eder.
void _toBackground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

void _toForeground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

void main() {
  tearDown(ForegroundPushCenter.resetForTest);

  testWidgets('sorgu sürerken gelen istekler tek ek yenilemede görünür', (
    tester,
  ) async {
    final repository = _CountingFriendsRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: MaterialApp(home: FriendsScreen(repository: repository)),
      ),
    );
    await tester.pump();
    final initial = repository.loadFriendsCalls;
    final blocked = repository.blockedFriends = Completer<List<Friend>>();
    const push = ForegroundPush(data: {'kind': 'friend_request'});
    ForegroundPushCenter.emit(push);
    await tester.pump();
    repository.requests = [
      FriendRequest(
        id: 'new-request',
        fromUserId: 'new-friend',
        fromUserName: 'Dilan',
        toUserId: 'me',
        createdAt: DateTime(2026, 10, 31),
      ),
    ];
    ForegroundPushCenter.emit(push);
    ForegroundPushCenter.emit(push);
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 1);
    repository.blockedFriends = null;
    blocked.complete([]);
    await tester.pump();
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 2);
    expect(find.text('Dilan'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('arkadaş push isteği açık listeyi polling beklemeden yeniler', (
    tester,
  ) async {
    final repository = _CountingFriendsRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: 'tr'),
        child: MaterialApp(home: FriendsScreen(repository: repository)),
      ),
    );
    await tester.pump();
    final initial = repository.loadFriendsCalls;
    ForegroundPushCenter.emit(
      const ForegroundPush(data: {'kind': 'friend_request'}),
    );
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 1);
    ForegroundPushCenter.emit(
      const ForegroundPush(data: {'kind': 'room_invite'}),
    );
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 1);
    _toBackground(tester);
    ForegroundPushCenter.emit(
      const ForegroundPush(data: {'kind': 'friend_accept'}),
    );
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 1);
    _toForeground(tester);
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 2);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    ForegroundPushCenter.emit(
      const ForegroundPush(data: {'kind': 'friend_request'}),
    );
    await tester.pump();
    expect(repository.loadFriendsCalls, initial + 2);
  });

  testWidgets('arka planda yoklama durur, dönüşte bir kez tazelenir', (
    tester,
  ) async {
    final repository = _CountingFriendsRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider(initialLang: 'tr'),
          ),
        ],
        child: MaterialApp(home: FriendsScreen(repository: repository)),
      ),
    );
    await tester.pump();

    // Önde: 60 sn'de bir yeniden okur (PollCadence.socialRefresh; tur 4).
    final afterStart = repository.loadFriendsCalls;
    await tester.pump(const Duration(seconds: 60));
    await tester.pump();
    expect(repository.loadFriendsCalls, afterStart + 1);

    // Arka plan: periyodik süreler geçse de istek yok.
    _toBackground(tester);
    final afterPause = repository.loadFriendsCalls;
    await tester.pump(const Duration(seconds: 180));
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause);

    // Dönüş: bir kez hemen tazelenir.
    _toForeground(tester);
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause + 1);

    // 20 sn sonra ikinci bir dönüş: döngü yeniden kurulur. Eski zamanlayıcı
    // iptal edilmeseydi ilk dönüşten 60. saniyede (yeniden kurulandan 40.)
    // o da tetiklenirdi.
    await tester.pump(const Duration(seconds: 20));
    tester.binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause + 2);

    await tester.pump(const Duration(seconds: 40));
    await tester.pump();
    expect(
      repository.loadFriendsCalls,
      afterPause + 2,
      reason: 'İlk dönüşün zamanlayıcısı iptal edilmeli (tek zamanlayıcı).',
    );

    await tester.pump(const Duration(seconds: 20));
    await tester.pump();
    expect(repository.loadFriendsCalls, afterPause + 3);

    await tester.pumpWidget(const SizedBox());
  });
}
