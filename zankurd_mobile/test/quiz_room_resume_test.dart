import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';

import 'support/widget_test_helpers.dart';

const _questions = <QuizQuestion>[
  QuizQuestion(
    id: 'resume-q-1',
    category: 'Ziman',
    prompt: 'Pirs 1',
    answers: ['A1', 'B1', 'C1', 'D1'],
    correctAnswer: '',
    explanation: '',
  ),
  QuizQuestion(
    id: 'resume-q-2',
    category: 'Ziman',
    prompt: 'Pirs 2',
    answers: ['A2', 'B2', 'C2', 'D2'],
    correctAnswer: '',
    explanation: '',
  ),
  QuizQuestion(
    id: 'resume-q-3',
    category: 'Ziman',
    prompt: 'Pirs 3',
    answers: ['A3', 'B3', 'C3', 'D3'],
    correctAnswer: '',
    explanation: '',
  ),
];

const _resultQuestions = <QuizQuestion>[
  QuizQuestion(
    id: 'resume-q-1',
    category: 'Ziman',
    prompt: 'Pirs 1',
    answers: ['A1', 'B1', 'C1', 'D1'],
    correctAnswer: 'A1',
    explanation: 'A1 rast e.',
  ),
  QuizQuestion(
    id: 'resume-q-2',
    category: 'Ziman',
    prompt: 'Pirs 2',
    answers: ['A2', 'B2', 'C2', 'D2'],
    correctAnswer: 'A2',
    explanation: 'A2 rast e.',
  ),
  QuizQuestion(
    id: 'resume-q-3',
    category: 'Ziman',
    prompt: 'Pirs 3',
    answers: ['A3', 'B3', 'C3', 'D3'],
    correctAnswer: 'A3',
    explanation: 'A3 rast e.',
  ),
];

const _room = GameRoom(
  id: 'resume-room',
  name: '1v1',
  code: 'ZK-RSME',
  category: 'Ziman',
  players: [
    Player(id: 'me', name: 'Ez', score: 0, state: Player.readyState),
    Player(id: 'opponent', name: 'Rakip', score: 80, state: Player.readyState),
  ],
  status: RoomStatus.active,
  questionCount: 3,
  secondsPerQuestion: 30,
  hostId: 'opponent',
);

RoomResumeSnapshot _snapshot({
  int questionIndex = 1,
  int score = 420,
  int streak = 3,
  int bestStreak = 5,
  int correct = 1,
  int wrong = 0,
  int remainingMs = 12000,
  List<ResumedAnswer> answers = const [],
}) {
  final now = DateTime.utc(2026, 8, 2, 12);
  return RoomResumeSnapshot(
    room: _room,
    currentQuestionIndex: questionIndex,
    ownScore: score,
    streak: streak,
    bestStreak: bestStreak,
    correctCount: correct,
    wrongCount: wrong,
    answers: answers,
    serverNow: now,
    questionStartedAt: now.subtract(const Duration(seconds: 18)),
    deadline: now.add(Duration(milliseconds: remainingMs)),
    remainingMs: remainingMs,
  );
}

const _firstAnswer = ResumedAnswer(
  questionId: 'resume-q-1',
  questionIndex: 0,
  selectedOptionKey: 'B',
  correctOptionKey: 'A',
  isCorrect: false,
  pointsAwarded: 0,
  responseMs: 1800,
  explanation: 'A1 doğrudur.',
  explanationKu: 'A1 rast e.',
  explanationTr: 'A1 doğrudur.',
);

const _secondAnswer = ResumedAnswer(
  questionId: 'resume-q-2',
  questionIndex: 1,
  selectedOptionKey: 'B',
  correctOptionKey: 'A',
  isCorrect: false,
  pointsAwarded: 0,
  responseMs: 2100,
  explanation: 'A2 doğrudur.',
  explanationKu: 'A2 rast e.',
  explanationTr: 'A2 doğrudur.',
);

const _timeoutAnswer = ResumedAnswer(
  questionId: 'resume-q-2',
  questionIndex: 1,
  selectedOptionKey: 'TIMEOUT',
  correctOptionKey: 'A',
  isCorrect: false,
  pointsAwarded: 0,
  responseMs: 30000,
  explanation: 'A2 doğrudur.',
);

