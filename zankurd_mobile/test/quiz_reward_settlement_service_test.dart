import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';

void main() {
  test(
    'sunucunun başarılı sıfır ödülü claimed olur ve kuyruğa girmez',
    () async {
      final repository = _AwardRepository(result: 0);
      var queueCalls = 0;
      final service = QuizRewardSettlementService(
        repository: repository,
        queueReward: _queue((_) async => queueCalls++),
      );

      final result = await service.settle(
        room: _onlineRoom,
        practice: false,
        score: 310,
        correctCount: 7,
        bestStreak: 4,
        totalQuestions: 10,
      );

      expect(result.state, QuizRewardSettlementState.claimed);
      expect(result.coinsAwarded, 0);
      expect(result.isDurable, isTrue);
      expect(queueCalls, 0);
      expect(repository.lastFacts, const [310, 7, 4, 10, 'room-1']);
    },
  );

  test('sunucu hatasında durable queue tamamlanmadan queued dönmez', () async {
    final repository = _AwardRepository(error: StateError('offline'));
    final queueGate = Completer<void>();
    _QueueFacts? queuedFacts;
    final service = QuizRewardSettlementService(
      repository: repository,
      queueReward: _queue((facts) async {
        queuedFacts = facts;
        await queueGate.future;
      }),
      errorRecorder: (_, _, {reason}) {},
    );

    var completed = false;
    final future = service
        .settle(
          room: _onlineRoom,
          practice: false,
          score: 310,
          correctCount: 7,
          bestStreak: 4,
          totalQuestions: 10,
        )
        .whenComplete(() => completed = true);
    await Future<void>.delayed(Duration.zero);

    expect(completed, isFalse);
    expect(queuedFacts?.roomId, 'room-1');
    expect(queuedFacts?.score, 310);
    expect(queuedFacts?.correctCount, 7);
    expect(queuedFacts?.bestStreak, 4);
    expect(queuedFacts?.totalQuestions, 10);

    queueGate.complete();
    final result = await future;
    expect(result.state, QuizRewardSettlementState.queued);
    expect(result.coinsAwarded, 0);
    expect(result.isDurable, isTrue);
  });

  test(
    'queue persistence hatası unresolved kalır ve hata kaydedilir',
    () async {
      final repository = _AwardRepository(error: StateError('offline'));
      final reasons = <String?>[];
      final service = QuizRewardSettlementService(
        repository: repository,
        queueReward: _queue((_) async => throw StateError('disk full')),
        errorRecorder: (_, _, {reason}) => reasons.add(reason),
      );

      final result = await service.settle(
        room: _onlineRoom,
        practice: false,
        score: 50,
        correctCount: 2,
        bestStreak: 1,
        totalQuestions: 10,
      );

      expect(result.state, QuizRewardSettlementState.unresolved);
      expect(result.isDurable, isFalse);
      expect(reasons, ['awardQuizCoins failed', 'queueQuizReward failed']);
    },
  );

  test('queue callback yoksa sunucu hatası unresolved kalır', () async {
    final service = QuizRewardSettlementService(
      repository: _AwardRepository(error: StateError('offline')),
      errorRecorder: (_, _, {reason}) {},
    );

    final result = await service.settle(
      room: _onlineRoom,
      practice: false,
      score: 50,
      correctCount: 2,
      bestStreak: 1,
      totalQuestions: 10,
    );

    expect(result.state, QuizRewardSettlementState.unresolved);
  });

  test(
    'claim beklerken hesap değişirse ödül yeni hesaba queue edilmez',
    () async {
      final repository = _DeferredIdentityAwardRepository();
      final reasons = <String?>[];
      var queueCalls = 0;
      final service = QuizRewardSettlementService(
        repository: repository,
        queueReward: _queue((_) async => queueCalls++),
        errorRecorder: (_, _, {reason}) => reasons.add(reason),
      );

      final future = service.settle(
        room: _onlineRoom,
        practice: false,
        score: 310,
        correctCount: 7,
        bestStreak: 4,
        totalQuestions: 10,
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.calls, 1);

      repository.userId = 'user-2';
      repository.gate.completeError(StateError('offline'));
      final result = await future;

      expect(result.state, QuizRewardSettlementState.unresolved);
      expect(queueCalls, 0);
      expect(reasons, [
        'awardQuizCoins failed',
        'quiz reward owner changed before queue',
      ]);
    },
  );

  test(
    'practice ve yerel oda sunucuya gitmeden güvenli claimed sıfırdır',
    () async {
      final repository = _AwardRepository(result: 99);
      final service = QuizRewardSettlementService(repository: repository);

      final practice = await service.settle(
        room: _onlineRoom,
        practice: true,
        score: 100,
        correctCount: 5,
        bestStreak: 3,
        totalQuestions: 10,
      );
      final local = await service.settle(
        room: _localRoom,
        practice: false,
        score: 100,
        correctCount: 5,
        bestStreak: 3,
        totalQuestions: 10,
      );

      expect(practice.state, QuizRewardSettlementState.claimed);
      expect(local.state, QuizRewardSettlementState.claimed);
      expect(practice.coinsAwarded, 0);
      expect(local.coinsAwarded, 0);
      expect(repository.calls, 0);
    },
  );

  test('negatif sunucu miktarı malformed kalır ve kuyruğa girmez', () async {
    final recorded = <Object>[];
    var queueCalls = 0;
    final service = QuizRewardSettlementService(
      repository: _AwardRepository(result: -1),
      queueReward: _queue((_) async => queueCalls++),
      errorRecorder: (error, _, {reason}) => recorded.add(error),
    );

    final result = await service.settle(
      room: _onlineRoom,
      practice: false,
      score: 100,
      correctCount: 5,
      bestStreak: 3,
      totalQuestions: 10,
    );

    expect(result.state, QuizRewardSettlementState.unresolved);
    expect(recorded.single, isA<FormatException>());
    expect(queueCalls, 0);
  });
}

QuizRewardQueue _queue(Future<void> Function(_QueueFacts) callback) {
  return ({
    required score,
    required correctCount,
    required bestStreak,
    required totalQuestions,
    required roomId,
  }) => callback(
    _QueueFacts(
      score: score,
      correctCount: correctCount,
      bestStreak: bestStreak,
      totalQuestions: totalQuestions,
      roomId: roomId,
    ),
  );
}

class _QueueFacts {
  const _QueueFacts({
    required this.score,
    required this.correctCount,
    required this.bestStreak,
    required this.totalQuestions,
    required this.roomId,
  });

  final int score;
  final int correctCount;
  final int bestStreak;
  final int totalQuestions;
  final String roomId;
}

class _AwardRepository extends MockZanKurdRepository {
  _AwardRepository({this.result, this.error});

  final int? result;
  final Object? error;
  int calls = 0;
  List<Object?>? lastFacts;

  @override
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    calls++;
    lastFacts = [score, correctCount, bestStreak, totalQuestions, room?.id];
    if (error case final error?) throw error;
    return result!;
  }
}

class _DeferredIdentityAwardRepository extends MockZanKurdRepository {
  String userId = 'user-1';
  final gate = Completer<int>();
  int calls = 0;

  @override
  String? get currentUserId => userId;

  @override
  Future<int> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) {
    calls++;
    return gate.future;
  }
}

const _onlineRoom = GameRoom(
  id: 'room-1',
  name: '1vs1',
  code: 'ZK-TEST',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
  questionCount: 10,
);

const _localRoom = GameRoom(
  name: 'Solo',
  code: 'LOCAL',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
  questionCount: 10,
);
