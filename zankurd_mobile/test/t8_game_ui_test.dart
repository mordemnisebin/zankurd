import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/t8_game_fixtures.dart';
import 'support/widget_test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpQuiz(
    WidgetTester tester, {
    int mine = 0,
    int theirs = 284,
    bool crowd = false,
    bool ku = false,
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = freshMockRepository();
    await repository.updateProfileName('Tolhildan Mawal');
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final room = GameRoom(
      id: 't8-room',
      name: 'T8',
      code: 'T8',
      category: 'Ziman',
      status: RoomStatus.active,
      questionCount: 2,
      maxPlayers: crowd ? 4 : 2,
      isCustom: crowd,
      players: [
        Player(
          id: 'user',
          name: 'Tolhildan Mawal',
          score: mine,
          state: 'Hazır',
        ),
        Player(id: 'opp', name: 'Rakip', score: theirs, state: 'Hazır'),
        if (crowd) ...const [
          Player(name: 'Üçüncü', score: 1234, state: 'Hazır'),
          Player(name: 'Dördüncü', score: 99999, state: 'Hazır'),
        ],
      ],
    );
    await tester.pumpWidget(
      testShell(
        languageProvider: ku ? kurmanciLang() : null,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: QuizScreen(
              repository: repository,
              room: room,
              questions: repository.questions.take(2).toList(),
              is1v1: !crowd,
              enableTimer: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  for (final mine in [0, 284]) {
    testWidgets('E4: sıfır puanlı taraf ilk karede bile dilim almaz ($mine)', (
      tester,
    ) async {
      await pumpQuiz(tester, mine: mine, theirs: 284 - mine);
      expect(find.byKey(const ValueKey('duel-tug-bar')), findsOneWidget);
      final zero = mine == 0 ? 'left' : 'right';
      expect(find.byKey(ValueKey('duel-tug-$zero')), findsNothing);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byKey(ValueKey('duel-tug-$zero')), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('E4: 0–0 çubuğu nötr kalır', (tester) async {
    await pumpQuiz(tester, mine: 0, theirs: 0);
    final left = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('duel-tug-left')),
    );
    final right = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('duel-tug-right')),
    );
    expect(left.color, right.color);
    expect(duelTugShare(0, 0), 0.5);
  });

  for (final win in [false, true]) {
    testWidgets('E6: sonuç süsleri yalnız galibiyette ($win)', (tester) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repository,
            room: repository.createRoom(),
            score: win ? 500 : 200,
            correctCount: 4,
            wrongCount: 1,
            totalQuestions: 5,
            bestStreak: 4,
            coinsAwarded: 0,
            answerRecords: const [],
            opponents: [
              Player(name: 'Rakip', score: win ? 200 : 500, state: 'Bot'),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      final hero = tester.widget<SahneResultHero>(
        find.byKey(const ValueKey('result-score-header')),
      );
      final score = tester.widget<Text>(
        find.byKey(const ValueKey('result-duel-score-me')),
      );
      final opponentScore = tester.widget<Text>(
        find.byKey(const ValueKey('result-duel-score-opponent')),
      );
      final scene = tester.widget<SahneResultScene>(
        find.byType(SahneResultScene).first,
      );
      expect(score.style, opponentScore.style);
      expect(hero.celebrate, win);
      expect(hero.lightGlow, win);
      expect(hero.calm, !win);
      expect(score.style!.color, SahneTokens.night.tx);
      expect(
        scene.mood,
        SahneResultMood.high,
        reason: 'sahne rengi soldurulmaz',
      );
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<SahneResultBackdropPainter>();
      expect(painters, isNotEmpty);
      expect(painters.every((painter) => painter.rays == win), isTrue);
    });
  }

  testWidgets(
    'E10/E11: gerçek oyun yanıt sonrası rakip sayacı ve açılışta cevap işareti',
    (tester) async {
      freshMockRepository();
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      final repository = T8GameVisualRepository();
      addTearDown(repository.disposeVisual);
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: t8GameRoom(),
            questions: const [t8GameQuestion, t8GameQuestion],
            is1v1: true,
            enableTimer: true,
            suspenseHold: Duration.zero,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final initial = tester.getRect(
        find.byKey(const ValueKey('stage-timer-capsule')),
      );
      await tester.tap(find.text('3'));
      await tester.pump(const Duration(milliseconds: 400));
      final waiting = tester.widget<SahneStageTimer>(
        find.byType(SahneStageTimer),
      );
      expect(waiting.secondary, isTrue);
      expect(waiting.semanticLabel, contains('Rakibin süresi'));
      expect(waiting.pending, isFalse);
      expect(
        tester.getRect(find.byKey(const ValueKey('stage-timer-capsule'))),
        initial,
      );
      repository.revealOpponentAnswer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(
        tester.widget<SahneStageTimer>(find.byType(SahneStageTimer)).revealed,
        isFalse,
      );
      expect(find.byKey(const ValueKey('stage-timer-revealed')), findsNothing);
      expect(find.byKey(const ValueKey('stage-timer-seconds')), findsNothing);
      expect(find.byKey(const ValueKey('stage-timer-paused')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const ValueKey('stage-timer-capsule'))),
        initial,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final ku in [false, true]) {
    testWidgets(
      'E10/E11: sayaç sahipliği ve cevap işareti sabit geometri (${ku ? 'KU' : 'TR'})',
      (tester) async {
        Future<void> pump({bool opponent = false, bool stopped = false}) async {
          await tester.pumpWidget(
            testShell(
              languageProvider: ku ? kurmanciLang() : null,
              child: Center(
                child: QuizTimerWidget(
                  animation: const AlwaysStoppedAnimation(0.2),
                  maxSeconds: 20,
                  isPaused: opponent,
                  opponentTime: opponent,
                  stopped: stopped,
                ),
              ),
            ),
          );
        }

        await pump();
        final active = tester.getRect(
          find.byKey(const ValueKey('stage-timer-capsule')),
        );
        await pump(opponent: true);
        final waiting = tester.widget<SahneStageTimer>(
          find.byType(SahneStageTimer),
        );
        expect(waiting.secondary, isTrue);
        expect(waiting.isHot, isFalse);
        expect(
          waiting.semanticLabel,
          contains(ku ? 'hevrik' : 'Rakibin süresi'),
        );
        final number = tester.widget<Text>(
          find.byKey(const ValueKey('stage-timer-seconds')),
        );
        expect(
          number.style!.color,
          SahneTokens.of(tester.element(find.byType(SahneStageTimer))).tx2,
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('stage-timer-capsule'))),
          active,
        );
        await pump(stopped: true);
        expect(
          find.byKey(const ValueKey('stage-timer-revealed')),
          findsNothing,
        );
        expect(find.byKey(const ValueKey('stage-timer-seconds')), findsNothing);
        expect(
          find.byKey(const ValueKey('stage-timer-paused')),
          findsOneWidget,
        );
        expect(find.text('4'), findsNothing);
        expect(
          tester
              .widget<SahneStageTimer>(find.byType(SahneStageTimer))
              .semanticLabel,
          ku ? 'Bersiv eşkere ne' : 'Cevaplar açık',
        );
        expect(
          tester.getRect(find.byKey(const ValueKey('stage-timer-capsule'))),
          active,
        );
      },
    );

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets(
        'E14: oda kendi çipinde Sen tam görünür (${ku ? 'KU' : 'TR'} $scale)',
        (tester) async {
          await pumpQuiz(tester, crowd: true, ku: ku, scale: scale);
          final mark = find.byKey(const ValueKey('quiz-crowd-self-mark'));
          expect(mark, findsOneWidget);
          final text = tester.widget<Text>(mark);
          expect(text.data, ku ? '(Tu)' : '(Sen)');
          expect(text.style!.fontSize, greaterThanOrEqualTo(14));
          final paragraph = tester.renderObject<RenderParagraph>(
            find.descendant(of: mark, matching: find.byType(RichText)),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          final header = tester.getRect(
            find.byKey(const ValueKey('quiz-crowd-header')),
          );
          expect(header.contains(tester.getRect(mark).topLeft), isTrue);
          expect(header.contains(tester.getRect(mark).bottomRight), isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