class _SessionRepository extends MockZanKurdRepository {
  _SessionRepository(this.snapshot);

  final StreamController<Map<String, dynamic>> broadcasts =
      StreamController<Map<String, dynamic>>.broadcast();
  RoomResumeSnapshot? snapshot;
  RoomResultSnapshot? exactResult = _resultSnapshot();
  final List<Object?> resultResponses = [];
  Completer<RoomResultSnapshot?>? resultGate;
  RoomLeaveOutcome leaveOutcome = const RoomLeaveOutcome(
    status: 'finished',
    reason: 'forfeit',
    forfeitedBy: 'player',
  );
  Object? finishError;
  String userId = 'me';
  RoomEndState endState = const RoomEndState(
    status: RoomStatus.active,
    endedReason: null,
    forfeitedBy: null,
  );
  Completer<RoomEndState>? endStateGate;
  List<Player> serverPlayers = _room.players;
  Completer<void>? pendingLeave;
  bool failLeave = false;
  Object? leaveErrorAfterGate;
  int resumeCalls = 0;
  int playerCalls = 0;
  int endStateCalls = 0;
  int leaveCalls = 0;
  int finishCalls = 0;
  int awardCalls = 0;
  int submitCalls = 0;
  int advanceCalls = 0;
  int resultCalls = 0;
  int resultQuestionCalls = 0;
  int ackCalls = 0;
  List<Object?>? lastAwardArguments;

  @override
  String? get currentUserId => userId;

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<String> getProfileName() async => 'Ez';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      broadcasts.stream;

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {}

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    resumeCalls++;
    return snapshot;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    playerCalls++;
    return serverPlayers;
  }

  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async {
    endStateCalls++;
    final gate = endStateGate;
    if (gate != null) return gate.future;
    return endState;
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    leaveCalls++;
    if (failLeave) {
      failLeave = false;
      throw StateError('network detail must stay hidden');
    }
    await pendingLeave?.future;
    if (leaveErrorAfterGate case final error?) throw error;
    return leaveOutcome;
  }

  @override
  Future<void> finishGame(GameRoom room) async {
    finishCalls++;
    if (finishError case final error?) throw error;
  }

  @override
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room) async {
    resultCalls++;
    final gate = resultGate;
    if (gate != null) return gate.future;
    final response = resultResponses.isEmpty
        ? exactResult
        : resultResponses.removeAt(0);
    if (response == null) return null;
    if (response is RoomResultSnapshot) return response;
    throw response;
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    resultQuestionCalls++;
    return _resultQuestions;
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {
    ackCalls++;
  }

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async {
    advanceCalls++;
    return null;
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    submitCalls++;
    return {
      'is_correct': false,
      'points': 0,
      'new_score': snapshot?.ownScore ?? 0,
      'new_streak': 0,
      'correct_option': 'A',
      'explanation': 'Süre doldu.',
    };
  }

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    awardCalls++;
    lastAwardArguments = [
      score,
      correctCount,
      bestStreak,
      totalQuestions,
      room?.id,
    ];
    return (amount: 7, dailyCapReached: false);
  }

  Future<void> close() => broadcasts.close();
}

class _QuizLauncher extends StatelessWidget {
  const _QuizLauncher({
    required this.repository,
    this.onResult,
    this.enableTimer = true,
  });

  final _SessionRepository repository;
  final ValueChanged<Object?>? onResult;
  final bool enableTimer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('open-resumed-quiz'),
          onPressed: () async {
            final result = await Navigator.of(context).push<Object?>(
              MaterialPageRoute<Object?>(
                builder: (_) => QuizScreen(
                  repository: repository,
                  room: _room,
                  questions: _questions,
                  is1v1: true,
                  enableTimer: enableTimer,
                  resumeSnapshot: repository.snapshot,
                ),
              ),
            );
            onResult?.call(result);
          },
          child: const Text('Maçı aç'),
        ),
      ),
    );
  }
}

