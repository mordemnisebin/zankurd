import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/game/reveal_timing.dart';
import 'package:zankurd_mobile/src/game/server_clock.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/t8_game_fixtures.dart';
import 'support/widget_test_helpers.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('süre dolan sayaç başarı işareti yerine sıfır gösterir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    Future<void> pump(double progress) => tester.pumpWidget(
      testShell(
        child: Center(
          child: QuizTimerWidget(
            animation: AlwaysStoppedAnimation(progress),
            maxSeconds: 30,
            isPaused: true,
            stopped: true,
          ),
        ),
      ),
    );
    await pump(.4);
    final size = tester.getSize(find.byType(QuizTimerWidget));
    await pump(0);
    expect(find.byKey(const ValueKey('stage-timer-revealed')), findsNothing);
    expect(find.text('0'), findsOneWidget);
    expect(find.bySemanticsLabel('Süre doldu'), findsOneWidget);
    expect(tester.getSize(find.byType(QuizTimerWidget)), size);
    semantics.dispose();
  });

  testWidgets('kilitli seçenek yazısı ve harfi canlı kontrastını korur', (
    tester,
  ) async {
    var taps = 0;
    Future<void> pump(bool locked) => tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: QuizOptionTile(
            index: 0,
            answer: 'Cevap',
            selected: false,
            correct: false,
            disabled: locked,
            dimmed: locked,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await pump(false);
    final answerColor = tester.widget<Text>(find.text('Cevap')).style!.color;
    final letterColor = tester.widget<Text>(find.text('A')).style!.color;
    await pump(true);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('Cevap')).style!.color, answerColor);
    expect(tester.widget<Text>(find.text('A')).style!.color, letterColor);
    await tester.tap(find.text('Cevap'));
    expect(taps, 0, reason: 'Okunaklı seçenek yeniden yanıtlanamaz');
  });

  testWidgets('çevrimiçi TIMEOUT oturumu geri açılınca saat sıfır kalır', (
    tester,
  ) async {
    freshMockRepository();
    final now = DateTime.utc(2026, 10, 30);
    final repo = _ResumedTimeoutRepo(
      RoomResumeSnapshot(
        room: t8GameRoom(),
        currentQuestionIndex: 0,
        ownScore: 0,
        streak: 0,
        bestStreak: 0,
        correctCount: 0,
        wrongCount: 1,
        answers: const [
          ResumedAnswer(
            questionId: 't8-game',
            questionIndex: 0,
            selectedOptionKey: 'TIMEOUT',
            correctOptionKey: 'A',
            isCorrect: false,
            pointsAwarded: 0,
            responseMs: 30000,
          ),
        ],
        serverNow: now,
        questionStartedAt: now.subtract(const Duration(seconds: 30)),
        deadline: now,
        remainingMs: 0,
        serverClock: ServerClock(serverNow: now, elapsed: () => Duration.zero),
        revealClock: ServerRevealClock(
          serverNow: now,
          endsAt: now.add(const Duration(seconds: 60)),
          elapsed: () => Duration.zero,
        ),
      ),
    );
    addTearDown(repo.disposeVisual);
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: repo.snapshot.room,
          questions: [t8GameQuestion.copyWith(correctAnswer: '')],
          is1v1: true,
          resumeSnapshot: repo.snapshot,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      find.byKey(const ValueKey('quiz-reveal-status-band')),
      findsOneWidget,
    );
    expect(find.textContaining('Süre doldu'), findsOneWidget);
    final timer = tester.widget<SahneStageTimer>(find.byType(SahneStageTimer));
    expect(timer.revealed, isFalse, reason: 'TIMEOUT başarılı cevap değildir');
    expect(timer.secondsLeft, 0);
    expect(timer.semanticLabel, 'Süre doldu');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final ku in [false, true]) {
    testWidgets('cevap seç yönergesi düğme değildir; geometri korunur ku=$ku', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final repo = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : null,
          child: QuizScreen(
            repository: repo,
            room: repo.createRoom(),
            questions: const [t8GameQuestion],
            enableTimer: false,
            experience: QuizExperience.learning,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final instruction = find.text(
        ku ? 'Bersivekê hilbijêre' : 'Bir cevap seç',
      );
      expect(instruction, findsOneWidget);
      expect(
        find.ancestor(of: instruction, matching: find.byType(SahneButton)),
        findsNothing,
      );
      expect(
        tester.getSemantics(instruction).flagsCollection.isButton,
        isFalse,
      );
      final style = tester.widget<Text>(instruction).style!;
      expect(style.fontSize, greaterThanOrEqualTo(14));
      final prompt = find.byType(QuizQuestionPrompt);
      final top = tester.getTopLeft(prompt).dy;
      final dock = find.byType(QuizStableDockHeight);
      final dockRect = tester.getRect(dock);
      await tester.tap(find.text('2').first);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(prompt).dy, closeTo(top, .5));
      expect(tester.getRect(dock).height, closeTo(dockRect.height, .5));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
}

class _ResumedTimeoutRepo extends T8GameVisualRepository {
  _ResumedTimeoutRepo(this.snapshot);
  final RoomResumeSnapshot snapshot;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async =>
      snapshot;

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async => snapshot;
}
