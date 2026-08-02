import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
    DailyMissionStore.resetInstance();
    MasteryStore.resetInstance();
    MistakeStore.resetInstance();
    StreakStore.resetInstance();
    XPStore.resetInstance();
  });

  testWidgets('questions mapper ve claimed reward sonucu result açar', (
    tester,
  ) async {
    final repository = _RecoveryRepository(questionResponses: [_questions]);
    await _pumpRecovery(
      tester,
      repository: repository,
      expectedUserId: ' user-1 ',
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pumpAndSettle();

    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.score, 30);
    expect(result.correctCount, 1);
    expect(result.wrongCount, 1);
    expect(result.bestStreak, 1);
    expect(result.answerRecords.first.prompt, 'Türkçe q1');
    expect(result.coinsAwarded, 24);
    expect(result.rewardSettlementState, QuizRewardSettlementState.claimed);
    expect(result.resultOwnerUserId, 'user-1');
    expect(result.rewardQueued, isFalse);
    expect(repository.awardCalls, 1);
  });

  testWidgets('başlangıç owner uyuşmazlığı reward ve navigation yapmaz', (
    tester,
  ) async {
    final repository = _RecoveryRepository(questionResponses: [_questions])
      ..userId = 'other-user';
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pump();

    expect(repository.loadQuestionCalls, 0);
    expect(repository.awardCalls, 0);
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(find.byType(RoomResultRecoveryScreen), findsOneWidget);
  });

  testWidgets('malformed üç oyunculu snapshot teslim edilmez', (tester) async {
    final repository = _RecoveryRepository(questionResponses: [_questions]);
    await _pumpRecovery(
      tester,
      repository: repository,
      snapshot: _snapshotWithRoom(
        _snapshot.room.copyWith(
          players: const [
            Player(
              id: 'user-1',
              name: 'Ez',
              score: 30,
              state: Player.readyState,
            ),
            Player(
              id: 'opponent',
              name: 'Hevrik',
              score: 20,
              state: Player.readyState,
            ),
            Player(
              id: 'opponent',
              name: 'Hevrik dublîkat',
              score: 20,
              state: Player.readyState,
            ),
          ],
        ),
      ),
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pump();

    expect(repository.loadQuestionCalls, 0);
    expect(repository.awardCalls, 0);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('question beklerken hesap değişirse reward ve navigation olmaz', (
    tester,
  ) async {
    final gate = Completer<List<QuizQuestion>>();
    final repository = _RecoveryRepository(questionGate: gate);
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    repository.userId = 'other-user';
    gate.complete(_questions);
    await tester.pump();
    await tester.pump();

    expect(repository.awardCalls, 0);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('question beklerken üst rota açılırsa onu değiştirmez', (
    tester,
  ) async {
    final gate = Completer<List<QuizQuestion>>();
    final repository = _RecoveryRepository(questionGate: gate);
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pump();

    final recoveryContext = tester.element(
      find.byType(RoomResultRecoveryScreen),
    );
    unawaited(
      Navigator.of(recoveryContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Üst rota')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gate.complete(_questions);
    await tester.pumpAndSettle();

    expect(find.text('Üst rota'), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.awardCalls, 0);

    Navigator.of(tester.element(find.text('Üst rota'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Tekrar dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizResultScreen), findsOneWidget);
  });

  testWidgets('reward settlement beklerken hesap değişirse sonuç açılmaz', (
    tester,
  ) async {
    final awardGate = Completer<int>();
    final repository = _RecoveryRepository(
      questionResponses: [_questions, _questions],
      awardGate: awardGate,
    );
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    for (var i = 0; i < 10 && repository.awardCalls == 0; i++) {
      await tester.pump();
    }
    expect(repository.awardCalls, 1);

    repository.userId = 'other-user';
    awardGate.complete(24);
    await tester.pump();
    await tester.pump();

    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.ackCalls, 0);

    repository.userId = 'user-1';
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.coinsAwarded, 24);
    expect(repository.awardCalls, 1);
  });

  testWidgets('owner yarışında unresolved reward Retry ile yeniden denenir', (
    tester,
  ) async {
    final awardGate = Completer<int>();
    final repository = _RecoveryRepository(
      questionResponses: [_questions],
      awardGate: awardGate,
    );
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(
        repository: repository,
        errorRecorder: (_, _, {reason}) {},
      ),
    );
    for (var i = 0; i < 10 && repository.awardCalls == 0; i++) {
      await tester.pump();
    }
    expect(repository.awardCalls, 1);

    repository.userId = 'other-user';
    awardGate.completeError(StateError('session changed'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(QuizResultScreen), findsNothing);
    expect(find.text('Tekrar dene'), findsOneWidget);

    repository
      ..userId = 'user-1'
      ..awardGate = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.rewardSettlementState, QuizRewardSettlementState.claimed);
    expect(result.coinsAwarded, 24);
    expect(repository.awardCalls, 2);
  });

  testWidgets('queued settlement stale hesap Retryında tekrar çalışmaz', (
    tester,
  ) async {
    final queueGate = Completer<void>();
    final repository = _RecoveryRepository(
      questionResponses: [_questions, _questions],
      awardError: StateError('offline'),
    );
    var queueCalls = 0;
    final service = QuizRewardSettlementService(
      repository: repository,
      queueReward:
          ({
            required score,
            required correctCount,
            required bestStreak,
            required totalQuestions,
            required roomId,
          }) async {
            queueCalls++;
            await queueGate.future;
          },
      errorRecorder: (_, _, {reason}) {},
    );
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: service,
    );
    for (var i = 0; i < 10 && queueCalls == 0; i++) {
      await tester.pump();
    }
    expect(repository.awardCalls, 1);
    expect(queueCalls, 1);

    repository.userId = 'other-user';
    queueGate.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.ackCalls, 0);

    repository.userId = 'user-1';
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.rewardSettlementState, QuizRewardSettlementState.queued);
    expect(repository.awardCalls, 1);
    expect(queueCalls, 1);
  });

  testWidgets('question ve mapper hataları retry ile iyileşir', (tester) async {
    final repository = _RecoveryRepository(
      questionResponses: [
        StateError('network'),
        [_questions.last, _questions.first],
        _questions,
      ],
    );
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Tekrar dene'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Tekrar dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(repository.loadQuestionCalls, 3);
  });

  testWidgets('takılan question load sınırlı sürede Retry açar', (
    tester,
  ) async {
    final gate = Completer<List<QuizQuestion>>();
    final repository = _RecoveryRepository(questionGate: gate);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(_questions);
    });
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();

    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
  });

  testWidgets('takılan settlement Retryda aynı in-flight işi kullanır', (
    tester,
  ) async {
    final awardGate = Completer<int>();
    final repository = _RecoveryRepository(
      questionResponses: [_questions],
      awardGate: awardGate,
    );
    addTearDown(() {
      if (!awardGate.isCompleted) awardGate.complete(24);
    });
    await _pumpRecovery(
      tester,
      repository: repository,
      settlementService: QuizRewardSettlementService(repository: repository),
    );
    for (var i = 0; i < 10 && repository.awardCalls == 0; i++) {
      await tester.pump();
    }
    expect(repository.awardCalls, 1);

    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('Tekrar dene'), findsOneWidget);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    expect(repository.awardCalls, 1);

    awardGate.complete(24);
    await tester.pumpAndSettle();
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(repository.awardCalls, 1);
  });

  testWidgets(
    'timeout sonrası stale unresolved settlement Retryda yeniden çalışır',
    (tester) async {
      final awardGate = Completer<int>();
      final repository = _RecoveryRepository(
        questionResponses: [_questions],
        awardGate: awardGate,
      );
      await _pumpRecovery(
        tester,
        repository: repository,
        settlementService: QuizRewardSettlementService(
          repository: repository,
          errorRecorder: (_, _, {reason}) {},
        ),
      );
      for (var i = 0; i < 10 && repository.awardCalls == 0; i++) {
        await tester.pump();
      }
      expect(repository.awardCalls, 1);

      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(find.text('Tekrar dene'), findsOneWidget);

      repository.userId = 'other-user';
      awardGate.completeError(StateError('session changed'));
      await tester.pump();
      repository
        ..userId = 'user-1'
        ..awardGate = null;

      await tester.tap(find.text('Tekrar dene'));
      await tester.pumpAndSettle();

      final result = tester.widget<QuizResultScreen>(
        find.byType(QuizResultScreen),
      );
      expect(result.rewardSettlementState, QuizRewardSettlementState.claimed);
      expect(result.coinsAwarded, 24);
      expect(repository.awardCalls, 2);
    },
  );

  testWidgets('geri tuşu stale oda rotasını da temizler', (tester) async {
    final gate = Completer<List<QuizQuestion>>();
    final repository = _RecoveryRepository(questionGate: gate);
    addTearDown(() {
      if (!gate.isCompleted) gate.complete(_questions);
    });
    await tester.pumpWidget(
      testShell(
        child: _NestedRecoveryLauncher(
          repository: repository,
          settlementService: QuizRewardSettlementService(
            repository: repository,
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open-stale-room')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-recovery')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(RoomResultRecoveryScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-stale-room')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-recovery')), findsNothing);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);

    gate.complete(_questions);
    await tester.pump();
  });

  for (final state in [
    QuizRewardSettlementState.queued,
    QuizRewardSettlementState.unresolved,
  ]) {
    testWidgets('$state sonucu state ile birlikte result açar', (tester) async {
      final repository = _RecoveryRepository(
        questionResponses: [_questions],
        awardError: StateError('offline'),
      );
      var queueCalls = 0;
      final service = QuizRewardSettlementService(
        repository: repository,
        queueReward: state == QuizRewardSettlementState.queued
            ? ({
                required score,
                required correctCount,
                required bestStreak,
                required totalQuestions,
                required roomId,
              }) async {
                queueCalls++;
              }
            : null,
        errorRecorder: (_, _, {reason}) {},
      );

      await _pumpRecovery(
        tester,
        repository: repository,
        settlementService: service,
      );
      await tester.pumpAndSettle();

      final result = tester.widget<QuizResultScreen>(
        find.byType(QuizResultScreen),
      );
      expect(result.rewardSettlementState, state);
      expect(result.rewardQueued, state == QuizRewardSettlementState.queued);
      expect(result.coinsAwarded, 0);
      expect(queueCalls, state == QuizRewardSettlementState.queued ? 1 : 0);
      expect(repository.ackCalls, 0);
    });
  }
}

