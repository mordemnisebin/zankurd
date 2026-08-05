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

import 'support/widget_test_helpers.dart';

const _questions = <QuizQuestion>[
  QuizQuestion(
    id: 'server-q-1',
    category: 'Ziman',
    prompt: 'Server pirs 1',
    answers: ['A1', 'B1', 'C1', 'D1'],
    correctAnswer: '',
    explanation: '',
  ),
  QuizQuestion(
    id: 'server-q-2',
    category: 'Ziman',
    prompt: 'Server pirs 2',
    answers: ['A2', 'B2', 'C2', 'D2'],
    correctAnswer: '',
    explanation: '',
  ),
];

const _resultQuestions = <QuizQuestion>[
  QuizQuestion(
    id: 'server-q-1',
    category: 'Ziman',
    prompt: 'Server pirs 1',
    answers: ['A1', 'B1', 'C1', 'D1'],
    correctAnswer: 'A1',
    explanation: 'A1 rast e.',
  ),
  QuizQuestion(
    id: 'server-q-2',
    category: 'Ziman',
    prompt: 'Server pirs 2',
    answers: ['A2', 'B2', 'C2', 'D2'],
    correctAnswer: 'A2',
    explanation: 'A2 rast e.',
  ),
];

const _room = GameRoom(
  id: 'server-room',
  name: '1v1',
  code: 'ZK-SRVR',
  category: 'Ziman',
  players: [
    Player(id: 'me', name: 'Ez', score: 0, state: Player.readyState),
    Player(id: 'opponent', name: 'Rakip', score: 0, state: Player.readyState),
  ],
  status: RoomStatus.active,
  questionCount: 2,
  secondsPerQuestion: 30,
  hostId: 'opponent',
);

const _answeredCurrent = ResumedAnswer(
  questionId: 'server-q-1',
  questionIndex: 0,
  selectedOptionKey: 'B',
  correctOptionKey: 'A',
  isCorrect: false,
  pointsAwarded: 0,
  responseMs: 1200,
);

const _pendingCurrent = ResumedPendingAnswer(
  questionId: 'server-q-1',
  questionIndex: 0,
  selectedOptionKey: 'B',
  responseMs: 1200,
);

RoomResumeSnapshot _snapshot({
  int index = 0,
  int remainingMs = 15000,
  bool timing = true,
  List<ResumedAnswer> answers = const [],
  ResumedPendingAnswer? pendingAnswer,
}) {
  final now = DateTime.utc(2026, 8, 2, 12);
  return RoomResumeSnapshot(
    room: _room,
    currentQuestionIndex: index,
    ownScore: answers.isEmpty ? 0 : 110,
    streak: 0,
    bestStreak: 1,
    correctCount: 0,
    wrongCount: answers.length,
    answers: answers,
    pendingAnswer: pendingAnswer,
    serverNow: now,
    questionStartedAt: timing ? now : null,
    deadline: timing ? now.add(Duration(milliseconds: remainingMs)) : null,
    remainingMs: remainingMs,
  );
}

typedef _AdvanceHandler = Future<RoomResumeSnapshot?> Function(int expected);
typedef _MarkHandler = Future<RoomResumeSnapshot?> Function(int call);

class _ServerSessionRepository extends MockZanKurdRepository {
  _ServerSessionRepository({required this.snapshot});

  final StreamController<Map<String, dynamic>> broadcasts =
      StreamController<Map<String, dynamic>>.broadcast();
  RoomResumeSnapshot? snapshot;
  RoomResumeSnapshot? markResult;
  RoomEndState endState = const RoomEndState(
    status: RoomStatus.active,
    endedReason: null,
    forfeitedBy: null,
  );
  _MarkHandler? markHandler;
  _AdvanceHandler? advanceHandler;
  int markCalls = 0;
  int resumeCalls = 0;
  int advanceCalls = 0;
  int submitCalls = 0;
  int finishCalls = 0;
  int awardCalls = 0;
  int resultCalls = 0;
  int ackCalls = 0;
  Map<String, dynamic>? submitResult;
  final List<int> expectedIndexes = [];
  final List<Map<String, dynamic>> sentBroadcasts = [];

