import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';

import 'support/widget_test_helpers.dart';

class _OnlineStatsRepo extends MockZanKurdRepository {
  _OnlineStatsRepo(this.totals);
  final ({int correct, int wrong})? totals;
  @override
  Future<({int correct, int wrong})?> loadOnlineAnswerStats() async => totals;

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    rank: 9,
    playerId: 'guest',
    displayName: 'Azad',
    totalScore: 3400,
    bestStreak: 4,
    roomsPlayed: 4,
  );
}

void main() {
  setUp(freshMockRepository);

  Future<void> open(
    WidgetTester tester,
    ({int correct, int wrong})? totals,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: _OnlineStatsRepo(totals)),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  test('T11 server answer SRS updates do not count twice locally', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await MistakeStore.load();
    await store.markMistake('remote-q', category: 'Ziman', countAnswer: false);
    expect(store.contains('remote-q'), isTrue);
    await store.markResolved('remote-q', countAnswer: false);
    expect(store.totalCorrect, 0);
    expect(store.totalWrong, 0);
    await store.markMistake('local-q', category: 'Ziman');
    await store.markResolved('local-q');
    expect(store.totalCorrect, 1);
    expect(store.totalWrong, 1);
  });

  testWidgets('T11 guest online room and duels count without local answers', (
    tester,
  ) async {
    await open(tester, (correct: 8, wrong: 7));
    expect(find.text('15'), findsOneWidget);
    expect(find.text('%53'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('T11 unavailable online history is not zero or a partial total', (
    tester,
  ) async {
    await open(tester, null);
    expect(
      find.text('Cevap istatistikleri şu anda alınamıyor.'),
      findsOneWidget,
    );
    expect(find.text('Cevaplanan soru'), findsNothing);
    expect(find.text('Doğruluk'), findsNothing);
  });

  testWidgets('T11 match history without answer records never claims zero', (
    tester,
  ) async {
    await open(tester, (correct: 0, wrong: 0));
    expect(
      find.byKey(const ValueKey('profile-answer-stats-unavailable')),
      findsOneWidget,
    );
    expect(find.text('Cevaplanan soru'), findsNothing);
  });

  testWidgets('T11 local practice plus all online answers sum once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final store = await MistakeStore.load();
    await store.markResolved('solo-correct');
    await store.markMistake('solo-wrong');
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(
            repository: _OnlineStatsRepo((correct: 8, wrong: 7)),
          ),
        ),
      ),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('17'), findsOneWidget);
    expect(find.text('%53'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
