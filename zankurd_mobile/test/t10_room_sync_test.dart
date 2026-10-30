import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/game/reveal_timing.dart';
import 'package:zankurd_mobile/src/game/server_clock.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

final _questions = List.generate(
  3,
  (i) => QuizQuestion(
    id: 't10-question-$i',
    category: 'Ziman',
    prompt: 'Soru ${i + 1}',
    answers: const ['A', 'B', 'C', 'D'],
    correctAnswer: '',
    explanation: '',
  ),
);

final _room = GameRoom(
  id: 't10-room',
  name: 'T10',
  code: 'T10',
  category: 'Ziman',
  isCustom: true,
  maxPlayers: 4,
  players: [
    for (final id in ['A', 'B', 'C', 'D'])
      Player(id: id, name: id, score: 0, state: Player.readyState),
  ],
  status: RoomStatus.active,
  questionCount: 3,
  secondsPerQuestion: 20,
  hostId: 'A',
);

/// Four independent repositories share only server state. RPC replies are
/// captured before their transport delay; clocks continue ageing in transit.
class _RoomServer {
  _RoomServer(this.tester) : epoch = tester.binding.clock.now();

  final WidgetTester tester;
  final DateTime epoch;
  final clients = <_RoomClient>[];
  final answers = <int, Map<String, String>>{};
  final reveals = <int, DateTime>{};
  final scheduledEvents = <Timer>[];
  int index = 0;
  late DateTime startedAt = epoch;

  DateTime get now => tester.binding.clock.now();
  DateTime get deadline => startedAt.add(const Duration(seconds: 20));

  void notifyPlayers() {
    for (final client in clients) {
      scheduledEvents.add(
        Timer(client.delay, () {
          if (!client.players.isClosed) client.players.add(_room.players);
        }),
      );
    }
  }

  RoomResumeSnapshot snapshot(_RoomClient client) {
    final sampledAt = now;
    final clock = ServerClock(
      serverNow: sampledAt,
      localReceivedAt: sampledAt.add(client.wallSkew),
      elapsed: () => now.difference(sampledAt),
    );
    final own = answers[index]?[client.id];
    final revealAt = reveals[index];
    return RoomResumeSnapshot(
      room: _room,
      currentQuestionIndex: index,
      ownScore: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: reveals.length,
      answers: [
        for (final questionIndex in reveals.keys)
          ResumedAnswer(
            questionId: _questions[questionIndex].id,
            questionIndex: questionIndex,
            selectedOptionKey: answers[questionIndex]?[client.id] ?? 'TIMEOUT',
            correctOptionKey: 'A',
            isCorrect: false,
            pointsAwarded: 0,
            responseMs: 20000,
          ),
      ],
      pendingAnswer: own == null || revealAt != null
          ? null
          : ResumedPendingAnswer(
              questionId: _questions[index].id,
              questionIndex: index,
              selectedOptionKey: own,
              responseMs: 4000,
            ),
      serverNow: sampledAt,
      serverClock: clock,
      revealClock: revealAt == null
          ? null
          : ServerRevealClock.fromServerClock(
              clock: clock,
              endsAt: revealAt.add(const Duration(seconds: 4)),
            ),
      questionStartedAt: startedAt,
      deadline: deadline,
      remainingMs: deadline.difference(now).inMilliseconds.clamp(0, 20000),
    );
  }

  void advance(int expected) {
    if (expected != index) return;
    final revealedAt = reveals[index];
    if (revealedAt == null) {
      if (now.isBefore(deadline)) return;
      // Server-generated TIMEOUT rows exist, but progress counts only choices.
      final rows = answers.putIfAbsent(index, () => {});
      for (final client in clients) {
        rows.putIfAbsent(client.id, () => 'TIMEOUT');
      }
      reveals[index] = now;
      // All scores remain zero: production room_players emits no change.
    } else if (!now.isBefore(revealedAt.add(const Duration(seconds: 4)))) {
      index++;
      startedAt = now;
      notifyPlayers();
    }
  }

  Future<void> close() async {
    for (final timer in scheduledEvents) {
      timer.cancel();
    }
    for (final client in clients) {
      await client.players.close();
      await client.broadcasts.close();
    }
  }
}

class _RoomClient extends MockZanKurdRepository {
  _RoomClient(this.server, this.id, this.wallSkew, this.delay) {
    server.clients.add(this);
  }

  final _RoomServer server;
  final String id;
  final Duration wallSkew;
  final Duration delay;
  final players = StreamController<List<Player>>.broadcast();
  final broadcasts = StreamController<Map<String, dynamic>>.broadcast();
  Completer<void>? nextSubmitGate;
  bool rejectNextSubmit = false;
  Completer<void>? nextResumeGate;
  Completer<void>? nextProgressGate;
  int resumeCalls = 0;
  int progressCalls = 0;
  final progressSamples = <String>[];