  @override
  String? get currentUserId => 'me';

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
  ) async {
    sentBroadcasts.add(payload);
  }

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    resumeCalls++;
    return snapshot;
  }

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async {
    markCalls++;
    final handler = markHandler;
    if (handler != null) return handler(markCalls);
    return markResult ?? snapshot;
  }

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async {
    advanceCalls++;
    expectedIndexes.add(expectedQuestionIndex);
    final handler = advanceHandler;
    return handler == null ? snapshot : handler(expectedQuestionIndex);
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => room.players;

  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async => endState;

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    submitCalls++;
    return submitResult ??
        {
          'is_correct': false,
          'points': 0,
          'new_score': 0,
          'new_streak': 0,
          // Yalnız mevcut istemci sözleşmesini taklit eder; testler reveal
          // zamanını veya bu alanların varlığını davranış olarak sabitlemez.
          'correct_option': 'A',
        };
  }

  @override
  Future<void> finishGame(GameRoom room) async {
    finishCalls++;
  }

  @override
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room) async {
    resultCalls++;
    return _serverResultSnapshot();
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    return _resultQuestions;
  }

  @override
  Future<void> acknowledgeRoomResult(GameRoom room) async {
    ackCalls++;
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
    return 0;
  }

  void emitOpponentAnswered({int questionIndex = 0}) {
    broadcasts.add({
      'sender': 'Rakip',
      'sender_id': 'opponent',
      'question_index': questionIndex,
      'answered': true,
      'score': 0,
      'streak': 0,
    });
  }

  void emitOpponentIndex(int questionIndex) {
    broadcasts.add({
      'sender': 'Rakip',
      'sender_id': 'opponent',
      'question_index': questionIndex,
      'answered': false,
      'score': 0,
      'streak': 0,
    });
  }

  Future<void> close() => broadcasts.close();
}

Future<void> _pumpFrames(WidgetTester tester, [int count = 4]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }
}

Future<void> _mount(
  WidgetTester tester,
  _ServerSessionRepository repository, {
  RoomResumeSnapshot? resumeSnapshot,
}) async {
  await tester.pumpWidget(
    testShell(
      child: QuizScreen(
        repository: repository,
        room: _room,
        questions: _questions,
        is1v1: true,
        resumeSnapshot: resumeSnapshot,
      ),
    ),
  );
  await _pumpFrames(tester);
}