class _NestedQuizLauncher extends StatelessWidget {
  const _NestedQuizLauncher({required this.repository});

  final _SessionRepository repository;

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
                    key: const ValueKey('open-nested-quiz'),
                    onPressed: () => Navigator.of(roomContext).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => QuizScreen(
                          repository: repository,
                          room: _room,
                          questions: _questions,
                          is1v1: true,
                          enableTimer: false,
                          resumeSnapshot: repository.snapshot,
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

Future<void> _pumpFrames(WidgetTester tester, [int count = 3]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _openQuiz(
  WidgetTester tester,
  _SessionRepository repository, {
  ValueChanged<Object?>? onResult,
  bool enableTimer = true,
}) async {
  await tester.pumpWidget(
    testShell(
      child: _QuizLauncher(
        repository: repository,
        onResult: onResult,
        enableTimer: enableTimer,
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-resumed-quiz')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await _pumpFrames(tester);
  expect(find.byType(QuizScreen), findsOneWidget);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets(
    'aktif oda index skor seri ve ilk kalan süreyle doğrudan devam eder',
    (tester) async {
      final repository = _SessionRepository(
        _snapshot(answers: const [_firstAnswer]),
      );
      addTearDown(repository.close);

      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: _room,
            questions: _questions,
            is1v1: true,
            resumeSnapshot: repository.snapshot,
          ),
        ),
      );
      await _pumpFrames(tester);

      expect(find.text('Pirs 2'), findsOneWidget);
      expect(find.text('Pirs 1'), findsNothing);
      expect(find.text('420 pts'), findsOneWidget);
      expect(find.text('x3'), findsOneWidget);
      expect(find.text('Rakip bekleniyor...'), findsNothing);

      final timer = tester.widget<QuizTimerWidget>(
        find.byKey(const ValueKey('quiz-circular-timer')),
      );
      expect(timer.animation.value, closeTo(0.4, 0.04));
      expect(timer.animation.isAnimating, isTrue);
    },
  );

  testWidgets('cevaplanmış güncel soru seçim ve doğru cevabı geri getirir', (
    tester,
  ) async {
    final repository = _SessionRepository(
      _snapshot(wrong: 2, answers: const [_firstAnswer, _secondAnswer]),
    );
    addTearDown(repository.close);

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: _room,
          questions: _questions,
          is1v1: true,
          resumeSnapshot: repository.snapshot,
        ),
      ),
    );
    await _pumpFrames(tester);

    final options = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(options.singleWhere((tile) => tile.answer == 'B2').selected, isTrue);
    expect(options.singleWhere((tile) => tile.answer == 'B2').disabled, isTrue);
    expect(options.singleWhere((tile) => tile.answer == 'A2').correct, isTrue);

    final timer = tester.widget<QuizTimerWidget>(
      find.byKey(const ValueKey('quiz-circular-timer')),
    );
    expect(timer.animation.isAnimating, isFalse);
    expect(find.text('Rakip bekleniyor...'), findsNothing);
  });

