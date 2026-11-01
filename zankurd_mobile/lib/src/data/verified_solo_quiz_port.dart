import '../models/quiz_question.dart';

/// Yerel ilerlemeden bağımsız, sunucunun cevapları doğruladığı oturum.
/// Port yoksa veya RPC erişilemiyorsa yerel tur çalışmaya devam eder.
abstract interface class VerifiedSoloQuizPort {
  Future<void> startVerifiedSoloRound({
    required String clientRoundId,
    required List<QuizQuestion> questions,
    required bool daily,
  });

  Future<void> recordVerifiedSoloAnswer({
    required String clientRoundId,
    required String questionId,
    required String choice,
  });

  Future<bool> submitVerifiedDailyResult(String clientRoundId);
}
