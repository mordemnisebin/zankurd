import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

RoomResumeSnapshot _startedSnapshot(GameRoom room, {required int remainingMs}) {
  final now = DateTime.utc(2026, 8, 2, 12);
  return RoomResumeSnapshot(
    room: room,
    currentQuestionIndex: 0,
    ownScore: 0,
    streak: 0,
    bestStreak: 0,
    correctCount: 0,
    wrongCount: 0,
    answers: const [],
    serverNow: now,
    questionStartedAt: now,
    deadline: now.add(Duration(milliseconds: remainingMs)),
    remainingMs: remainingMs,
  );
}

RoomResumeSnapshot _timeoutRevealSnapshot(GameRoom room) {
  final now = DateTime.utc(2026, 8, 2, 12);
  return RoomResumeSnapshot(
    room: room,
    currentQuestionIndex: 0,
    ownScore: 0,
    streak: 0,
    bestStreak: 0,
    correctCount: 0,
    wrongCount: 1,
    answers: const [
      ResumedAnswer(
        questionId: '00000000-0000-0000-0000-000000000101',
        questionIndex: 0,
        selectedOptionKey: 'TIMEOUT',
        correctOptionKey: 'A',
        isCorrect: false,
        pointsAwarded: 0,
        responseMs: 20000,
      ),
    ],
    serverNow: now,
    questionStartedAt: now.subtract(const Duration(seconds: 20)),
    deadline: now,
    remainingMs: 0,
  );
}

class _StartedHiddenRepository extends MockZanKurdRepository {
  RoomResumeSnapshot? snapshot;
  int advanceCalls = 0;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async =>
      snapshot;

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async => null;

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async {
    advanceCalls += 1;
    return snapshot;
  }
}

class _DelayedHiddenAdvanceRepository extends _StartedHiddenRepository {
  final advanceResult = Completer<RoomResumeSnapshot?>();

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) {
    advanceCalls += 1;
    return advanceResult.future;
  }
}

class _FailingHiddenAdvanceRepository extends _StartedHiddenRepository {
  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async {
    advanceCalls += 1;
    throw StateError('advance unavailable');
  }
}

const _hiddenQuestion = QuizQuestion(
  id: '00000000-0000-0000-0000-000000000101',
  category: 'Ziman',
  prompt: 'Pirtûk çi ye?',
  answers: ['Kitêb', 'Mase', 'Av', 'Mal'],
  correctAnswer: '',
  explanation: '',
);

void main() {
  testWidgets('sunucu gizli deadline CAS sonucu gelene kadar reveal yapmaz', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _DelayedHiddenAdvanceRepository();
    final room = repository.createRoom().copyWith(
      id: '00000000-0000-0000-0000-000000000001',
      status: RoomStatus.active,
      secondsPerQuestion: 20,
    );
    repository.snapshot = _startedSnapshot(room, remainingMs: 20000);

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: const [_hiddenQuestion],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    expect(repository.advanceCalls, 1);
    expect(find.byKey(const ValueKey('quiz-timeout-notice')), findsNothing);
    final pendingTiles = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(pendingTiles, hasLength(4));
    expect(pendingTiles.every((tile) => !tile.correct), isTrue);
    expect(pendingTiles.every((tile) => !tile.dimmed), isTrue);

    repository.advanceResult.complete(_timeoutRevealSnapshot(room));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Süre doldu! Doğru cevap: Kitêb'), findsOneWidget);
    final revealedTiles = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(revealedTiles.where((tile) => tile.correct).single.answer, 'Kitêb');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('gizli deadline CAS hatası local timeout döngüsü üretmez', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _FailingHiddenAdvanceRepository();
    final room = repository.createRoom().copyWith(
      id: '00000000-0000-0000-0000-000000000001',
      status: RoomStatus.active,
      secondsPerQuestion: 20,
    );
    repository.snapshot = _startedSnapshot(room, remainingMs: 20000);

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: const [_hiddenQuestion],
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(repository.advanceCalls, greaterThan(0));
    expect(repository.advanceCalls, lessThanOrEqualTo(6));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
