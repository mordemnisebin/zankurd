import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/learn_path.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/t15_capture.dart';
import 'support/widget_test_helpers.dart';

const _semiOne = TournamentMatch(
  id: 'semi-one',
  playerOneId: 'absent',
  playerOneName: 'Test ZK',
  playerOneScore: 0,
  playerTwoId: 'rival',
  playerTwoName: 'QaAli',
  playerTwoScore: 134,
  playerOneSubmitted: false,
  playerTwoSubmitted: true,
  status: 'completed',
  winnerId: 'rival',
);
const _semiTwo = TournamentMatch(
  id: 'semi-two',
  playerOneId: 'user',
  playerOneName: 'QaBero',
  playerTwoId: 'other',
  playerTwoName: 'QaCano',
  playerOneScore: 265,
  playerTwoScore: 122,
  playerOneSubmitted: true,
  playerTwoSubmitted: true,
  status: 'completed',
  winnerId: 'user',
);
const _final = TournamentMatch(
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
    tournamentId: 't15',
    userId: 'user',
    rounds: const [
      TournamentRound(
        roundNumber: 1,
        matches: [_semiOne, _semiTwo],
        status: 'completed',
      ),
      TournamentRound(roundNumber: 2, matches: [_final], status: 'completed'),
    ],
    currentRound: 1,
    status: 'eliminated',
    totalScore: 510,
    createdAt: DateTime.utc(2026),
  );
  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => [];
}

class _LearningRepo extends _Repo {
  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async =>
      (await super.loadLessonsByCategory(
        category,
      )).where((lesson) => lesson.id != 'everyday_2').take(5).toList();

  @override
  Future<Set<String>> loadCompletedLessonIds() async => {
    'alphabet_1',
    'everyday_1',
    'greetings_2',
  };
}

Future<void> _open(
  WidgetTester tester,
  Widget child, {
  bool ku = false,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      reducedMotion: true,
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: const ValueKey('t15-capture'),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadT15Fonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final ku in [false, true]) {
    testWidgets(
      'S14 günlük karar bilgileri ilk görünümde ve dock sabit ku=$ku',
      (tester) async {
        final repo = _Repo()
          ..sampleDailyEventBoard = const DailyEventBoard(
            participants: 1,
            yesterdayWinner: DailyEventEntry(
              rank: 1,
              name: 'Test ZK',
              correct: 10,
              total: 10,
              seconds: 60,
            ),
          );
        await _open(tester, ContestScreen(repository: repo), ku: ku);
        final viewport = tester.getRect(find.byType(CustomScrollView));
        final chips = find.byType(SahneStatChip);
        expect(chips, findsNWidgets(2));
        for (var i = 0; i < 2; i++) {
          expect(
            tester.getRect(chips.at(i)).bottom,
            lessThan(viewport.bottom - 16),
          );
        }
        final start = find.text(ku ? 'Dest pê bike' : 'Başla');
        expect(start, findsOneWidget);
        final startRect = tester.getRect(start);
        expect(startRect.bottom, lessThan(810));
        await captureT15(tester, 'S14_sonra_${ku ? 'KU' : 'TR'}');
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.getRect(start), startRect);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('S16 final ve toplam ayrı; şemada 265 + 245 = 510 ku=$ku', (
      tester,
    ) async {
      await _open(tester, TournamentScreen(repository: _Repo()), ku: ku);
      final last = tester.widget<Text>(
        find.byKey(const ValueKey('tournament-eliminated-vs')),
      );
      final total = tester.widget<Text>(
        find.byKey(const ValueKey('tournament-your-total')),
      );
      expect(last.data, startsWith(ku ? 'Fînal · ' : 'Final · '));
      expect(last.data, contains('245'));
      expect(last.data, contains('510'));
      expect(total.data, contains('510'));
      expect(last.style!.fontSize, greaterThanOrEqualTo(14));
      final bracket = tester.widget<TournamentBracketWidget>(
        find.byType(TournamentBracketWidget),
      );
      expect(
        bracket.bracket.rounds[0].matches[1].playerOneScore +
            bracket.bracket.rounds[1].matches[0].playerTwoScore,
        510,
      );
      await captureT15(tester, 'S16_sonra_${ku ? 'KU' : 'TR'}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('S17 hükmen kazanan ve elenen kendi oyuncu satırında ku=$ku', (
      tester,
    ) async {
      await _open(tester, TournamentScreen(repository: _Repo()), ku: ku);
      final winner = find.byKey(
        const ValueKey('tournament-player-semi-one-rival'),
      );
      final loser = find.byKey(
        const ValueKey('tournament-player-semi-one-absent'),
      );
      expect(
        find.descendant(
          of: winner,
          matching: find.textContaining(
            ku ? 'Bi hukmî derbas bû' : 'Hükmen geçti',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: loser,
          matching: find.text(
            ku ? 'Nelîst · têkçûna bi biryarê' : 'Oynamadı · hükmen elendi',
          ),
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(loser);
      await tester.pumpAndSettle();
      await captureT15(tester, 'S17_sonra_${ku ? 'KU' : 'TR'}');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'S21 güncel ders kartı düğüme doğrudan bağlı, tamamlanma ikonla ayrılır',
    (tester) async {
      await _open(
        tester,
        LearningScreen(repository: _LearningRepo()),
        ku: true,
      );
      final current = find.byKey(const ValueKey('learning-next-step'));
      await Scrollable.ensureVisible(tester.element(current), alignment: 1);
      await tester.pumpAndSettle();
      final ring = find.byKey(const ValueKey('learn-node-current-ring'));
      final connector = find.byKey(const ValueKey('learn-current-connector'));
      expect(connector, findsOneWidget);
      expect(
        tester.getRect(connector).center.dx,
        closeTo(tester.getRect(ring).center.dx, .1),
      );
      final path = tester.widget<LearnPath>(find.byType(LearnPath));
      expect(path.stops.where((s) => s.state == LearnNodeState.done).length, 3);
      expect(find.text('Ders qediya'), findsNWidgets(3));
      expect(
        find.descendant(of: current, matching: find.text('Xwe nasandin')),
        findsOneWidget,
      );
      expect(tester.getSize(connector).width, 24);
      expect(
        path.stops.where((s) => s.state == LearnNodeState.current).length,
        1,
      );
      expect(
        path.stops
            .singleWhere((s) => s.state == LearnNodeState.current)
            .attachment,
        isNotNull,
      );
      await captureT15(tester, 'S21_sonra_KU');
      expect(tester.takeException(), isNull);
    },
  );
}