  @override
  String get currentUserId => id;
  @override
  bool get usesServerHiddenAnswers => true;
  @override
  Future<String> getProfileName() async => id;
  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) => players.stream;
  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      broadcasts.stream;
  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    for (final client in server.clients) {
      if (client != this) client.broadcasts.add(payload);
    }
  }

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    resumeCalls++;
    final snapshot = server.snapshot(this);
    final gate = nextResumeGate;
    nextResumeGate = null;
    if (gate != null) await gate.future;
    await Future<void>.delayed(delay);
    return snapshot;
  }

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) =>
      loadMyResumableRoom();
  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => _room.players;
  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async =>
      const RoomEndState(
        status: RoomStatus.active,
        endedReason: null,
        forfeitedBy: null,
      );

  @override
  Future<RoomAnswerProgress?> loadRoomAnswerProgress(GameRoom room) async {
    progressCalls++;
    final progress = RoomAnswerProgress(
      questionIndex: server.index,
      answered: (server.answers[server.index]?.values ?? <String>[])
          .where((answer) => answer != 'TIMEOUT')
          .length,
      active: 4,
      revealed: server.reveals.containsKey(server.index),
    );
    progressSamples.add(
      '${server.now.difference(server.epoch).inMilliseconds}:${progress.answered}',
    );
    final gate = nextProgressGate;
    nextProgressGate = null;
    if (gate != null) await gate.future;
    await Future<void>.delayed(delay);
    return progress;
  }

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    final gate = nextSubmitGate;
    nextSubmitGate = null;
    if (gate != null) await gate.future;
    if (rejectNextSubmit) {
      rejectNextSubmit = false;
      throw StateError('Rejected test answer');
    }
    server.answers.putIfAbsent(server.index, () => {})[id] =
        selectedOptionOptionKey;
    return {'accepted': true, 'pending': true};
  }

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) {
    server.advance(expectedQuestionIndex);
    return loadMyResumableRoom();
  }
}

Finder _inside(String id, Finder matching) =>
    find.descendant(of: find.byKey(ValueKey('client-$id')), matching: matching);

