// 2026-10-20 Yarış merkezi kimliği: (1) kilim imzası ekranda TEK ve ≤ 12 pt
// (kahraman kartın alt kenarında; büyürse metni/düğmeyi bastırır, çoğalırsa
// imza olmaktan çıkar). (2) "Bu hafta" kartı YALNIZ gerçek veriyi gösterir:
// haftalık kayıt yokken sayı çizilmez (uydurma "#0 / 0 puan" sessizce yanlış
// söylerdi), yalnız çağrı ve "Yarışa başla" durur.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

Future<void> _open(WidgetTester tester, MockZanKurdRepository repo) async {
  await tester.pumpWidget(testShell(child: PlayHubScreen(repository: repo)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('kilim şeridi ekranda tek ve en çok 12 pt', (tester) async {
    await _open(tester, MockZanKurdRepository());
    expect(find.byType(SahneKilimStrip), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-kilim-strip')), findsOneWidget);
    final size = tester.getSize(find.byType(SahneKilimStrip));
    expect(size.height, lessThanOrEqualTo(12));
    expect(size.height, greaterThan(0));
  });

  testWidgets('Bu hafta kartı veri yokken sayı göstermez', (tester) async {
    await _open(tester, MockZanKurdRepository());
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-this-week')),
      200,
    );
    expect(find.byKey(const ValueKey('play-hub-this-week-empty')), findsOne);
    expect(find.byKey(const ValueKey('play-hub-this-week-start')), findsOne);
    expect(
      find.byKey(const ValueKey('play-hub-this-week-stats')),
      findsNothing,
    );
    expect(find.textContaining('#'), findsNothing);
  });

  testWidgets(
    'Bu hafta kartı gerçek kayıt gelince sırayı gösterir; 0 hücre yok',
    (tester) async {
      final repo = MockZanKurdRepository()
        ..sampleMyWeeklyRank = const LeaderboardEntry(
          rank: 4,
          playerId: 'p',
          displayName: 'P',
          totalScore: 0,
          bestStreak: 0,
          roomsPlayed: 2,
        );
      await _open(tester, repo);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('play-hub-this-week-stats')),
        200,
      );
      expect(find.text('#4'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(
        find.byKey(const ValueKey('play-hub-this-week-empty')),
        findsNothing,
      );
    },
  );
}
