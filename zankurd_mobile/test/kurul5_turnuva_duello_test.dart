import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/widget_test_helpers.dart';
import 'support/t8_visual_fixtures.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('E3: bitmiş hükmen maçta henüz oynamadı yazmaz', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: TournamentBracketWidget(
            bracket: t8TournamentBracket(t8TournamentMatch(submitted: false)),
            userId: 'user',
            ku: false,
          ),
        ),
      ),
    );
    expect(find.text('Oynamadı · hükmen'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Oynamadı · hükmen')).style!.fontSize,
      greaterThanOrEqualTo(14),
    );
    expect(find.text('Henüz oynamadı'), findsNothing);
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: TournamentBracketWidget(
            bracket: t8TournamentBracket(
              t8TournamentMatch(completed: false, submitted: false),
              finished: false,
            ),
            userId: 'user',
            ku: false,
          ),
        ),
      ),
    );
    expect(find.text('Henüz oynamadı'), findsOneWidget);
    expect(find.text('Oynamadı · hükmen'), findsNothing);
  });

  for (final link in [false, true]) {
    testWidgets('E5: rakipsiz açık davetin doğru sayısı ve kapanışı ($link)', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: AsyncDuelInboxSection(repository: T8DuelRepo(link)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Açık davet'), findsOneWidget);
      expect(find.text('7 soruda 1 doğru'), findsOneWidget);
      expect(find.text('13 sa içinde katılan olmazsa kapanır'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text('13 sa içinde katılan olmazsa kapanır'))
            .style!
            .fontSize,
        greaterThanOrEqualTo(14),
      );
      expect(find.text('Sen 1/7'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('E7: biten kupadan yeni turnuvaya katılım açıkça yazılır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: TournamentScreen(
          repository: T8CupRepo(t8TournamentBracket(t8TournamentMatch())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yeni turnuvaya katıl'), findsOneWidget);
    expect(find.text('Turnuvaya katıl'), findsNothing);
  });

  testWidgets('E8: final kaybedeni ikinci ve skorun sahibi açık', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: TournamentScreen(
          repository: T8CupRepo(t8TournamentBracket(t8TournamentMatch())),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('İkinci oldun'), findsOneWidget);
    expect(find.text('Sen 245 – 510 QaAlı'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Sen 245 – 510 QaAlı')).style!.fontSize,
      greaterThanOrEqualTo(14),
    );
    expect(find.text('Elendi'), findsNothing);
    expect(find.textContaining('turunda elendin'), findsNothing);
  });
}
