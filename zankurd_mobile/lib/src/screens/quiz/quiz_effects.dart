/// Üst üste doğru cevap serisinin görsel kademesi.
/// Eşikler spec'ten: ×3 bronz (turuncu), ×5 gümüş (mor), ×10 altın.
enum ComboTier { bronze, silver, gold }

ComboTier? comboTierFor(int streak) {
  if (streak >= 10) return ComboTier.gold;
  if (streak >= 5) return ComboTier.silver;
  if (streak >= 3) return ComboTier.bronze;
  return null;
}

/// Kalan süre oranından (1.0 = dolu, 0.0 = bitti) kırmızı kenar vinyetinin
/// gücünü üretir. Son üçte birde 0→1 doğrusal tırmanır; öncesinde 0.
double vignetteStrengthFor(double remainingFraction) {
  final clamped = remainingFraction.clamp(0.0, 1.0);
  const threshold = 1 / 3;
  if (clamped >= threshold) return 0.0;
  return (threshold - clamped) / threshold;
}
