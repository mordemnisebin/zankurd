/// Doğru cevabın temel puanını ve cevap hızına bağlı bonusu hesaplar.
class SpeedScore {
  const SpeedScore._();

  static int calculate({
    required int responseMs,
    required int limitSeconds,
    required bool correct,
  }) {
    if (!correct || responseMs < 0 || limitSeconds <= 0) return 0;

    final limitMs = limitSeconds * 1000;
    if (responseMs >= limitMs) return 0;

    final remainingRatio = (limitMs - responseMs) / limitMs;
    return 100 + (remainingRatio * 100).round();
  }
}
