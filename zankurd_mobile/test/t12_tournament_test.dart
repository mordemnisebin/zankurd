import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

const _finalMatch = TournamentMatch(
  id: 'final',
  playerOneId: 'rival',
  playerOneName: 'QaAli',
  playerTwoId: 'user',
  playerTwoName: 'QaBero',
  playerOneScore: 510,
  playerTwoScore: 245,
  playerOneSubmitted: true,
  playerTwoSubmitted: true,
  status: 'completed',
  winnerId: 'rival',
);

class _Repo extends MockZanKurdRepository {
  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => null;

  @override
  Future<TournamentBracket?> loadTournamentBracket() async => TournamentBracket(
    tournamentId: 'cup',
    userId: 'user',
    rounds: const [
      TournamentRound(
        roundNumber: 1,
        matches: [_finalMatch],
        status: 'completed',
      ),
    ],
    currentRound: 0,
    status: 'eliminated',
    totalScore: 510,
    createdAt: DateTime.utc(2026),
  );

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [
    TournamentStandings(
      rank: 1,
      playerId: 'rival',
      playerName: 'QaAli',
      status: 'champion',
      totalScore: 644,
      hasSubmitted: true,
    ),
    TournamentStandings(
      rank: 2,
      playerId: 'user',
      playerName: 'QaBero',
      status: 'finalist',
      totalScore: 510,
      hasSubmitted: true,
    ),
  ];
}

Future<void> _pump(
  WidgetTester tester, {
  bool ku = false,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: TournamentScreen(repository: _Repo())),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('T12 toplam puan kullanıcının adını taşıyan sahiplik metnidir', (
    tester,
  ) async {
    for (final ku in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, ku: ku);
      final total = find.byKey(const ValueKey('tournament-your-total'));
      expect(total, findsOneWidget);
      final text = tester.widget<Text>(total);
      expect(
        text.data,
        ku
            ? 'Kûpa · Pûanên te yên giştî: 510'
            : 'Turnuva · Senin toplam puanın: 510',
      );
      expect(text.style!.fontSize, greaterThanOrEqualTo(14));
      // T14 F09: aynı 510 iki kişide; final ve turnuva kapsamı ayrı yazılır.
      final match = tester.widget<Text>(
        find.byKey(const ValueKey('tournament-eliminated-vs')),
      );
      expect(match.data, startsWith(ku ? 'Fînal · ' : 'Final · '));
      expect(match.data, contains('245'));
      expect(match.data, contains('510'));
      expect(match.style!.fontSize, greaterThanOrEqualTo(14));
    }
  });

  testWidgets(
    'T12 elenen isim okunaklı ve çizgisiz kalır, sonuç ikonu korunur',
    (tester) async {
      await _pump(tester);
      final name = tester.widgetList<Text>(find.text('QaBero')).first;
      expect(name.style?.decoration, isNot(TextDecoration.lineThrough));
      final tokens = SahneTokens.of(tester.element(find.text('QaBero').first));
      expect(name.style?.color, tokens.tx);
      expect(find.byIcon(AppIcons.circleXmark), findsWidgets);
      expect(find.byIcon(AppIcons.trophy), findsWidgets);
    },
  );

  testWidgets('T12 sıralama değerleri iki dilde puan birimi taşır', (
    tester,
  ) async {
    for (final ku in [false, true]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pump(tester, ku: ku);
      final points = find.text(ku ? '644 pûan' : '644 puan');
      expect(points, findsOneWidget);
      expect(find.text('Oynadı · 644'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('T12 turnuva bilgileri büyütülmüş metinde taşmaz', (
    tester,
  ) async {
    for (final ku in [false, true]) {
      for (final scale in [1.3, 2.0]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await _pump(tester, ku: ku, scale: scale);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