Future<void> _pumpRecovery(
  WidgetTester tester, {
  required _RecoveryRepository repository,
  String expectedUserId = 'user-1',
  RoomResultSnapshot? snapshot,
  required QuizRewardSettlementService settlementService,
}) {
  return tester.pumpWidget(
    testShell(
      child: RoomResultRecoveryScreen(
        repository: repository,
        snapshot: snapshot ?? _snapshot,
        expectedUserId: expectedUserId,
        rewardSettlementService: settlementService,
      ),
    ),
  );
}

class _RecoveryRepository extends MockZanKurdRepository {
  _RecoveryRepository({
    this.questionResponses = const [],
    this.questionGate,
    this.awardGate,
    this.awardError,
  });

  String userId = 'user-1';
  final List<Object> questionResponses;
  final Completer<List<QuizQuestion>>? questionGate;
  Completer<int>? awardGate;
  final Object? awardError;
  int loadQuestionCalls = 0;
  int awardCalls = 0;
  int ackCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    loadQuestionCalls++;
    final gate = questionGate;
    if (gate != null) return gate.future;
    final response = questionResponses[loadQuestionCalls - 1];
    if (response is! List<QuizQuestion>) throw response;
    return response;
  }

  @override
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    awardCalls++;
    if (awardError case final error?) throw error;
    expect(
      [score, correctCount, bestStreak, totalQuestions, room?.id],
      [30, 1, 1, 2, 'room-1'],
    );
    final gate = awardGate;
    if (gate != null) return gate.future;
    return 24;
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {
    ackCalls++;
  }
}

