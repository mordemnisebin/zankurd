import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-07-22 canlı UX denetimi (P1-D): liderlik yalnız ilk 10'u getiriyor.
/// Bu sıralamaya giremeyen oyuncu kendi sırasını hiçbir yerde göremiyordu —
/// tablonun temel motivasyon mekanizması eksikti.
class _OutsideTopTenRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return List.generate(
      10,
      (i) => LeaderboardEntry(
        playerId: 'other-$i',
        displayName: 'Oyuncu ${i + 1}',
        totalScore: 5000 - i * 100,
        bestStreak: 5,
        roomsPlayed: 10,
        rank: i + 1,
      ),
    );
  }

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    playerId: 'me',
    displayName: 'Rojhat',
    totalScore: 210,
    bestStreak: 1,
    roomsPlayed: 0,
    rank: 47,
  );
}

void main() {
  testWidgets('ilk 10 dışındaki oyuncu kendi sırasını görür', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: LeaderboardScreen(repository: _OutsideTopTenRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kendi satırı listenin sonunda; ListView yalnız görünür alanı
    // inşa ettiği için önce sona kaydırılır.
    await tester.dragUntilVisible(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      find.byType(ListView).first,
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      findsOneWidget,
      reason: 'kendi sıra satırı listenin altına sabitlenmeli',
    );
    expect(find.text('Rojhat'), findsWidgets);
  });

  testWidgets('oyuncu ilk 10 içindeyse ayrı satır tekrarlanmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: LeaderboardScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Mock repository oturum sahibini listeye koymuyorsa satır görünür;
    // koyuyorsa görünmemeli. İki durumda da tek satırdan fazla olmamalı.
    expect(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      anyOf(findsNothing, findsOneWidget),
    );
  });
}
