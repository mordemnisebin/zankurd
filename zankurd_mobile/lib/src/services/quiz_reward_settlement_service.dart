import '../data/zankurd_repository.dart';
import '../models/room.dart';
import '../utils/error_reporter.dart';

enum QuizRewardSettlementState { claimed, queued, unresolved }

class QuizRewardSettlement {
  const QuizRewardSettlement({required this.state, required this.coinsAwarded});

  final QuizRewardSettlementState state;
  final int coinsAwarded;

  bool get isDurable => state != QuizRewardSettlementState.unresolved;
}

typedef QuizRewardQueue =
    Future<void> Function({
      required int score,
      required int correctCount,
      required int bestStreak,
      required int totalQuestions,
      required String roomId,
    });

typedef QuizRewardSettlementErrorRecorder =
    void Function(Object error, StackTrace stack, {String? reason});

/// Coin talebi ile kalıcı çevrimdışı kuyruğu tek, typed sonuca indirger.
class QuizRewardSettlementService {
  const QuizRewardSettlementService({
    required ZanKurdRepository repository,
    QuizRewardQueue? queueReward,
    QuizRewardSettlementErrorRecorder? errorRecorder,
  }) : // Named public API'yi `repository:` olarak tutmak entegrasyonu sadeleştirir.
       // ignore: prefer_initializing_formals
       _repository = repository,
       // ignore: prefer_initializing_formals
       _queueReward = queueReward,
       _errorRecorder = errorRecorder ?? ErrorReporter.record;

  final ZanKurdRepository _repository;
  final QuizRewardQueue? _queueReward;
  final QuizRewardSettlementErrorRecorder _errorRecorder;

  Future<QuizRewardSettlement> settle({
    required GameRoom room,
    required bool practice,
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) async {
    final roomId = room.id?.trim();
    if (practice || roomId == null || roomId.isEmpty) {
      return const QuizRewardSettlement(
        state: QuizRewardSettlementState.claimed,
        coinsAwarded: 0,
      );
    }

    late final int amount;
    try {
      amount = await _repository.awardQuizCoins(
        score: score,
        correctCount: correctCount,
        bestStreak: bestStreak,
        totalQuestions: totalQuestions,
        room: room,
      );
    } catch (error, stack) {
      _errorRecorder(error, stack, reason: 'awardQuizCoins failed');
      final queueReward = _queueReward;
      if (queueReward != null) {
        try {
          await queueReward(
            score: score,
            correctCount: correctCount,
            bestStreak: bestStreak,
            totalQuestions: totalQuestions,
            roomId: roomId,
          );
          return const QuizRewardSettlement(
            state: QuizRewardSettlementState.queued,
            coinsAwarded: 0,
          );
        } catch (queueError, queueStack) {
          _errorRecorder(
            queueError,
            queueStack,
            reason: 'queueQuizReward failed',
          );
        }
      }
      return const QuizRewardSettlement(
        state: QuizRewardSettlementState.unresolved,
        coinsAwarded: 0,
      );
    }

    if (amount < 0) {
      final error = FormatException(
        'Quiz reward amount must not be negative: $amount',
      );
      _errorRecorder(
        error,
        StackTrace.current,
        reason: 'awardQuizCoins malformed response',
      );
      return const QuizRewardSettlement(
        state: QuizRewardSettlementState.unresolved,
        coinsAwarded: 0,
      );
    }

    return QuizRewardSettlement(
      state: QuizRewardSettlementState.claimed,
      coinsAwarded: amount,
    );
  }
}