class _NestedRecoveryLauncher extends StatelessWidget {
  const _NestedRecoveryLauncher({
    required this.repository,
    required this.settlementService,
  });

  final _RecoveryRepository repository;
  final QuizRewardSettlementService settlementService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('open-stale-room'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (roomContext) => Scaffold(
                body: Center(
                  child: FilledButton(
                    key: const ValueKey('open-recovery'),
                    onPressed: () => Navigator.of(roomContext).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => RoomResultRecoveryScreen(
                          repository: repository,
                          snapshot: _snapshot,
                          expectedUserId: 'user-1',
                          rewardSettlementService: settlementService,
                        ),
                      ),
                    ),
                    child: const Text('Eski oda rotası'),
                  ),
                ),
              ),
            ),
          ),
          child: const Text('Ana kök'),
        ),
      ),
    );
  }
}

const _questions = [
  QuizQuestion(
    id: 'q1',
    category: 'Ziman',
    prompt: 'Kurmancî q1',
    promptTr: 'Türkçe q1',
    answers: ['yek', 'du', 'sê', 'çar'],
    answersTr: ['bir', 'iki', 'üç', 'dört'],
    correctAnswer: 'yek',
    correctAnswerTr: 'bir',
    explanation: 'Ravekirin',
  ),
  QuizQuestion(
    id: 'q2',
    category: 'Ziman',
    prompt: 'Kurmancî q2',
    promptTr: 'Türkçe q2',
    answers: ['yek', 'du', 'sê', 'çar'],
    answersTr: ['bir', 'iki', 'üç', 'dört'],
    correctAnswer: 'du',
    correctAnswerTr: 'iki',
    explanation: 'Ravekirin',
  ),
];

