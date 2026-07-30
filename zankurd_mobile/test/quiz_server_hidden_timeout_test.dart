import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

class _DelayedHiddenAnswerRepository extends MockZanKurdRepository {
  final answerResult = Completer<Map<String, dynamic>>();
  int submitCalls = 0;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) {
    submitCalls += 1;
    return answerResult.future;
  }
}

class _FailingHiddenAnswerRepository extends MockZanKurdRepository {
  int submitCalls = 0;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    submitCalls += 1;
    throw StateError('answer unavailable');
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
  testWidgets('sunucu gizli TIMEOUT sonucu gelene kadar reveal yapmaz', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _DelayedHiddenAnswerRepository();
    final room = repository.createRoom().copyWith(
      id: '00000000-0000-0000-0000-000000000001',
      status: RoomStatus.active,
      secondsPerQuestion: 20,
    );

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

    expect(repository.submitCalls, 1);
    expect(find.byKey(const ValueKey('quiz-timeout-notice')), findsNothing);
    final pendingTiles = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(pendingTiles, hasLength(4));
    expect(pendingTiles.every((tile) => !tile.correct), isTrue);
    expect(pendingTiles.every((tile) => !tile.dimmed), isTrue);

    repository.answerResult.complete({
      'is_correct': false,
      'points': 0,
      'new_score': 0,
      'new_streak': 0,
      'correct_option': 'A',
      'explanation': 'Pirtûk kitêb e.',
      'explanation_ku': 'Pirtûk kitêb e.',
      'explanation_tr': 'Pirtûk kitap demektir.',
      'already_answered': false,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(find.text('Süre doldu! Doğru cevap: Kitêb'), findsOneWidget);
    final revealedTiles = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(revealedTiles.where((tile) => tile.correct).single.answer, 'Kitêb');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('gizli TIMEOUT gönderimi başarısızsa sayaç yeniden geri sayar', (
    tester,
  ) async {
    freshMockRepository();
    final repository = _FailingHiddenAnswerRepository();
    final room = repository.createRoom().copyWith(
      id: '00000000-0000-0000-0000-000000000001',
      status: RoomStatus.active,
      secondsPerQuestion: 20,
    );

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

    expect(repository.submitCalls, 1);

    await tester.pump(const Duration(seconds: 21));
    await tester.pump();

    expect(repository.submitCalls, 2);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
