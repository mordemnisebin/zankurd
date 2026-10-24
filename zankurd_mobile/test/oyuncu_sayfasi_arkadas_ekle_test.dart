// 2026-10-23: sıralamada ve odada karşılaşılan oyuncuya "Arkadaş ekle".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/add_friend_outcome.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/widgets/player_moderation_button.dart';

import 'support/widget_test_helpers.dart';

/// Oyuncu alt sayfasında (oda lobisi, eşleşme, sıralama, sonuç) "Arkadaş ekle".
///
/// ## Kusur
///
/// Alt sayfa ([showPlayerModerationSheet]) yalnız Çıkar / Bildir / Engelle
/// sunuyordu; sıralama satırı yalnız "bildir" menüsü açıyordu. Sıralamada ya
/// da aynı odada karşılaşılan biriyle arkadaş olmanın tek yolu oyuncu kodunu
/// bulup Arkadaşlar ekranında aratmaktı.
///
/// ## Niçin sessiz kalabilirdi
///
/// Hiçbir şey çökmüyordu: eksik bir düğme hata üretmez. Üstelik sıralamada
/// satıra dokunmak hiçbir şey yapmıyor, yalnızca ⋯ düğmesi menü açıyordu;
/// kimse "satıra basınca bir şey olmalı" diye bir test yazmamıştı.
///
/// ## Bekçi
///
/// Sayfada satır EN ÜSTTE ve `addFriend` doğru kimlik/adla çağrılır; zaten
/// arkadaş ya da isteği gönderilmiş oyuncuda satır pasif; sıralamada satıra
/// dokunmak sayfayı açar, kendi satırında açmaz.
class _Repo extends MockZanKurdRepository {
  _Repo({this.friendIds = const {}, this.sentIds = const {}});

  final Set<String> friendIds;
  final Set<String> sentIds;
  final List<(String, String)> added = [];

  @override
  Future<AddFriendOutcome> addFriend(String friendId, String friendName) async {
    added.add((friendId, friendName));
    return AddFriendOutcome.sent;
  }

  @override
  Future<List<Friend>> loadFriends() async => [
    for (final id in friendIds)
      Friend(
        id: 'f-$id',
        userId: 'me',
        friendId: id,
        friendName: id,
        createdAt: DateTime(2026, 10, 1),
      ),
  ];

  @override
  Future<List<SentFriendRequest>?> loadSentFriendRequests() async => [
    for (final id in sentIds)
      SentFriendRequest(
        id: 's-$id',
        toUserId: id,
        toUserName: id,
        createdAt: DateTime(2026, 10, 1),
      ),
  ];

  @override
  String? get currentUserId => 'user';

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => List.generate(
    12,
    (i) => LeaderboardEntry(
      playerId: i == 5 ? 'user' : 'other-$i',
      displayName: i == 5 ? 'Ben' : 'Oyuncu ${i + 1}',
      totalScore: 5000 - i * 100,
      bestStreak: 5,
      roomsPlayed: 10,
      rank: i + 1,
    ),
  );
}

Future<void> _openSheet(WidgetTester tester, _Repo repo) async {
  await tester.pumpWidget(
    testShell(
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPlayerModerationSheet(
              context: context,
              repository: repo,
              playerId: 'other-1',
              playerName: 'Berfin',
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('aç'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sayfada Arkadaş ekle var, üstte; basınca addFriend çağrılır', (
    tester,
  ) async {
    final repo = _Repo();
    await _openSheet(tester, repo);
    final add = find.byKey(const ValueKey('player-add-friend-action'));
    expect(add, findsOneWidget);
    expect(find.text('Arkadaş ekle'), findsOneWidget);
    final report = find.byKey(const ValueKey('player-report-action'));
    expect(
      tester.getTopLeft(add).dy,
      lessThan(tester.getTopLeft(report).dy),
      reason: 'Arkadaş ekle sayfanın en üstünde olmalı',
    );
    await tester.tap(add);
    await tester.pumpAndSettle();
    expect(repo.added, [('other-1', 'Berfin')]);
    expect(find.text('İstek gönderildi'), findsOneWidget);
  });

  testWidgets('zaten arkadaş olan oyuncuda satır pasif', (tester) async {
    final repo = _Repo(friendIds: {'other-1'});
    await _openSheet(tester, repo);
    expect(find.text('Arkadaşın'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-add-friend-action')));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);
  });

  testWidgets('isteği gönderilmiş oyuncuda satır pasif', (tester) async {
    final repo = _Repo(sentIds: {'other-1'});
    await _openSheet(tester, repo);
    expect(find.text('İstek gönderildi'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-add-friend-action')));
    await tester.pumpAndSettle();
    expect(repo.added, isEmpty);
  });

  group('sıralama', () {
    Future<void> pump(WidgetTester tester, _Repo repo) async {
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: ThemeMode.light),
          child: Scaffold(body: LeaderboardScreen(repository: repo)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
    }

    testWidgets('başkasının satırına dokununca sayfa açılır', (tester) async {
      final repo = _Repo();
      await pump(tester, repo);
      final row = find.byKey(const ValueKey('leaderboard-rank-row-8'));
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-add-friend-action')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('player-add-friend-action')));
      await tester.pumpAndSettle();
      expect(repo.added.single.$1, 'other-7');
    });

    testWidgets('kendi satırında sayfa açılmaz', (tester) async {
      await pump(tester, _Repo());
      final row = find.byKey(const ValueKey('leaderboard-rank-row-6'));
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-add-friend-action')),
        findsNothing,
      );
    });
  });
}
