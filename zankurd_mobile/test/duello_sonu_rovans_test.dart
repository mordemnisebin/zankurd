/// Rastgele canlı düello sonucunda tek dokunuşluk "Rövanş" / "Yeniden eşleş".
///
/// ## Kusur (ikinci tur kurulu 2026-11-04)
///
/// Canlı düello bitince tek yol "Rakip bul" idi (konu seçimi baştan);
/// aynı rakibe rövanş ya da aynı konuda yeni arama tek dokunuşla yoktu.
/// Sırayla düelloda rövanş vardı, canlıda yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// Özel odanın "Tekrar oyna"sı ve sırayla düellonun "Rövanş"ı çalışıyordu;
/// rastgele eşleşmenin sonucu yalnız "Rakip bul" göstermek için bilerek
/// sadeleşmişti, eksik olan bir hata üretmiyordu.
///
/// ## Kural
///
/// Rakip kabul edilmiş ARKADAŞSA "Rövanş" (sırayla düello meydan okuması,
/// `create_async_duel_challenge(p_friend_id)`), değilse "Yeniden eşleş"
/// (aynı konuda arama, konu seçimi atlanır). Rakip bot ise Rövanş çıkmaz.
/// Özel oda ve kalabalık odada ikisi de çıkmaz (onların kendi akışı var).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';

import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  _Repo({this.friendIds = const []});
  final List<String> friendIds;

  @override
  Future<List<Friend>> loadFriends() async => [
    for (final id in friendIds)
      Friend(
        id: 'f-$id',
        userId: 'user',
        friendId: id,
        friendName: 'Rakip',
        createdAt: DateTime(2026, 1, 1),
      ),
  ];

  @override
  Future<bool> supportsAsyncDuelChallenge() async => true;
}

Future<void> _pumpResult(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  Player opponent = const Player(
    id: 'opp-1',
    name: 'Rakip',
    score: 40,
    state: '',
  ),
  bool custom = false,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final room = repo.createRoom().copyWith(
    id: 'online-room-id',
    status: RoomStatus.finished,
    isCustom: custom,
  );
  await tester.pumpWidget(
    testShell(
      child: QuizResultScreen(
        repository: repo,
        room: room,
        score: 100,
        correctCount: 10,
        wrongCount: 0,
        totalQuestions: 10,
        bestStreak: 10,
        answerRecords: const [],
        coinsAwarded: 50,
        opponents: [opponent],
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('arkadaş rakip: Rövanş sırayla düello meydan okumasını açar', (
    tester,
  ) async {
    await _pumpResult(tester, _Repo(friendIds: ['opp-1']));
    final button = find.byKey(const ValueKey('result-live-rematch-button'));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Rövanş'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-rematch-search-button')),
      findsNothing,
    );
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('arkadaş olmayan rakip: Yeniden eşleş aynı konuda arar', (
    tester,
  ) async {
    await _pumpResult(tester, _Repo());
    final button = find.byKey(const ValueKey('result-rematch-search-button'));
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Yeniden eşleş'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-live-rematch-button')),
      findsNothing,
    );
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final screen = tester.widget<MatchmakingScreen>(
      find.byType(MatchmakingScreen),
    );
    expect(screen.initialCategory, 'Ziman');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('bot rakip: Rövanş çıkmaz, Yeniden eşleş çıkar', (tester) async {
    await _pumpResult(
      tester,
      _Repo(friendIds: ['opp-1']),
      opponent: const Player(
        id: 'opp-1',
        name: 'Bot',
        score: 0,
        state: Player.botState,
      ),
    );
    expect(
      find.byKey(
        const ValueKey('result-live-rematch-button'),
        skipOffstage: false,
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const ValueKey('result-rematch-search-button'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
