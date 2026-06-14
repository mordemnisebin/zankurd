class CoinCalculator {
  CoinCalculator._();

  static int award({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
  }) {
    final completionBonus = totalQuestions >= 10 ? 20 : 8;
    return completionBonus +
        (correctCount * 6) +
        (bestStreak * 2) +
        score ~/ 80;
  }

  static int practiceAward() => 0;
}
