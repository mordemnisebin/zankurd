import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/referral_result.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';

import 'support/widget_test_helpers.dart';

class _OnlineGuest extends AuthProvider {
  _OnlineGuest() : super.test();

  @override
  bool get isAuthenticated => true;
  @override
  bool get isGuest => true;
  @override
  bool get canUseRemoteActions => true;
}

class _CodeRepository extends MockZanKurdRepository {
  String? query;
  final sentTo = <String>[];
  int redemptions = 0;
  bool failRequest = false;

  @override
  Future<String?> getPlayerTag() async => 'AB12';
  @override
  Future<List<Friend>> loadFriends() async => const [];
  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];
  @override
  Future<List<SentFriendRequest>?> loadSentFriendRequests() async => null;

  @override
  Future<List<PlayerSearchResult>> searchPlayers(String value) async {
    query = value;
    return const [
      PlayerSearchResult(id: 'rojda', displayName: 'Rojda', playerTag: 'PVB2'),
    ];
  }

  @override
  Future<bool> addFriend(String friendId, String friendName) async {
    sentTo.add(friendId);
    return !failRequest;
  }

  @override
  Future<ReferralResult> redeemReferralCode(String code) async {
    redemptions++;
    return const ReferralResult(status: ReferralStatus.notVerified);
  }
}

class _DelayedSearchRepository extends _CodeRepository {
  final pending = <String, Completer<List<PlayerSearchResult>>>{};

  @override
  Future<List<PlayerSearchResult>> searchPlayers(String value) {
    return (pending[value] = Completer<List<PlayerSearchResult>>()).future;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, _CodeRepository repo) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: FriendsScreen(repository: repo),
        authProvider: _OnlineGuest(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('arkadaş araması ödül kartından önce gelir', (tester) async {
    await pump(tester, _CodeRepository());
    final search = find.byKey(const ValueKey('friends-search-panel'));
    final reward = find.byKey(const ValueKey('friends-invite-panel'));
    expect(
      tester.getTopLeft(search).dy,
      lessThan(tester.getTopLeft(reward).dy),
    );
    expect(find.text('Davet ödülü'), findsOneWidget);
  });

  testWidgets('anonim oyuncu kodla arkadaş ister, ödül RPCsine gitmez', (
    tester,
  ) async {
    final repo = _CodeRepository();
    await pump(tester, repo);
    expect(
      find.byKey(const ValueKey('friends-enter-code-button')),
      findsNothing,
    );
    final search = find.byKey(const ValueKey('friends-search-panel'));
    await tester.enterText(
      find.descendant(of: search, matching: find.byType(TextField)),
      'ZK-PVB2',
    );
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();
    expect(repo.query, 'ZK-PVB2');
    final add = find.byKey(const ValueKey('search-add-rojda'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(repo.sentTo, ['rojda']);
    expect(repo.redemptions, 0);
    expect(find.text('İstek gönderildi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arkadaş isteği reddedilirse başarı gösterilmez', (tester) async {
    final repo = _CodeRepository()..failRequest = true;
    await pump(tester, repo);
    final search = find.byKey(const ValueKey('friends-search-panel'));
    await tester.enterText(
      find.descendant(of: search, matching: find.byType(TextField)),
      'ZK-PVB2',
    );
    await tester.tap(find.text('Ara'));
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('search-add-rojda'));
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(repo.sentTo, ['rojda']);
    expect(repo.redemptions, 0);
    expect(find.text('İstek gönderildi'), findsNothing);
    expect(add, findsOneWidget);
  });

  testWidgets('geç gelen eski arama son oyuncu sonucunu değiştirmez', (
    tester,
  ) async {
    final repo = _DelayedSearchRepository();
    await pump(tester, repo);
    final field = find.descendant(
      of: find.byKey(const ValueKey('friends-search-panel')),
      matching: find.byType(TextField),
    );
    await tester.enterText(field, 'Rojda');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(field, 'Berfin');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    repo.pending['Berfin']!.complete(const [
      PlayerSearchResult(id: 'berfin', displayName: 'Berfin'),
    ]);
    await tester.pumpAndSettle();
    repo.pending['Rojda']!.complete(const [
      PlayerSearchResult(id: 'rojda', displayName: 'Rojda'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-add-berfin')), findsOneWidget);
    expect(find.byKey(const ValueKey('search-add-rojda')), findsNothing);
  });
}