Future<void> _tick(WidgetTester tester, Duration duration) async {
  // Small increments deliver distinct delayed RPCs/events at their real times.
  for (var ms = 0; ms < duration.inMilliseconds; ms += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pump();
}

Future<_RoomServer> _openFour(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1608, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final server = _RoomServer(tester);
  for (var i = 0; i < 4; i++) {
    _RoomClient(
      server,
      ['A', 'B', 'C', 'D'][i],
      Duration(seconds: [5, -5, 3, -3][i]),
      Duration(milliseconds: [0, 700, 1500, 2000][i]),
    );
  }
  addTearDown(server.close);
  await tester.pumpWidget(
    testShell(
      child: Row(
        children: [
          for (final client in server.clients)
            Expanded(
              key: ValueKey('client-${client.id}'),
              child: MediaQuery(
                data: const MediaQueryData(size: Size(402, 874)),
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => QuizScreen(
                      repository: client,
                      room: _room,
                      questions: _questions,
                      resumeSnapshot: server.snapshot(client),
                      suspenseHold: Duration.zero,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  await tester.pump();
  return server;
}

void main() {
  setUp(freshMockRepository);

  testWidgets('T11: yerel cevap sunucu yanıtını beklemeden sayılır', (
    tester,
  ) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(milliseconds: 3100));
    final client = server.clients.last;
    final gate = Completer<void>();
    client.nextSubmitGate = gate;
    await tester.tap(_inside('D', find.byType(QuizOptionTile)).first);
    await tester.pump();
    expect(server.answers[0], isNull);
    expect(_inside('D', find.text('1/4 cevapladı')), findsOneWidget);
    gate.complete();
    await _tick(tester, const Duration(milliseconds: 2200));
    expect(_inside('D', find.text('1/4 cevapladı')), findsOneWidget);
    expect(_inside('D', find.text('2/4 cevapladı')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });

  testWidgets('T11: kabul edilen cevap yayını periyodik yoklamayı beklemez', (
    tester,
  ) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(milliseconds: 3100));
    final observer = server.clients.first;
    final before = observer.progressCalls;
    await tester.tap(_inside('D', find.byType(QuizOptionTile)).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(observer.progressCalls, greaterThan(before));
    expect(_inside('A', find.text('1/4 cevapladı')), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });

  testWidgets('T11: reddedilen yerel cevap sayısı geri alınır', (tester) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(milliseconds: 3100));
    final client = server.clients.first;
    final gate = Completer<void>();
    client.nextSubmitGate = gate;
    client.rejectNextSubmit = true;
    await tester.tap(_inside('A', find.byType(QuizOptionTile)).first);
    await tester.pump();
    expect(_inside('A', find.text('1/4 cevapladı')), findsOneWidget);
    gate.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(_inside('A', find.text('0/4 cevapladı')), findsOneWidget);
    expect(server.answers[0], isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });

  testWidgets('T11: yayın sayı veya soru evresini değiştiremez', (
    tester,
  ) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(milliseconds: 3100));
    final client = server.clients.first;
    final before = client.progressCalls;
    client.broadcasts.add({
      'type': 'crowd_answered',
      'sender_id': 'D',
      'question_index': 0,
      'answered': 4,
      'revealed': true,
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(client.progressCalls, greaterThan(before));
    expect(_inside('A', find.text('0/4 cevapladı')), findsOneWidget);
    expect(_inside('A', find.text('Soru 1')), findsOneWidget);
    final after = client.progressCalls;
    client.broadcasts.add({
      'type': 'crowd_answered',
      'sender_id': 'outsider',
      'question_index': 0,
    });
    client.broadcasts.add({
      'type': 'crowd_answered',
      'sender_id': 'D',
      'question_index': 1,
    });
    await tester.pump();
    expect(client.progressCalls, after);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });

  testWidgets(
    'T10: dört oda, ±5 sn saat ve 0–2 sn gecikmede ortak sayaç/sayı',
    (tester) async {
      final server = await _openFour(tester);
      await _tick(tester, const Duration(seconds: 4));
      await tester.tap(_inside('A', find.byType(QuizOptionTile)).first);
      await tester.pump();
      await _tick(tester, const Duration(seconds: 1));
      await tester.tap(_inside('D', find.byType(QuizOptionTile)).first);
      await tester.pump();
      await _tick(tester, const Duration(seconds: 4));

      expect(server.answers[0]!.keys.toSet(), {'A', 'D'});
      final seconds = <int>[];
      for (final client in server.clients) {
        final timer = tester.widget<QuizTimerWidget>(
          _inside(client.id, find.byType(QuizTimerWidget)),
        );
        seconds.add((timer.animation.value * timer.maxSeconds).ceil());
        expect(timer.animation.isAnimating, isTrue, reason: client.id);
        expect(client.progressCalls, greaterThan(2));
      }
      expect(
        seconds.every((seconds) => (seconds - 11).abs() <= 1),
        isTrue,
        reason: '$seconds; A/D yanıtında 16/15 üzerinde donmamalı',
      );
      seconds.sort();
      expect(seconds.last - seconds.first, lessThanOrEqualTo(1));

      for (final client in server.clients) {
        expect(
          tester
              .widget<Text>(
                _inside(
                  client.id,
                  find.byKey(const ValueKey('quiz-crowd-progress')),
                ),
              )
              .data,
          '2/4 cevapladı',
          reason: '${client.id}, ${client.progressSamples}',
        );
      }
      await _tick(tester, const Duration(seconds: 19));
      expect(server.index, 1);
      for (final client in server.clients) {
        expect(_inside(client.id, find.text('Soru 2')), findsOneWidget);
        expect(_inside(client.id, find.text('0/4 cevapladı')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _tick(tester, const Duration(seconds: 3));
    },
  );

  testWidgets('T10: dört TIMEOUT satırı cevaplayan sayısını artırmaz', (
    tester,
  ) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(seconds: 23));
    expect(server.answers[0]!.values, everyElement('TIMEOUT'));
    for (final client in server.clients) {
      expect(_inside(client.id, find.text('0/4 cevapladı')), findsOneWidget);
      expect(_inside(client.id, find.text('4/4 cevapladı')), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });

  testWidgets('T10: uçuşta eski snapshot varken yeni oda olayı kaybolmaz', (
    tester,
  ) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(seconds: 3));
    final client = server.clients.first;
    final gate = Completer<void>();
    client.nextResumeGate = gate;
    client.players.add(_room.players);
    await _tick(tester, const Duration(seconds: 1));
    final callsWhileHeld = client.resumeCalls;
    expect(client.nextResumeGate, isNull);
    server.index = 1;
    server.startedAt = server.now;
    client.players.add(_room.players);
    await _tick(tester, const Duration(seconds: 1));
    gate.complete();
    await _tick(tester, const Duration(milliseconds: 500));
    // Before the six-second heavy polling fallback, queued invalidation wins.
    expect(client.resumeCalls, greaterThan(callsWhileHeld));
    expect(_inside('A', find.text('Soru 2')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });

  testWidgets('T10: geç dönen eski cevap sayısı yeni sayıyı geri alamaz', (
    tester,
  ) async {
    final server = await _openFour(tester);
    await _tick(tester, const Duration(seconds: 3));
    final client = server.clients.first;
    final gate = Completer<void>();
    client.nextProgressGate = gate;
    await _tick(tester, const Duration(milliseconds: 1100));
    expect(client.nextProgressGate, isNull);
    await tester.tap(_inside('A', find.byType(QuizOptionTile)).first);
    await tester.pump();
    await _tick(tester, const Duration(milliseconds: 100));
    expect(_inside('A', find.text('1/4 cevapladı')), findsOneWidget);
    gate.complete();
    await _tick(tester, const Duration(milliseconds: 100));
    expect(_inside('A', find.text('1/4 cevapladı')), findsOneWidget);
    expect(_inside('A', find.text('0/4 cevapladı')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await _tick(tester, const Duration(seconds: 3));
  });
}