QuizTimerWidget _timer(WidgetTester tester) => tester.widget<QuizTimerWidget>(
  find.byKey(const ValueKey('quiz-circular-timer')),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets('fresh server oda iki client-ready olmadan süreyi başlatmaz', (
    tester,
  ) async {
    final waiting = _snapshot(timing: false, remainingMs: 0);
    final repository = _ServerSessionRepository(snapshot: waiting)
      ..markResult = waiting;
    addTearDown(repository.close);

    await _mount(tester, repository);

    expect(repository.markCalls, 1);
    expect(find.text('Rakip bekleniyor...'), findsOneWidget);
    expect(_timer(tester).animation.isAnimating, isFalse);
    expect(repository.submitCalls, 0);
    expect(
      repository.sentBroadcasts.any((payload) => payload['ready'] == true),
      isFalse,
    );

    repository.snapshot = _snapshot(remainingMs: 12000);
    await tester.pump(const Duration(milliseconds: 700));
    await _pumpFrames(tester);

    expect(find.text('Rakip bekleniyor...'), findsNothing);
    expect(_timer(tester).animation.isAnimating, isTrue);
    expect(_timer(tester).animation.value, closeTo(0.4, 0.05));
  });

  testWidgets('resume deadline null ise TIMEOUT üretmeden ready bekler', (
    tester,
  ) async {
    final waiting = _snapshot(timing: false, remainingMs: 0);
    final repository = _ServerSessionRepository(snapshot: waiting);
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: waiting);
    await tester.pump(const Duration(seconds: 2));
    await _pumpFrames(tester);

    expect(repository.submitCalls, 0);
    expect(_timer(tester).animation.isAnimating, isFalse);
    expect(find.text('Rakip bekleniyor...'), findsOneWidget);
    expect(repository.markCalls, greaterThanOrEqualTo(1));
  });

  testWidgets('ready kısa retry bütçesi sonrası kontrollü yeniden dener', (
    tester,
  ) async {
    final waiting = _snapshot(timing: false, remainingMs: 0);
    final started = _snapshot(remainingMs: 12000);
    final repository = _ServerSessionRepository(snapshot: waiting)
      ..markHandler = (call) async {
        if (call <= 7) throw StateError('ready unavailable');
        return started;
      };
    addTearDown(repository.close);

    await _mount(tester, repository);
    for (var i = 0; i < 10 && repository.markCalls < 7; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }

    expect(repository.markCalls, 7);
    expect(_timer(tester).animation.isAnimating, isFalse);

    await tester.pump(const Duration(milliseconds: 4200));
    await _pumpFrames(tester);

    expect(repository.markCalls, 8);
    expect(_timer(tester).animation.isAnimating, isTrue);
  });

  testWidgets('başlamış server turu tam authoritative remaining ile açılır', (
    tester,
  ) async {
    final started = _snapshot(remainingMs: 9000);
    final repository = _ServerSessionRepository(snapshot: started);
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: started);

    expect(find.text('Rakip bekleniyor...'), findsNothing);
    expect(_timer(tester).animation.isAnimating, isTrue);
    expect(_timer(tester).animation.value, closeTo(0.3, 0.05));
  });

  testWidgets('pending submit seçimi kilitler ve şıkkı rakibe yayınlamaz', (
    tester,
  ) async {
    final started = _snapshot(remainingMs: 20000);
    final repository = _ServerSessionRepository(snapshot: started)
      ..submitResult = {'accepted': true, 'pending': true};
    addTearDown(repository.close);
    await _mount(tester, repository, resumeSnapshot: started);

    await tester.tap(find.text('B1').first);
    await _pumpFrames(tester);

    final options = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(options.singleWhere((tile) => tile.answer == 'B1').selected, isTrue);
    expect(options.singleWhere((tile) => tile.answer == 'B1').disabled, isTrue);
    expect(options.any((tile) => tile.correct), isFalse);
    expect(find.text('Rakip bekleniyor...'), findsNothing);
    expect(
      repository.sentBroadcasts.any(
        (payload) => payload.containsKey('selected_answer'),
      ),
      isFalse,
    );
  });

  testWidgets('resume pending cevap seçili ve kilitli geri yüklenir', (
    tester,
  ) async {
    final pending = _snapshot(
      remainingMs: 12000,
      pendingAnswer: const ResumedPendingAnswer(
        questionId: 'server-q-1',
        questionIndex: 0,
        selectedOptionKey: 'B',
        responseMs: 900,
      ),
    );
    final repository = _ServerSessionRepository(snapshot: pending);
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: pending);

    final options = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(options.singleWhere((tile) => tile.answer == 'B1').selected, isTrue);
    expect(options.singleWhere((tile) => tile.answer == 'B1').disabled, isTrue);
    expect(options.any((tile) => tile.correct), isFalse);
    expect(repository.submitCalls, 0);
  });

  testWidgets('cold resume güvenli reveal için broadcast beklemez', (
    tester,
  ) async {
    final revealed = _snapshot(
      remainingMs: 12000,
      answers: const [_answeredCurrent],
    );
    final repository = _ServerSessionRepository(snapshot: revealed);
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: revealed);

    expect(find.textContaining('Sonraki soru'), findsOneWidget);
    expect(repository.advanceCalls, 0);
  });

  testWidgets('rakip answered sinyali güvenli resume revealini bekler', (
    tester,
  ) async {
    final started = _snapshot(remainingMs: 20000);
    final repository = _ServerSessionRepository(snapshot: started)
      ..submitResult = {'accepted': true, 'pending': true};
    addTearDown(repository.close);
    await _mount(tester, repository, resumeSnapshot: started);
    await tester.tap(find.text('B1').first);
    await _pumpFrames(tester);
    final beforeOpponent = repository.resumeCalls;

    repository.snapshot = _snapshot(
      remainingMs: 18000,
      answers: const [_answeredCurrent],
    );
    repository.emitOpponentAnswered();
    await _pumpFrames(tester, 6);

    expect(repository.resumeCalls, greaterThan(beforeOpponent));
    final options = tester
        .widgetList<QuizOptionTile>(find.byType(QuizOptionTile))
        .toList();
    expect(options.singleWhere((tile) => tile.answer == 'A1').correct, isTrue);
    expect(find.textContaining('Sonraki soru'), findsOneWidget);
  });

  testWidgets('host olmayan üye expected index ile CAS advance çağırır', (
    tester,
  ) async {
    final answered = _snapshot(
      remainingMs: 20000,
      answers: const [_answeredCurrent],
    );
    final next = _snapshot(index: 1, remainingMs: 15000);
    final repository = _ServerSessionRepository(snapshot: answered);
    repository.advanceHandler = (expected) async {
      repository.snapshot = next;
      return next;
    };
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: answered);
    repository.emitOpponentAnswered();
    await _pumpFrames(tester);
    expect(find.textContaining('Sonraki soru'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await _pumpFrames(tester);

    expect(repository.advanceCalls, 1);
    expect(repository.expectedIndexes, [0]);
    expect(find.text('Server pirs 2'), findsOneWidget);
    expect(
      repository.sentBroadcasts.any(
        (payload) => payload['advance_request'] == true,
      ),
      isFalse,
    );
  });

  testWidgets('aynı index için eşzamanlı CAS çağrısı çoğaltılmaz', (
    tester,
  ) async {
    final answered = _snapshot(
      remainingMs: 100,
      pendingAnswer: _pendingCurrent,
    );
    final next = _snapshot(index: 1, remainingMs: 15000);
    final pending = Completer<RoomResumeSnapshot?>();
    final repository = _ServerSessionRepository(snapshot: answered)
      ..advanceHandler = (_) => pending.future;
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: answered);
    await tester.pump(const Duration(milliseconds: 200));
    expect(repository.advanceCalls, 1);

    repository.emitOpponentAnswered();
    await tester.pump(const Duration(seconds: 6));
    expect(repository.advanceCalls, 1);

    repository.snapshot = next;
    pending.complete(next);
    await _pumpFrames(tester);
    expect(find.text('Server pirs 2'), findsOneWidget);
  });

  testWidgets('CAS hatası local next yapmaz ve bounded retry dener', (
    tester,
  ) async {
    final answered = _snapshot(
      remainingMs: 100,
      pendingAnswer: _pendingCurrent,
    );
    final repository = _ServerSessionRepository(snapshot: answered)
      ..advanceHandler = (_) async => throw StateError('early CAS');
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: answered);
    for (var i = 0; i < 10 && repository.advanceCalls < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    await _pumpFrames(tester);

    expect(repository.advanceCalls, greaterThan(1));
    expect(repository.advanceCalls, lessThanOrEqualTo(6));
    expect(find.text('Server pirs 1'), findsOneWidget);
    expect(find.text('Server pirs 2'), findsNothing);
  });

  testWidgets('CAS kısa retry bütçesi sonrası yavaş recovery ile açılır', (
    tester,
  ) async {
    final answered = _snapshot(
      remainingMs: 100,
      pendingAnswer: _pendingCurrent,
    );
    final next = _snapshot(index: 1, remainingMs: 15000);
    final repository = _ServerSessionRepository(snapshot: answered);
    repository.advanceHandler = (_) async {
      if (repository.advanceCalls <= 6) {
        throw StateError('temporary outage');
      }
      repository.snapshot = next;
      return next;
    };
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: answered);
    await tester.pump(const Duration(seconds: 2));

    expect(repository.advanceCalls, 6);
    expect(find.text('Server pirs 1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 4200));
    await _pumpFrames(tester);

    expect(repository.advanceCalls, 7);
    expect(find.text('Server pirs 2'), findsOneWidget);
  });

  testWidgets('server-hidden broadcast index tam süre değil resume çeker', (
    tester,
  ) async {
    final first = _snapshot(remainingMs: 20000);
    final repository = _ServerSessionRepository(snapshot: first);
    addTearDown(repository.close);
    await _mount(tester, repository, resumeSnapshot: first);
    final resumeCallsBefore = repository.resumeCalls;

    repository.snapshot = _snapshot(index: 1, remainingMs: 7500);
    repository.emitOpponentIndex(1);
    await _pumpFrames(tester, 6);

    expect(repository.resumeCalls, greaterThan(resumeCallsBefore));
    expect(find.text('Server pirs 2'), findsOneWidget);
    expect(_timer(tester).animation.value, closeTo(0.25, 0.05));
  });

  testWidgets('cevap sonrası rakip bekleme authoritative remaining kadardır', (
    tester,
  ) async {
    final answered = _snapshot(
      remainingMs: 2000,
      pendingAnswer: _pendingCurrent,
    );
    final next = _snapshot(index: 1, remainingMs: 15000);
    final repository = _ServerSessionRepository(snapshot: answered);
    repository.advanceHandler = (_) async {
      repository.snapshot = next;
      return next;
    };
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: answered);
    await tester.pump(const Duration(milliseconds: 500));
    expect(repository.advanceCalls, 0);

    await tester.pump(const Duration(milliseconds: 1600));
    await _pumpFrames(tester);
    expect(repository.advanceCalls, 1);
    expect(find.text('Server pirs 2'), findsOneWidget);
  });

  testWidgets('CAS null dönüşünde terminal end-state ile sonuçlanır', (
    tester,
  ) async {
    final answered = _snapshot(
      remainingMs: 20000,
      answers: const [_answeredCurrent],
    );
    final repository = _ServerSessionRepository(snapshot: answered);
    repository.advanceHandler = (_) async {
      repository.endState = const RoomEndState(
        status: RoomStatus.finished,
        endedReason: 'completed',
        forfeitedBy: null,
      );
      return null;
    };
    addTearDown(repository.close);

    await _mount(tester, repository, resumeSnapshot: answered);
    repository.emitOpponentAnswered();
    await _pumpFrames(tester);
    expect(find.textContaining('Sonraki soru'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await _pumpFrames(tester, 8);

    expect(repository.advanceCalls, 1);
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(repository.finishCalls, 0);
    expect(repository.resultCalls, 1);
    expect(repository.awardCalls, 1);
  });

  testWidgets('bilinmeyen terminal neden ödülsüz güvenli çıkış gösterir', (
    tester,
  ) async {
    final repository =
        _ServerSessionRepository(snapshot: _snapshot(remainingMs: 12000))
          ..endState = const RoomEndState(
            status: RoomStatus.finished,
            endedReason: 'stale_timeout',
            forfeitedBy: null,
          );
    addTearDown(repository.close);

    await _mount(tester, repository);

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(repository.finishCalls, 0);
    expect(repository.awardCalls, 0);
  });
}

RoomResultSnapshot _serverResultSnapshot() {
  return RoomResultSnapshot(
    room: _room.copyWith(
      players: const [
        Player(
          id: 'me',
          name: 'Ez',
          score: 40,
          streak: 1,
          state: Player.readyState,
        ),
        Player(
          id: 'opponent',
          name: 'Rakip',
          score: 20,
          state: Player.readyState,
        ),
      ],
      status: RoomStatus.finished,
    ),
    ownPlayerId: 'me',
    questionIds: const ['server-q-1', 'server-q-2'],
    answers: const [
      ResumedAnswer(
        questionId: 'server-q-1',
        questionIndex: 0,
        selectedOptionKey: 'B',
        correctOptionKey: 'A',
        isCorrect: false,
        pointsAwarded: 0,
        responseMs: 1200,
      ),
      ResumedAnswer(
        questionId: 'server-q-2',
        questionIndex: 1,
        selectedOptionKey: 'A',
        correctOptionKey: 'A',
        isCorrect: true,
        pointsAwarded: 40,
        responseMs: 900,
      ),
    ],
    winnerId: 'me',
    endedReason: 'completed',
    forfeitedBy: null,
    finishedAt: DateTime.utc(2026, 8, 2),
  );
}
