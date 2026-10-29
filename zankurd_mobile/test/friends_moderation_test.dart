import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';

/// Arkadaşlar ekranında bildir/engelle (Apple Guideline 1.2).
///
/// ## Kusur
///
/// Arkadaş "⋯" menüsü yalnız "Odaya çağır" ve "Arkadaşlıktan çıkar",
/// gelen istek satırı yalnız kabul/ret sunuyordu. İstek gönderenin avatarı
/// ve adı kullanıcı içeriğidir; tanımadığın biri bu ekrandan
/// bildirilemiyor/engellenemiyordu. Araç sıralama ve odada vardı
/// ([showPlayerModerationSheet]) ama içerikle karşılaşılan bu yüzeyde yoktu.
///
/// ## Bekçi
///
/// İstek satırından ve arkadaş menüsünden aynı alt sayfa açılır; engel
/// hedef kimlikle `blockPlayer`a gider ve listeler yeniden okunur.
class _Repository extends MockZanKurdRepository {
  final blocked = <String>[];
  int friendLoads = 0;
  int requestLoads = 0;

  @override
  Future<List<Friend>> loadFriends() async {
    friendLoads++;
    return [
      Friend(
        id: 'friend1',
        userId: 'user1',
        friendId: 'friend-user-1',
        friendName: 'Rojda',
        createdAt: DateTime(2026),
        totalScore: 100,
        level: 2,
        gamesPlayed: 3,
      ),
    ];
  }

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async {
    requestLoads++;
    return [
      FriendRequest(
        id: 'req1',
        fromUserId: 'stranger-id',
        fromUserName: 'Diyar',
        toUserId: 'user1',
        createdAt: DateTime(2026),
        status: 'pending',
      ),
    ];
  }

  @override
  Future<bool> blockPlayer(String playerId) async {
    blocked.add(playerId);
    return true;
  }
}

Widget _app(_Repository repository) => MultiProvider(
  providers: [
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider(initialLang: 'tr'),
    ),
  ],
  child: MaterialApp(home: FriendsScreen(repository: repository)),
);

Future<void> _block(WidgetTester tester) async {
  expect(find.byKey(const ValueKey('player-block-action')), findsOneWidget);
  expect(find.byKey(const ValueKey('player-report-action')), findsOneWidget);
  await tester.tap(find.byKey(const ValueKey('player-block-action')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('player-moderation-confirm')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('istek satırından engellenir; listeler yenilenir', (
    tester,
  ) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final friendLoads = repository.friendLoads;
    final requestLoads = repository.requestLoads;

    final more = find.byKey(const ValueKey('friend-request-more-req1'));
    expect(more, findsOneWidget);
    expect(find.bySemanticsLabel('Profili bildir'), findsWidgets);
    await tester.tap(more);
    await tester.pumpAndSettle();
    await _block(tester);

    expect(repository.blocked, ['stranger-id']);
    expect(repository.friendLoads, greaterThan(friendLoads));
    expect(repository.requestLoads, greaterThan(requestLoads));
  });

  testWidgets('arkadaş menüsünden engellenir', (tester) async {
    final repository = _Repository();
    await tester.pumpWidget(_app(repository));
    await tester.pumpAndSettle();
    final friendLoads = repository.friendLoads;

    // Ölçü fontunda (kare harfler) satır eylemleri alt satıra iner
    // (kapışma U11 ölçümü); düğme 800×600 test yüzeyinin altına düşebilir.
    await tester.ensureVisible(find.byKey(const ValueKey('friend-more-Rojda')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friend-more-Rojda')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('friend-moderate-Rojda')));
    await tester.pumpAndSettle();
    await _block(tester);

    expect(repository.blocked, ['friend-user-1']);
    expect(repository.friendLoads, greaterThan(friendLoads));
  });
}
