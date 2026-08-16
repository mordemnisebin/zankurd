import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'support/widget_test_helpers.dart';

class _RoomQuizBroadcastRepository extends MockZanKurdRepository {
  final broadcasts = <Map<String, dynamic>>[];
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get currentUserId => 'user';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return controller.stream;
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    broadcasts.add(payload);
    controller.add(payload);
  }
}

class _SameNameDuelRepository extends MockZanKurdRepository {
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <Map<String, dynamic>>[];
  QuizQuestion? terminalQuestion;
  GameRoom? terminalRoom;
  int finishCalls = 0;
  int resultCalls = 0;
  int awardCalls = 0;
  int? awardedScore;
  Completer<int>? awardGate;
  RoomEndState endState = const RoomEndState(
    status: RoomStatus.active,
    endedReason: null,
    forfeitedBy: null,
  );
  final List<Object?> finishResponses = [
    StateError('host finish response was lost'),
  ];
  Completer<void>? finishGate;
  Completer<RoomEndState>? endStateGate;
  Completer<List<Player>>? playersGate;
  int endStateCalls = 0;
  int playerLoadCalls = 0;
  final List<Object?> resultResponses = [];
  String userId = 'me-id';

  @override
  String? get currentUserId => userId;

  @override
  Future<String> getProfileName() async => 'Berfin';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      controller.stream;

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    sent.add(payload);
  }

  @override
  Future<void> finishGame(GameRoom room) async {
    finishCalls++;
    final gate = finishGate;
    if (gate != null) await gate.future;
    final response = finishResponses.isEmpty
        ? null
        : finishResponses.removeAt(0);
    if (response != null) throw response;
  }

  @override
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room) async {
    resultCalls++;
    if (resultResponses.isNotEmpty) {
      final response = resultResponses.removeAt(0);
      if (response == null) return null;
      if (response is RoomResultSnapshot) return response;
      throw response;
    }
    final question = terminalQuestion!;
    final exactRoom = terminalRoom!;
    final correctKey = question.optionKeyForAnswer(question.correctAnswer);
    return RoomResultSnapshot(
      room: exactRoom.copyWith(
        players: const [
          Player(
            id: 'me-id',
            name: 'Berfin',
            score: 123,
            streak: 1,
            state: Player.readyState,
          ),
          Player(
            id: 'opponent-id',
            name: 'Berfin',
            score: 700,
            state: Player.readyState,
          ),
        ],
        status: RoomStatus.finished,
      ),
      ownPlayerId: 'me-id',
      questionIds: [question.id],
      answers: [
        ResumedAnswer(
          questionId: question.id,
          questionIndex: 0,
          selectedOptionKey: correctKey,
          correctOptionKey: correctKey,
          isCorrect: true,
          pointsAwarded: 123,
          responseMs: 900,
        ),
      ],
      winnerId: 'opponent-id',
      endedReason: 'completed',
      forfeitedBy: null,
      finishedAt: DateTime.utc(2026, 8, 2),
    );
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    return [terminalQuestion!];
  }

  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async {
    endStateCalls++;
    final gate = endStateGate;
    if (gate != null) return gate.future;
    return endState;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    playerLoadCalls++;
    final gate = playersGate;
    if (gate != null) return gate.future;
    return terminalRoom?.players ?? room.players;
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
    awardedScore = score;
    final gate = awardGate;
    if (gate != null) {
      return (amount: await gate.future, dailyCapReached: false);
    }
    return (amount: 5, dailyCapReached: false);
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('quiz screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Arayüz Türkçe: soru ekranda `localized(isKu: false)` ile
    // yansıtılıyor. Kurmancî ham metni aramak, curated banka
    // çevrilene kadar tesadüfen çalışıyordu (2026-08-10).
    final shown = question.localized(isKu: false);
    expect(find.text(shown.prompt), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quiz-landscape-content')),
      findsOneWidget,
    );
    expect(find.text(shown.displayAnswers.first), findsWidgets);

    await tester.ensureVisible(find.text(shown.displayAnswers.first).first);
    await tester.tap(find.text(shown.displayAnswers.first).first);
    await tester.pumpAndSettle();

    // Yarışma modunda tur içi açıklama gösterilmez (çözümler oyun sonunda).
    expect(find.text('Doğru cevap'), findsNothing);
  });

  testWidgets('quiz question panel renders the polished visual accents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quiz-question-icon-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quiz-question-ghost-icon')),
      findsOneWidget,
    );
  });

  testWidgets('online room answer broadcasts readiness outside 1vs1', (
    tester,
  ) async {
    final roomRepository = _RoomQuizBroadcastRepository();
    addTearDown(roomRepository.controller.close);
    final questions = repository.questions.take(2).toList();
    const room = GameRoom(
      id: 'online-room',
      name: 'Oda',
      code: 'ZK-ROOM',
      category: 'Ziman',
      players: [
        Player(id: 'user', name: 'ZanKurd Oyuncusu', score: 0, state: 'Hazır'),
        Player(id: 'guest', name: 'Misafir', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 2,
      hostId: 'user',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: roomRepository,
          room: room,
          questions: questions,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(questions.first.displayAnswers.first).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      roomRepository.broadcasts.any(
        (payload) =>
            payload['question_index'] == 0 && payload['answered'] == true,
      ),
      isTrue,
    );
  });

  testWidgets(
    'aynı adlı farklı kimlikteki oyuncu sonuçta rakip olarak korunur',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      final duelRepository = _SameNameDuelRepository();
      addTearDown(duelRepository.controller.close);
      final question = repository.questions.first;
      final room = GameRoom(
        id: 'same-name-room',
        name: '1vs1',
        code: 'ZK-SAME',
        category: question.category,
        players: const [
          Player(id: 'opponent-id', name: 'Berfin', score: 700, state: 'Hazır'),
          Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        ],
        status: RoomStatus.active,
        questionCount: 1,
        hostId: 'me-id',
      );
      duelRepository
        ..terminalQuestion = question
        ..terminalRoom = room;

      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: duelRepository,
            room: room,
            questions: [question],
            enableTimer: false,
            is1v1: true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      duelRepository.controller.add({
        'sender': 'Berfin',
        'sender_id': 'opponent-id',
        'ready': true,
      });
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text(question.displayAnswers.first).first);
      await tester.pump(const Duration(milliseconds: 500));
      duelRepository.controller.add({
        'sender': 'Berfin',
        'sender_id': 'opponent-id',
        'score': 700,
        'streak': 2,
        'question_index': 0,
        'answered': true,
        'selected_answer': question.correctAnswer,
        'finished': true,
      });
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();

      expect(find.byType(QuizResultScreen), findsOneWidget);
      final result = tester.widget<QuizResultScreen>(
        find.byType(QuizResultScreen),
      );
      expect(result.opponents.map((player) => player.id), ['opponent-id']);
      expect(result.room.players.first.id, 'me-id');
      expect(result.score, 123);
      expect(duelRepository.finishCalls, 1);
      expect(duelRepository.resultCalls, 1);
      expect(duelRepository.awardCalls, 1);
      expect(duelRepository.awardedScore, 123);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('finish hata ve null sonuç sonrası Retry finish niyetini korur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final duelRepository = _SameNameDuelRepository()..resultResponses.add(null);
    addTearDown(duelRepository.controller.close);
    final question = repository.questions.first;
    final room = GameRoom(
      id: 'finish-retry-room',
      name: '1vs1',
      code: 'ZK-RETRY',
      category: question.category,
      players: const [
        Player(id: 'opponent-id', name: 'Berfin', score: 700, state: 'Hazır'),
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );
    duelRepository
      ..terminalQuestion = question
      ..terminalRoom = room;

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: duelRepository,
          room: room,
          questions: [question],
          enableTimer: false,
          is1v1: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    duelRepository.controller.add({
      'sender': 'Berfin',
      'sender_id': 'opponent-id',
      'ready': true,
    });
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(question.displayAnswers.first).first);
    await tester.pump(const Duration(milliseconds: 500));
    duelRepository.controller.add({
      'sender': 'Berfin',
      'sender_id': 'opponent-id',
      'score': 700,
      'streak': 2,
      'question_index': 0,
      'answered': true,
      'selected_answer': question.correctAnswer,
      'finished': true,
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(
      find.text('Sonuç yüklenemedi. Tekrar deneyebilirsin.'),
      findsOneWidget,
    );
    expect(duelRepository.finishCalls, 1);
    expect(duelRepository.resultCalls, 1);
    expect(duelRepository.awardCalls, 0);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(duelRepository.finishCalls, 2);
    expect(duelRepository.resultCalls, 2);
    expect(duelRepository.awardCalls, 1);
    expect(duelRepository.awardedScore, 123);
  });

  testWidgets('takılan finish isteği exact sonucu sonsuza dek kilitlemez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final finishGate = Completer<void>();
    final duelRepository = _SameNameDuelRepository()
      ..finishResponses.clear()
      ..finishGate = finishGate;
    addTearDown(duelRepository.controller.close);
    final question = repository.questions.first;
    final room = GameRoom(
      id: 'finish-timeout-room',
      name: '1vs1',
      code: 'ZK-TIMEOUT',
      category: question.category,
      players: const [
        Player(id: 'opponent-id', name: 'Berfin', score: 700, state: 'Hazır'),
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );
    duelRepository
      ..terminalQuestion = question
      ..terminalRoom = room;

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: duelRepository,
          room: room,
          questions: [question],
          enableTimer: false,
          is1v1: true,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    duelRepository.controller.add({
      'sender': 'Berfin',
      'sender_id': 'opponent-id',
      'ready': true,
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(question.displayAnswers.first).first);
    await tester.pump(const Duration(milliseconds: 500));
    duelRepository.controller.add({
      'sender': 'Berfin',
      'sender_id': 'opponent-id',
      'score': 700,
      'streak': 2,
      'question_index': 0,
      'answered': true,
      'selected_answer': question.correctAnswer,
      'finished': true,
    });
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();

    expect(duelRepository.finishCalls, 1);
    expect(find.text('Yarış sonucu hazırlanıyor…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(duelRepository.resultCalls, 1);
    expect(duelRepository.awardCalls, 1);
    finishGate.complete();
    await tester.pump();
  });

  testWidgets('aynı adlı farklı rakiplerin cevap işaretleri birbirini ezmez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final duelRepository = _SameNameDuelRepository();
    addTearDown(duelRepository.controller.close);
    const question = QuizQuestion(
      id: 'same-name-answers',
      category: 'Ziman',
      prompt: 'Kîjan bersiv rast e?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );
    const room = GameRoom(
      id: 'same-name-team-room',
      name: 'Oda',
      code: 'ZK-TEAM',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
        Player(id: 'opponent-2', name: 'Rojda', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: duelRepository,
          room: room,
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 100));

    duelRepository.controller.add({
      'sender': 'Rojda',
      'sender_id': 'opponent-1',
      'score': 0,
      'streak': 0,
      'question_index': 0,
      'answered': true,
      'selected_answer': 'B',
    });
    await tester.pump(const Duration(milliseconds: 100));
    duelRepository.controller.add({
      'sender': 'Rojda',
      'sender_id': 'opponent-2',
      'score': 0,
      'streak': 0,
      'question_index': 0,
      'answered': true,
      'selected_answer': 'C',
    });
    await tester.pump(const Duration(milliseconds: 100));

    final tiles = tester.widgetList<QuizOptionTile>(
      find.byType(QuizOptionTile),
    );
    final b = tiles.singleWhere((tile) => tile.answer == 'B');
    final c = tiles.singleWhere((tile) => tile.answer == 'C');
    expect(b.opponentNamesWhoSelected, ['Rojda']);
    expect(c.opponentNamesWhoSelected, ['Rojda']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('3 oyunculu online oda mevcut terminal yolunu korur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final teamRepository = _SameNameDuelRepository()..finishResponses.clear();
    addTearDown(teamRepository.controller.close);
    const question = QuizQuestion(
      id: 'team-terminal',
      category: 'Ziman',
      prompt: 'Kîjan bersiv rast e?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );
    const room = GameRoom(
      id: 'team-terminal-room',
      name: 'Oda',
      code: 'ZK-TEAM',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
        Player(id: 'opponent-2', name: 'Rojda', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );
    teamRepository
      ..terminalQuestion = question
      ..terminalRoom = room;

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: teamRepository,
          room: room,
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 100));

    for (final id in const ['opponent-1', 'opponent-2']) {
      teamRepository.controller.add({
        'sender': 'Rojda',
        'sender_id': id,
        'score': 0,
        'streak': 0,
        'question_index': 0,
        'answered': true,
        'selected_answer': 'B',
        'finished': true,
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    final result = tester.widget<QuizResultScreen>(
      find.byType(QuizResultScreen),
    );
    expect(result.opponents.map((player) => player.id), [
      'opponent-1',
      'opponent-2',
    ]);
    expect(teamRepository.finishCalls, 1);
    expect(teamRepository.resultCalls, 0);
    expect(teamRepository.awardCalls, 1);
    expect(tester.takeException(), isNull);
  });

  for (final stalledStage in [
    'finish',
    'hızlı finish hatası',
    'end-state doğrulama',
    'oyuncu yükleme',
    'ödül settlement',
  ]) {
    testWidgets('takım sonucunda takılan $stalledStage çıkışı kilitlemez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      final finishGate = Completer<void>();
      final endStateGate = Completer<RoomEndState>();
      final playersGate = Completer<List<Player>>();
      final awardGate = Completer<int>();
      final teamRepository = _SameNameDuelRepository();
      switch (stalledStage) {
        case 'finish':
          teamRepository
            ..finishResponses.clear()
            ..finishGate = finishGate;
        case 'hızlı finish hatası':
          break;
        case 'end-state doğrulama':
          teamRepository.endStateGate = endStateGate;
        case 'oyuncu yükleme':
          teamRepository
            ..finishResponses.clear()
            ..playersGate = playersGate;
        case 'ödül settlement':
          teamRepository
            ..finishResponses.clear()
            ..awardGate = awardGate;
      }
      addTearDown(() async {
        if (!finishGate.isCompleted) finishGate.complete();
        if (!endStateGate.isCompleted) {
          endStateGate.complete(teamRepository.endState);
        }
        if (!playersGate.isCompleted) {
          playersGate.complete(teamRepository.terminalRoom?.players ?? []);
        }
        if (!awardGate.isCompleted) awardGate.complete(5);
        await teamRepository.controller.close();
      });
      const question = QuizQuestion(
        id: 'team-timeout',
        category: 'Ziman',
        prompt: 'Kîjan bersiv rast e?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'A bersiva rast e.',
      );
      const room = GameRoom(
        id: 'team-timeout-room',
        name: 'Oda',
        code: 'ZK-TEAM',
        category: 'Ziman',
        players: [
          Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
          Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
          Player(id: 'opponent-2', name: 'Aram', score: 0, state: 'Hazır'),
        ],
        status: RoomStatus.active,
        questionCount: 1,
        hostId: 'me-id',
      );
      teamRepository
        ..terminalQuestion = question
        ..terminalRoom = room;

      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: teamRepository,
            room: room,
            questions: const [question],
            enableTimer: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('A').first);
      await tester.pump(const Duration(milliseconds: 100));
      for (final id in const ['opponent-1', 'opponent-2']) {
        teamRepository.controller.add({
          'sender': id,
          'sender_id': id,
          'score': 0,
          'streak': 0,
          'question_index': 0,
          'answered': true,
          'selected_answer': 'B',
          'finished': true,
        });
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();

      switch (stalledStage) {
        case 'finish':
          expect(teamRepository.finishCalls, 1);
        case 'hızlı finish hatası':
          expect(teamRepository.finishCalls, 1);
        case 'end-state doğrulama':
          expect(teamRepository.endStateCalls, greaterThanOrEqualTo(1));
        case 'oyuncu yükleme':
          expect(teamRepository.playerLoadCalls, greaterThanOrEqualTo(1));
        case 'ödül settlement':
          expect(teamRepository.awardCalls, 1);
      }

      await tester.pump(const Duration(seconds: 16));
      await tester.pump();

      expect(find.text('Tekrar dene'), findsOneWidget);
      expect(find.text('Ana Sayfa'), findsOneWidget);
      expect(find.byType(QuizResultScreen), findsNothing);

      if (stalledStage == 'finish') {
        await tester.tap(find.text('Tekrar dene'));
        await tester.pump();
        expect(teamRepository.finishCalls, 1);
        finishGate.complete();
      } else if (stalledStage == 'hızlı finish hatası') {
        await tester.tap(find.text('Tekrar dene'));
      } else {
        teamRepository.endState = const RoomEndState(
          status: RoomStatus.finished,
          endedReason: 'completed',
          forfeitedBy: null,
        );
        if (stalledStage == 'end-state doğrulama') {
          teamRepository.endStateGate = null;
        } else if (stalledStage == 'oyuncu yükleme') {
          teamRepository.playersGate = null;
        }
        await tester.tap(find.text('Tekrar dene'));
        await tester.pump();
        if (stalledStage == 'ödül settlement') {
          expect(teamRepository.awardCalls, 1);
          awardGate.complete(5);
        }
      }
      await tester.pumpAndSettle();

      expect(find.byType(QuizResultScreen), findsOneWidget);
      if (stalledStage == 'finish') {
        expect(teamRepository.finishCalls, 1);
      } else if (stalledStage == 'hızlı finish hatası') {
        expect(teamRepository.finishCalls, 2);
      } else if (stalledStage == 'ödül settlement') {
        expect(teamRepository.awardCalls, 1);
      }
    });
  }

  testWidgets('takım owner gate Retry aktif maçı bitmiş gibi göstermez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final teamRepository = _SameNameDuelRepository();
    addTearDown(teamRepository.controller.close);
    const question = QuizQuestion(
      id: 'team-owner-retry',
      category: 'Ziman',
      prompt: 'Kîjan bersiv rast e?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );
    const room = GameRoom(
      id: 'team-owner-retry-room',
      name: 'Oda',
      code: 'ZK-TEAM',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
        Player(id: 'opponent-2', name: 'Aram', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: teamRepository,
          room: room,
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(teamRepository.finishCalls, 0);

    teamRepository.userId = 'other-user';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ana Sayfa'), findsOneWidget);

    teamRepository
      ..userId = 'me-id'
      ..endState = const RoomEndState(
        status: RoomStatus.active,
        endedReason: null,
        forfeitedBy: null,
      );
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(QuizResultScreen), findsNothing);
    // Arayüz Türkçe: soru ekranda `localized(isKu: false)` ile
    // yansıtılıyor. Kurmancî ham metni aramak, curated banka
    // çevrilene kadar tesadüfen çalışıyordu (2026-08-10).
    final shown = question.localized(isKu: false);
    expect(find.text(shown.prompt), findsOneWidget);
    expect(teamRepository.resultCalls, 0);
    expect(teamRepository.awardCalls, 0);
    expect(teamRepository.finishCalls, 0);

    teamRepository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(teamRepository.awardCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('takım owner Retry bekleyen settlementı çoğaltmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final awardGate = Completer<int>();
    addTearDown(() {
      if (!awardGate.isCompleted) awardGate.complete(5);
    });
    final teamRepository = _SameNameDuelRepository()
      ..finishResponses.clear()
      ..awardGate = awardGate;
    addTearDown(teamRepository.controller.close);
    const question = QuizQuestion(
      id: 'team-owner-overlap',
      category: 'Ziman',
      prompt: 'Kîjan bersiv rast e?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );
    const room = GameRoom(
      id: 'team-owner-overlap-room',
      name: 'Oda',
      code: 'ZK-TEAM',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
        Player(id: 'opponent-2', name: 'Aram', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: teamRepository,
          room: room,
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 100));
    for (final id in const ['opponent-1', 'opponent-2']) {
      teamRepository.controller.add({
        'sender': id,
        'sender_id': id,
        'score': 0,
        'streak': 0,
        'question_index': 0,
        'answered': true,
        'selected_answer': 'B',
        'finished': true,
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(teamRepository.awardCalls, 1);

    teamRepository
      ..userId = 'other-user'
      ..endState = const RoomEndState(
        status: RoomStatus.finished,
        endedReason: 'completed',
        forfeitedBy: null,
      );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Ana Sayfa'), findsOneWidget);

    teamRepository.userId = 'me-id';
    await tester.tap(find.text('Tekrar dene'));
    await tester.pump();
    expect(teamRepository.awardCalls, 1);

    awardGate.complete(5);
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(teamRepository.awardCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('takım ödülü üst rota yarışında ikinci kez settlement olmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final awardGate = Completer<int>();
    final teamRepository = _SameNameDuelRepository()
      ..finishResponses.clear()
      ..awardGate = awardGate;
    addTearDown(teamRepository.controller.close);
    const question = QuizQuestion(
      id: 'team-reward-race',
      category: 'Ziman',
      prompt: 'Kîjan bersiv rast e?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );
    const room = GameRoom(
      id: 'team-reward-race-room',
      name: 'Oda',
      code: 'ZK-TEAM',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
        Player(id: 'opponent-2', name: 'Rojda', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );
    teamRepository
      ..terminalQuestion = question
      ..terminalRoom = room;

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: teamRepository,
          room: room,
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 100));
    for (final id in const ['opponent-1', 'opponent-2']) {
      teamRepository.controller.add({
        'sender': 'Rojda',
        'sender_id': id,
        'score': 0,
        'streak': 0,
        'question_index': 0,
        'answered': true,
        'selected_answer': 'B',
        'finished': true,
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(teamRepository.awardCalls, 1);

    final quizContext = tester.element(find.byType(QuizScreen));
    unawaited(
      Navigator.of(quizContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Takım üst rotası')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    awardGate.complete(5);
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Takım üst rotası'), findsOneWidget);

    Navigator.of(tester.element(find.text('Takım üst rotası'))).pop();
    await tester.pumpAndSettle();
    teamRepository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(teamRepository.awardCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dayanıksız takım ödülü üst rota sonrası yeniden denenir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
    final awardGate = Completer<int>();
    final teamRepository = _SameNameDuelRepository()
      ..finishResponses.clear()
      ..awardGate = awardGate;
    addTearDown(teamRepository.controller.close);
    const question = QuizQuestion(
      id: 'team-unresolved-retry',
      category: 'Ziman',
      prompt: 'Kîjan bersiv rast e?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );
    const room = GameRoom(
      id: 'team-unresolved-retry-room',
      name: 'Oda',
      code: 'ZK-TEAM',
      category: 'Ziman',
      players: [
        Player(id: 'me-id', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'opponent-1', name: 'Rojda', score: 0, state: 'Hazır'),
        Player(id: 'opponent-2', name: 'Aram', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 1,
      hostId: 'me-id',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: teamRepository,
          room: room,
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('A').first);
    await tester.pump(const Duration(milliseconds: 100));
    for (final id in const ['opponent-1', 'opponent-2']) {
      teamRepository.controller.add({
        'sender': id,
        'sender_id': id,
        'score': 0,
        'streak': 0,
        'question_index': 0,
        'answered': true,
        'selected_answer': 'B',
        'finished': true,
      });
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    expect(teamRepository.awardCalls, 1);

    final quizContext = tester.element(find.byType(QuizScreen));
    unawaited(
      Navigator.of(quizContext).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Takım üst rotası')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    awardGate.completeError(StateError('offline'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.text('Takım üst rotası'), findsOneWidget);

    teamRepository.awardGate = null;
    Navigator.of(tester.element(find.text('Takım üst rotası'))).pop();
    await tester.pumpAndSettle();
    teamRepository.endState = const RoomEndState(
      status: RoomStatus.finished,
      endedReason: 'completed',
      forfeitedBy: null,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(teamRepository.awardCalls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short portrait quiz keeps the next action pinned on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const question = QuizQuestion(
      id: 'compact-portrait-fit',
      category: 'Çand',
      prompt: 'Kurmancî kültüründe dengbêjlerin temel görevi hangisidir?',
      answers: [
        'Sözlü kültürü aktarmak',
        'Yalnızca dans etmek',
        'Resmî belge hazırlamak',
        'Spor karşılaşması düzenlemek',
      ],
      correctAnswer: 'Sözlü kültürü aktarmak',
      explanation: 'Dengbêjler sözlü kültürü kuşaktan kuşağa aktarır.',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-portrait-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);

    // Aksiyon barı sabit: joker satırı ve "Piştre" scroll gerektirmeden
    // ekranda olmalı. Geri sayım işlerken kullanıcı devam butonunu aramak
    // zorunda kalmasın (2026-07-22 UX denetimi, P0-1).
    final nextButton = find.byKey(const ValueKey('quiz-next-button'));
    final beforeScroll = tester.getRect(nextButton);
    expect(beforeScroll.bottom, lessThanOrEqualTo(640));
    expect(beforeScroll.top, greaterThanOrEqualTo(0));

    // Soru + şıklar kendi alanında kayar; bu kaydırma aksiyon barını
    // yerinden oynatmamalı.
    final scrollable = find.descendant(
      of: find.byKey(const ValueKey('quiz-portrait-scroll')),
      matching: find.byType(Scrollable),
    );
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pumpAndSettle();

    final afterScroll = tester.getRect(nextButton);
    expect(afterScroll, equals(beforeScroll));
    expect(tester.takeException(), isNull);
  });

  // Uzun telefonda kısa soru tam ortaya itilmez; göz ilerleme çubuğundan
  // soruya doğal biçimde inerken alt eylem sabit kalır.
  testWidgets('2 şıklı kısa soru uzun ekranda üstten dengeli başlar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1300));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const question = QuizQuestion(
      id: 'two-option-short',
      category: 'Ziman',
      prompt: 'Ev peyv bi kurmancî çi ye?',
      answers: ['Rast', 'Şaş'],
      correctAnswer: 'Rast',
      explanation: 'Bersiva rast: Rast.',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollArea = tester.getRect(
      find.byKey(const ValueKey('quiz-portrait-scroll')),
    );
    final content = tester.getRect(
      find.byKey(const ValueKey('quiz-answer-content')),
    );

    final gapAbove = content.top - scrollArea.top;
    final gapBelow = scrollArea.bottom - content.bottom;

    expect(
      gapAbove,
      inInclusiveRange(16, 72),
      reason: 'Kısa içerik ne üste yapışmalı ne ekran ortasına itilmelidir.',
    );

    // Burada eskiden `gapBelow > gapAbove` bekleniyordu: "kalan esnek boşluk
    // içeriğin altında kalmalı". O kural tam olarak şikâyet edilen kusuru
    // ŞART KOŞUYORDU — iPhone 17'de soru kartı ile "Sonraki" düğmesi
    // arasında ~287pt, yani ekranın üçte biri kadar bir ölü bant kalıyordu;
    // cevap verilip açıklama paneli açıldıktan sonra bile ~200pt duruyordu
    // (2026-08-16 simülatör taraması).
    //
    // Yeni kural: kart, altında kullanılmayan alan kaldığında oraya kadar
    // uzar (`_buildQuestionPanel`in `minHeight`i). Yani içerik yukarıdan
    // başlamaya devam eder ama ALTINDA ölü bant bırakmaz; artan alan kartın
    // içine düşer ve cevaptan sonra açıklama panelinin yeri olur.
    expect(
      gapBelow,
      lessThanOrEqualTo(1.0),
      reason:
          'Soru kartı ile alt eylem barı arasında ölü boşluk kalmamalı; '
          'kart kalan alanı doldurur.',
    );
  });

  testWidgets('quiz tutorial keeps its second target and tooltip on screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlay = find.byType(CoachMarkOverlay);
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.text('Süre + Cevap')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('1/2')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: overlay, matching: find.text('İleri')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: overlay, matching: find.text('Seri + Sonraki Soru')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('2/2')),
      findsOneWidget,
    );
    final target = tester.getRect(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    final tooltip = tester.getRect(
      find.descendant(of: overlay, matching: find.text('Seri + Sonraki Soru')),
    );
    expect(target.top, greaterThanOrEqualTo(0));
    expect(target.bottom, lessThanOrEqualTo(640));
    expect(tooltip.top, greaterThanOrEqualTo(0));
    expect(tooltip.bottom, lessThanOrEqualTo(640));
  });

  testWidgets('wide portrait quiz centers content within 800 px', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Testin adı zaten "wide **portrait**": geniş bir viewport'ta içeriğin
    // ortalanıp 800px ile sınırlanmasını ölçüyor. Yazıldığı sırada 1440×900
    // yanlışlıkla telefon-yatay dalına düşüyordu, bu yüzden ölçüm
    // `quiz-landscape-content` üzerinden yapılmıştı (ZKR-P1-001). Dal seçimi
    // düzeltildikten sonra bu genişlik artık dikey (stacked) akışı kullanıyor;
    // ölçülen sözleşme aynı, yalnız doğru daldan okunuyor.
    expect(
      find.byKey(const ValueKey('quiz-landscape-content')),
      findsNothing,
      reason: '1440×900 masaüstü telefon-yatay dalına düşmemeli',
    );

    final content = find.byKey(const ValueKey('quiz-portrait-scroll'));
    expect(content, findsOneWidget);
    expect(tester.getSize(content).width, lessThanOrEqualTo(800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('visual quiz keeps the next action visible in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const question = QuizQuestion(
      id: 'visual-landscape-fit',
      category: 'Çand',
      prompt: 'Görseldeki etkinlik hangi kültürel kategoriyle ilgilidir?',
      answers: ['Coğrafya', 'Ziman', 'Müzik', 'Edebiyat'],
      correctAnswer: 'Müzik',
      explanation: 'Govend kültürel bir dans ve müzik etkinliğidir.',
      type: QuestionType.visual,
      imageUrl: 'asset://assets/zankurd.webp',
    );

    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nextButton = find.byKey(const ValueKey('quiz-next-button'));
    final nextRect = tester.getRect(nextButton);
    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);
    expect(nextRect.top, greaterThanOrEqualTo(0));
    expect(nextRect.bottom, lessThanOrEqualTo(390));
    expect(tester.takeException(), isNull);
  });
}