final _snapshot = RoomResultSnapshot(
  room: const GameRoom(
    id: 'room-1',
    name: '1vs1',
    code: 'ZK-TEST',
    category: 'Ziman',
    players: [
      Player(id: 'user-1', name: 'Ez', score: 30, state: Player.readyState),
      Player(
        id: 'opponent',
        name: 'Hevrik',
        score: 20,
        state: Player.readyState,
      ),
    ],
    status: RoomStatus.finished,
    questionCount: 2,
  ),
  ownPlayerId: 'user-1',
  questionIds: const ['q1', 'q2'],
  answers: const [
    ResumedAnswer(
      questionId: 'q1',
      questionIndex: 0,
      selectedOptionKey: 'A',
      correctOptionKey: 'A',
      isCorrect: true,
      pointsAwarded: 30,
      responseMs: 900,
    ),
    ResumedAnswer(
      questionId: 'q2',
      questionIndex: 1,
      selectedOptionKey: 'A',
      correctOptionKey: 'B',
      isCorrect: false,
      pointsAwarded: 0,
      responseMs: 1200,
    ),
  ],
  winnerId: 'user-1',
  endedReason: 'completed',
  forfeitedBy: null,
  finishedAt: DateTime.utc(2026, 8, 2),
);

RoomResultSnapshot _snapshotWithRoom(GameRoom room) {
  return RoomResultSnapshot(
    room: room,
    ownPlayerId: _snapshot.ownPlayerId,
    questionIds: _snapshot.questionIds,
    answers: _snapshot.answers,
    winnerId: _snapshot.winnerId,
    endedReason: _snapshot.endedReason,
    forfeitedBy: _snapshot.forfeitedBy,
    finishedAt: _snapshot.finishedAt,
  );
}
