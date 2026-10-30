import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'support/t8_game_fixtures.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets(
    'S9 cevap açılışında saniye kalır, genel onay tiki yok; boyut sabit',
    (tester) async {
      Future<void> pump(bool stopped) => tester.pumpWidget(
        testShell(
          child: Center(
            child: QuizTimerWidget(
              animation: const AlwaysStoppedAnimation(.4),
              maxSeconds: 20,
              isPaused: stopped,
              stopped: stopped,
            ),
          ),
        ),
      );
      await pump(false);
      final before = tester.getSize(find.byType(QuizTimerWidget));
      await pump(true);
      expect(find.byKey(const ValueKey('stage-timer-revealed')), findsNothing);
      expect(find.byKey(const ValueKey('stage-timer-paused')), findsNothing);
      expect(find.byKey(const ValueKey('stage-timer-seconds')), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(tester.getSize(find.byType(QuizTimerWidget)), before);
    },
  );
  testWidgets('F08 kalabalık odada sıra puan sıralaması olarak adlandırılır', (
    tester,
  ) async {
    final repo = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: t8GameRoom(crowd: true),
          questions: const [t8GameQuestion],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sıralaman'), findsOneWidget);
    expect(find.text('Sıran'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final ku in [false, true]) {
    for (final win in [false, true]) {
      testWidgets(
        'F01 F02 grup özeti ve ilk sıralama satırı ilk görünümde $win ku=$ku',
        (tester) async {
          tester.view.physicalSize = const Size(402, 874);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
          tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
          addTearDown(tester.view.reset);
          final repo = freshMockRepository();
          final players = [
            Player(
              id: 'user',
              name: 'Azad',
              score: win ? 152 : 0,
              rank: win ? 1 : 2,
              state: '',
            ),
            Player(
              id: 'opp',
              name: 'Cano',
              score: win ? 111 : 152,
              rank: win ? 2 : 1,
              state: '',
            ),
            const Player(
              id: 'third',
              name: 'Dilan',
              score: 0,
              rank: 2,
              state: '',
            ),
            const Player(
              id: 'fourth',
              name: 'Bero',
              score: 0,
              rank: 2,
              state: '',
            ),
          ];
          await tester.pumpWidget(
            testShell(
              languageProvider: ku ? kurmanciLang() : null,
              child: QuizResultScreen(
                repository: repo,
                room: GameRoom(
                  id: 't12',
                  name: 'T12',
                  code: 'T12',
                  category: 'Tevlihev',
                  questionCount: 10,
                  maxPlayers: 4,
                  isCustom: true,
                  status: RoomStatus.finished,
                  players: players,
                ),
                resultOwnerUserId: 'user',
                rewardSettlementState: QuizRewardSettlementState.claimed,
                score: win ? 152 : 0,
                correctCount: win ? 1 : 0,
                wrongCount: win ? 0 : 1,
                totalQuestions: 10,
                bestStreak: win ? 1 : 0,
                coinsAwarded: 20,
                answerRecords: [
                  for (var i = 0; i < 10; i++)
                    AnswerRecord(
                      id: 't12-$i',
                      category: 'Ziman',
                      prompt: 'Pirs $i',
                      answers: const ['A', 'B'],
                      correctAnswer: 'A',
                      selectedAnswer: i == 0 ? (win ? 'A' : 'B') : 'TIMEOUT',
                      explanation: 'The correct answer is A.',
                      explanationTr: 'Doğru cevap A seçeneğidir.',
                      explanationKu: 'Bersiva rast A ye.',
                    ),
                ],
                opponents: players.skip(1).toList(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('result-see-answers-button')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('result-level-journey-progress')),
            findsOneWidget,
          );
          final hero = tester.widget<SahneResultHero>(
            find.byKey(const ValueKey('result-score-header')),
          );
          expect(
            hero.caption,
            contains(
              win
                  ? (ku ? 'Rêza te #1/4' : 'Sıralaman #1/4')
                  : (ku
                        ? '4 lîstikvanan'
                        : '4 oyuncu arasında 2. sırayı 3 kişi paylaştınız.'),
            ),
          );
          final first = find.byKey(
            ValueKey(win ? 'crowd-standing-me-1' : 'crowd-standing-opp'),
          );
          final viewport = tester.getRect(find.byType(ListView).first);
          expect(
            tester.getRect(first).bottom,
            lessThanOrEqualTo(viewport.bottom - 16),
            reason: 'ilk oyuncu satırı alt solma bandına girmez',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets('F05 düello sonuç başlığı oyun türünü açıklar', (tester) async {
    final repo = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repo,
          room: repo.createRoom(),
          score: 308,
          correctCount: 2,
          wrongCount: 2,
          totalQuestions: 10,
          bestStreak: 2,
          coinsAwarded: 35,
          answerRecords: const [],
          opponents: const [Player(name: 'Bero', score: 668, state: '')],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final scene = tester.widget<SahneResultScaffold>(
      find.byType(SahneResultScaffold),
    );
    expect(scene.contextLabel, contains('düello'));
  });
}