  testWidgets('resume TIMEOUT kaydını cevaplanmış olarak ve doğruyla korur', (
    tester,
  ) async {
    final repository = _SessionRepository(
      _snapshot(wrong: 1, answers: const [_firstAnswer, _timeoutAnswer]),
    );
    addTearDown(repository.close);

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: _room,
          questions: _questions,
          is1v1: true,
          resumeSnapshot: repository.snapshot,
        ),
      ),
    );
    await _pumpFrames(tester);

    expect(find.byKey(const ValueKey('quiz-timeout-notice')), findsOneWidget);
    final correct = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .singleWhere((tile) => tile.answer == 'A2');
    expect(correct.correct, isTrue);
    final timer = tester.widget<QuizTimerWidget>(
      find.byKey(const ValueKey('quiz-circular-timer')),
    );
    expect(timer.animation.isAnimating, isFalse);
  });

  testWidgets('eşleşmeyen dolu soru kimliği index üzerinden cevap sızdırmaz', (
    tester,
  ) async {
    const mismatched = ResumedAnswer(
      questionId: 'foreign-question',
      questionIndex: 1,
      selectedOptionKey: 'B',
      correctOptionKey: 'A',
      isCorrect: false,
      pointsAwarded: 0,
      responseMs: 2000,
    );
    final repository = _SessionRepository(
      _snapshot(answers: const [_firstAnswer, mismatched]),
    );
    addTearDown(repository.close);

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: _room,
          questions: _questions,
          is1v1: true,
          resumeSnapshot: repository.snapshot,
        ),
      ),
    );
    await _pumpFrames(tester);

    final options = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(options.any((tile) => tile.selected), isFalse);
    expect(options.any((tile) => tile.correct), isFalse);
    final timer = tester.widget<QuizTimerWidget>(
      find.byKey(const ValueKey('quiz-circular-timer')),
    );
    expect(timer.animation.isAnimating, isTrue);
  });

  testWidgets('kalan süre sıfırsa server timeout CAS akışına girer', (
    tester,
  ) async {
    final repository = _SessionRepository(
      _snapshot(questionIndex: 0, remainingMs: 0),
    );
    addTearDown(repository.close);

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: _room,
          questions: _questions,
          is1v1: true,
          resumeSnapshot: repository.snapshot,
        ),
      ),
    );
    await _pumpFrames(tester, 5);

    expect(repository.submitCalls, 0);
    expect(repository.advanceCalls, greaterThan(0));
    expect(repository.advanceCalls, lessThanOrEqualTo(6));
    expect(find.byKey(const ValueKey('quiz-timeout-notice')), findsNothing);
  });

  testWidgets('sıfırıncı soruda online geri çıkış sunucu onayı ister', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..failLeave = true;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Yarıştan çıkılsın mı?'), findsOneWidget);
    expect(
      find.text('Maçtan ayrılırsan hükmen yenilmiş sayılırsın.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Çık'));
    await _pumpFrames(tester, 8);

    expect(repository.leaveCalls, 1);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(
      find.text('Odadan ayrılamadın. Lütfen tekrar dene.'),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('Çık'));
    await _pumpFrames(tester, 8);

    expect(repository.leaveCalls, 2);
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsOneWidget);
  });

  testWidgets('bekleyen online çıkış çift geri çağrısında tek RPC çalıştırır', (
    tester,
  ) async {
    final pending = Completer<void>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..pendingLeave = pending;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('Çık'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(repository.leaveCalls, 1);
    expect(find.byType(QuizScreen), findsOneWidget);

    pending.complete();
    await _pumpFrames(tester, 8);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets(
    'arka plan hükmen çıkış yapmaz ve resumed sunucu snapshotına uzlaşır',
    (tester) async {
      final repository = _SessionRepository(
        _snapshot(questionIndex: 0, score: 10, streak: 0, remainingMs: 25000),
      );
      addTearDown(repository.close);
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: _room,
            questions: _questions,
            is1v1: true,
            resumeSnapshot: repository.snapshot,
          ),
        ),
      );
      await _pumpFrames(tester);
      final callsBeforeResume = repository.resumeCalls;

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(repository.leaveCalls, 0);

      repository.snapshot = _snapshot(
        questionIndex: 2,
        score: 760,
        streak: 4,
        bestStreak: 6,
        correct: 2,
        remainingMs: 9000,
        answers: const [_firstAnswer, _secondAnswer],
      );
      repository.serverPlayers = const [
        Player(id: 'me', name: 'Ez', score: 760, state: Player.readyState),
        Player(
          id: 'opponent',
          name: 'Rakip',
          score: 500,
          state: Player.readyState,
        ),
      ];
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await _pumpFrames(tester, 5);

      expect(repository.leaveCalls, 0);
      expect(repository.resumeCalls, greaterThan(callsBeforeResume));
      expect(find.text('Pirs 3'), findsOneWidget);
      expect(find.text('760 pts'), findsOneWidget);
      expect(find.text('x4'), findsOneWidget);
      final timer = tester.widget<QuizTimerWidget>(
        find.byKey(const ValueKey('quiz-circular-timer')),
      );
      expect(timer.animation.value, lessThanOrEqualTo(0.31));
    },
  );

  testWidgets('rakibin hükmen çıkışı tek terminal gösterir ve ödül yazmaz', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'forfeit',
      forfeitedBy: 'opponent',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 5);

    expect(find.text('Maç hükmen sona erdi'), findsOneWidget);
    expect(
      find.text('Rakibin maçtan ayrıldı. Maçı hükmen kazandın.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.finishCalls, 0);
    expect(repository.awardCalls, 0);

    await tester.tap(find.text('Tamam'));
    await _pumpFrames(tester, 8);
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsOneWidget);
  });

  testWidgets('kendi hükmen çıkışını rakip terk etmiş gibi göstermez', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'forfeit',
      forfeitedBy: 'me',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 5);

    expect(find.text('Maçtan ayrıldın. Maç hükmen sona erdi.'), findsOneWidget);
    expect(
      find.text('Rakibin maçtan ayrıldı. Maçı hükmen kazandın.'),
      findsNothing,
    );
    expect(repository.finishCalls, 0);
    expect(repository.awardCalls, 0);
  });

  testWidgets('hükmen sonuç dialogunda hesap değişirse rota silinmez', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'forfeit',
      forfeitedBy: 'opponent',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 5);
    expect(find.text('Maç hükmen sona erdi'), findsOneWidget);

    repository.userId = 'other';
    await tester.tap(find.text('Tamam'));
    await _pumpFrames(tester, 6);

    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsNothing);
  });

  testWidgets('repository tabanlı periyodik poll hükmen bitişi yakalar', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);
    final pollsBefore = repository.endStateCalls;

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'host_left',
      forfeitedBy: 'opponent',
    );
    await tester.pump(const Duration(seconds: 4));
    await _pumpFrames(tester, 4);

    expect(repository.endStateCalls, greaterThan(pollsBefore));
    expect(find.text('Maç hükmen sona erdi'), findsOneWidget);
  });

  testWidgets('completed sunucu bitişi normal sonuç ve geçmiş kayıtları açar', (
    tester,
  ) async {
    final repository = _SessionRepository(
      _snapshot(
        score: 910,
        streak: 0,
        bestStreak: 7,
        correct: 0,
        wrong: 2,
        answers: const [_firstAnswer, _secondAnswer],
      ),
    );
    addTearDown(repository.close);
    Object? routeResult;
    await _openQuiz(
      tester,
      repository,
      onResult: (value) => routeResult = value,
    );

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 8);

    expect(find.byType(QuizResultScreen), findsOneWidget);
    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.score, 777);
    expect(result.answerRecords.map((record) => record.id), [
      'resume-q-1',
      'resume-q-2',
      'resume-q-3',
    ]);
    expect(result.answerRecords.first.correctAnswer, 'A1');
    expect(result.answerRecords.first.selectedAnswer, 'A1');
    expect(
      result.room.players.singleWhere((player) => player.id == 'me').score,
      777,
    );
    expect(result.resultOwnerUserId, 'me');
    expect(repository.resultCalls, 1);
    expect(repository.finishCalls, 0);
    expect(repository.awardCalls, 1);
    expect(repository.lastAwardArguments, [777, 2, 1, 3, 'resume-room']);
    expect(routeResult, {
      'completed': true,
      'score': 777,
      'correct': 2,
      'opponentScore': 880,
    });
  });

  testWidgets('exact sonuç error ve null sonrası yalnız Retry ile iyileşir', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    repository.resultResponses.addAll([
      StateError('offline'),
      null,
      _resultSnapshot(),
    ]);
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 8);

    expect(
      find.text('Sonuç yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.resultCalls, 1);
    expect(repository.awardCalls, 0);

    await tester.tap(find.text('Tekrar dene'));
    await _pumpFrames(tester, 5);
    expect(
      find.text('Sonuç yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(repository.resultCalls, 2);
    expect(repository.finishCalls, 0);

    await tester.tap(find.text('Tekrar dene'));
    await _pumpFrames(tester, 10);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(repository.resultCalls, 3);
    expect(repository.awardCalls, 1);
    expect(repository.finishCalls, 0);
  });

  testWidgets('exact sonuç failure gate ana sayfaya güvenli çıkış verir', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..exactResult = null;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 8);

    expect(find.text('Ana Sayfa'), findsOneWidget);
    await tester.tap(find.text('Ana Sayfa'));
    await _pumpFrames(tester, 5);

    expect(find.byType(QuizScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsOneWidget);
    expect(repository.awardCalls, 0);
  });

  testWidgets('exact null sonrası authoritative forfeit sonucu işlenir', (
    tester,
  ) async {
    final resultGate = Completer<RoomResultSnapshot?>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..resultGate = resultGate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 5);
    expect(repository.resultCalls, 1);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'forfeit',
      forfeitedBy: 'opponent',
    );
    resultGate.complete(null);
    await _pumpFrames(tester, 8);

    expect(
      find.text('Rakibin maçtan ayrıldı. Maçı hükmen kazandın.'),
      findsOneWidget,
    );
    expect(
      find.text('Sonuç yüklenemedi. Tekrar deneyebilirsin.'),
      findsNothing,
    );
    expect(repository.awardCalls, 0);

    repository.userId = 'other';
    await tester.tap(find.text('Tamam'));
    await _pumpFrames(tester, 5);

    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);

    repository.userId = 'me';
    await tester.tap(find.text('Tekrar dene'));
    await _pumpFrames(tester, 8);
    expect(
      find.text('Rakibin maçtan ayrıldı. Maçı hükmen kazandın.'),
      findsOneWidget,
    );
  });

  testWidgets('exact sonuç isteği takılırsa sınırlı sürede Retry açılır', (
    tester,
  ) async {
    final gate = Completer<RoomResultSnapshot?>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..resultGate = gate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 4);
    expect(find.text('Yarış sonucu hazırlanıyor…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 16));
    await _pumpFrames(tester, 3);

    expect(
      find.text('Sonuç yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(repository.resultCalls, 1);
    expect(repository.awardCalls, 0);
  });

  testWidgets('duplicate terminal sinyalleri tek exact load ve rota üretir', (
    tester,
  ) async {
    final gate = Completer<RoomResultSnapshot?>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..resultGate = gate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 6);

    expect(repository.resultCalls, 1);
    expect(find.text('Yarış sonucu hazırlanıyor…'), findsOneWidget);

    gate.complete(_resultSnapshot());
    await _pumpFrames(tester, 10);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
    expect(repository.resultCalls, 1);
    expect(repository.awardCalls, 1);
  });

  testWidgets('exact load sırasında hesap değişirse sonuç ve ödül açılmaz', (
    tester,
  ) async {
    final gate = Completer<RoomResultSnapshot?>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..resultGate = gate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 4);
    repository.userId = 'other';
    gate.complete(_resultSnapshot());
    await _pumpFrames(tester, 6);

    expect(find.byType(QuizResultScreen), findsNothing);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
    expect(repository.awardCalls, 0);
    expect(repository.ackCalls, 0);

    expect(find.text('Ana Sayfa'), findsOneWidget);
    await tester.tap(find.text('Ana Sayfa'));
    await _pumpFrames(tester, 6);
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsOneWidget);
  });

  testWidgets('owner gate eski exact isteğini orphan etmeden Retry açar', (
    tester,
  ) async {
    final staleGate = Completer<RoomResultSnapshot?>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..resultGate = staleGate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 4);
    expect(repository.resultCalls, 1);

    repository.userId = 'other';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 4);
    expect(find.text('Ana Sayfa'), findsOneWidget);

    repository
      ..userId = 'me'
      ..resultGate = null;
    await tester.tap(find.text('Tekrar dene'));
    await _pumpFrames(tester, 10);

    expect(repository.resultCalls, 2);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    staleGate.complete(_resultSnapshot());
    await _pumpFrames(tester, 2);
    expect(repository.awardCalls, 1);
  });

  testWidgets('terminalden önce hesap değişimi yeni owner sonucunu açmaz', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository
      ..userId = 'opponent'
      ..exactResult = _resultSnapshot(ownPlayerId: 'opponent')
      ..endState = const RoomEndState(
        status: RoomStatus.finished,
        endedReason: 'completed',
        forfeitedBy: null,
      );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 8);

    expect(find.byType(QuizResultScreen), findsNothing);
    expect(find.byType(RoomResultRecoveryScreen), findsNothing);
    expect(repository.resultCalls, 0);
    expect(repository.awardCalls, 0);
    expect(repository.ackCalls, 0);

    expect(find.text('Ana Sayfa'), findsOneWidget);
    await tester.tap(find.text('Ana Sayfa'));
    await _pumpFrames(tester, 6);
    expect(find.byType(QuizScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsOneWidget);
  });

  testWidgets('owner gate sistem geri tuşunda stale oda rotasını da temizler', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await tester.pumpWidget(
      testShell(child: _NestedQuizLauncher(repository: repository)),
    );
    await tester.tap(find.byKey(const ValueKey('open-stale-room')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-nested-quiz')));
    await tester.pump();
    await _pumpFrames(tester, 4);

    repository.userId = 'other';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 6);
    expect(find.text('Ana Sayfa'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _pumpFrames(tester, 6);

    expect(find.byKey(const ValueKey('open-stale-room')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-nested-quiz')), findsNothing);
    expect(find.byType(QuizScreen), findsNothing);
  });

  testWidgets('reconcile beklerken hesap değişirse eski snapshot uygulanmaz', (
    tester,
  ) async {
    final gate = Completer<RoomEndState>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..endStateGate = gate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);
    expect(repository.endStateCalls, 1);

    repository.userId = 'other';
    gate.complete(
      const RoomEndState(
        status: RoomStatus.active,
        endedReason: null,
        forfeitedBy: null,
      ),
    );
    await _pumpFrames(tester, 6);

    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.resultCalls, 0);
  });

  testWidgets('exact load sırasında üst rota açılırsa onu değiştirmez', (
    tester,
  ) async {
    final gate = Completer<RoomResultSnapshot?>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..resultGate = gate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 4);

    final quizContext = tester.element(find.byType(QuizScreen));
    unawaited(
      Navigator.of(quizContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Üst rota')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    gate.complete(_resultSnapshot());
    await _pumpFrames(tester, 6);

    expect(find.text('Üst rota'), findsOneWidget);
    expect(find.byType(QuizResultScreen), findsNothing);
    expect(repository.awardCalls, 0);

    Navigator.of(tester.element(find.text('Üst rota'))).pop();
    await tester.pumpAndSettle();
    expect(
      find.text('Sonuç yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );

    repository.resultGate = null;
    await tester.tap(find.text('Tekrar dene'));
    await _pumpFrames(tester, 10);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(repository.resultCalls, 2);
  });

  testWidgets('exit completed outcome home yerine exact sonucu açar', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..leaveOutcome = const RoomLeaveOutcome(
        status: 'finished',
        reason: 'completed',
        forfeitedBy: null,
      );
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('Çık'));
    await _pumpFrames(tester, 10);

    expect(repository.leaveCalls, 1);
    expect(repository.resultCalls, 1);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsNothing);
  });

  testWidgets('exit dialogunda hesap değişirse leave RPC çalışmaz', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    repository.userId = 'other';
    await tester.tap(find.text('Çık'));
    await _pumpFrames(tester, 6);

    expect(repository.leaveCalls, 0);
    expect(find.byType(QuizScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsNothing);
  });

  testWidgets('leave beklerken açılan üst rota dönüşte korunur', (
    tester,
  ) async {
    final leaveGate = Completer<void>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..pendingLeave = leaveGate;
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('Çık'));
    await tester.pump();
    expect(repository.leaveCalls, 1);

    final quizContext = tester.element(find.byType(QuizScreen));
    unawaited(
      Navigator.of(quizContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Leave üst rotası')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'forfeit',
      forfeitedBy: 'opponent',
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 3);

    leaveGate.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await _pumpFrames(tester, 4);

    expect(find.text('Leave üst rotası'), findsOneWidget);
    expect(find.byKey(const ValueKey('open-resumed-quiz')), findsNothing);
    expect(find.byType(QuizResultScreen), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    await _pumpFrames(tester, 4);
    expect(find.text('Leave üst rotası'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('leave hatasında hesap değişmişse deferred forfeit gösterilmez', (
    tester,
  ) async {
    final leaveGate = Completer<void>();
    final repository = _SessionRepository(_snapshot(questionIndex: 0))
      ..pendingLeave = leaveGate
      ..leaveErrorAfterGate = StateError('offline');
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.tap(find.text('Çık'));
    await tester.pump();
    expect(repository.leaveCalls, 1);

    repository
      ..userId = 'other'
      ..endState = const RoomEndState(
        status: RoomStatus.finished,
        endedReason: 'forfeit',
        forfeitedBy: 'opponent',
      );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 3);

    leaveGate.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await _pumpFrames(tester, 6);

    expect(find.text('Maç hükmen sona erdi'), findsNothing);
    expect(find.text('Maçtan ayrıldın. Maç hükmen sona erdi.'), findsNothing);
    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets(
    'completed leave animasyon sonrası exact action için frame ister',
    (tester) async {
      final leaveGate = Completer<void>();
      final repository = _SessionRepository(_snapshot(questionIndex: 0))
        ..pendingLeave = leaveGate
        ..leaveOutcome = const RoomLeaveOutcome(
          status: 'finished',
          reason: 'completed',
          forfeitedBy: null,
        );
      addTearDown(repository.close);
      await _openQuiz(tester, repository, enableTimer: false);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('Çık'));
      await tester.pumpAndSettle();
      expect(repository.leaveCalls, 1);
      expect(repository.resultCalls, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);

      leaveGate.complete();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expect(repository.resultCalls, 1);
      expect(find.byType(QuizResultScreen), findsOneWidget);
    },
  );

  testWidgets('exit dialogunda terminal sinyal Continue sonrası işlenir', (
    tester,
  ) async {
    final repository = _SessionRepository(_snapshot(questionIndex: 0));
    addTearDown(repository.close);
    await _openQuiz(tester, repository);

    await tester.binding.handlePopRoute();
    await tester.pump();
    repository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpFrames(tester, 5);
    expect(find.text('Yarıştan çıkılsın mı?'), findsOneWidget);

    await tester.tap(find.text('Devam Et'));
    await _pumpFrames(tester, 10);

    expect(repository.leaveCalls, 0);
    expect(repository.resultCalls, 1);
    expect(find.byType(QuizResultScreen), findsOneWidget);
  });
}

RoomResultSnapshot _resultSnapshot({String ownPlayerId = 'me'}) {
  return RoomResultSnapshot(
    room: _room.copyWith(
      players: const [
        Player(
          id: 'me',
          name: 'Ez',
          score: 777,
          streak: 1,
          state: Player.readyState,
        ),
        Player(
          id: 'opponent',
          name: 'Rakip',
          score: 880,
          streak: 0,
          state: Player.readyState,
        ),
      ],
      status: RoomStatus.finished,
    ),
    ownPlayerId: ownPlayerId,
    questionIds: const ['resume-q-1', 'resume-q-2', 'resume-q-3'],
    answers: const [
      ResumedAnswer(
        questionId: 'resume-q-1',
        questionIndex: 0,
        selectedOptionKey: 'A',
        correctOptionKey: 'A',
        isCorrect: true,
        pointsAwarded: 300,
        responseMs: 900,
      ),
      ResumedAnswer(
        questionId: 'resume-q-2',
        questionIndex: 1,
        selectedOptionKey: 'B',
        correctOptionKey: 'A',
        isCorrect: false,
        pointsAwarded: 0,
        responseMs: 1200,
      ),
      ResumedAnswer(
        questionId: 'resume-q-3',
        questionIndex: 2,
        selectedOptionKey: 'A',
        correctOptionKey: 'A',
        isCorrect: true,
        pointsAwarded: 477,
        responseMs: 800,
      ),
    ],
    winnerId: 'opponent',
    endedReason: 'completed',
    forfeitedBy: null,
    finishedAt: DateTime.utc(2026, 8, 2),
  );
}
