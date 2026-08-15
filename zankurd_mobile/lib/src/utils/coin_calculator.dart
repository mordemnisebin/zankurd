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

  /// Tek başına oynanan turun ödülü.
  ///
  /// Oda turundan ayrı ve belirgin biçimde küçük, çünkü iki turun doğrulama
  /// rejimi farklı: oda turunu sunucu görebildiği için DOĞRULAR, solo turu
  /// doğrulayamaz — çevrimdışı banka istemcidedir, sorular veritabanında
  /// yoktur. Doğrulanamayan bir talep kabul ediliyorsa ödülü küçük ve
  /// tavanlı olmalıdır.
  ///
  /// On soruluk kusursuz bir tur 24 jeton verir; [soloDailyCap] ile birlikte
  /// tavana iki turda varılır.
  ///
  /// Bu formül `supabase/2026-08-10_solo_round_reward.sql` içindeki
  /// `claim_solo_reward` ile BİREBİR aynı olmalıdır: üretimde miktarı sunucu
  /// belirler, buradaki hesap yalnız çevrimdışı/mock yolunun aynı davranışı
  /// göstermesi içindir. `test/solo_reward_parity_test.dart` ikisinin
  /// ayrışmadığını sabitler.
  static int soloAward({required int correctCount, required int bestStreak}) =>
      4 + correctCount + bestStreak;

  /// Solo turlardan bir günde kazanılabilecek en yüksek jeton.
  ///
  /// Talep doğrulanamadığı için tavan, zararın sınırıdır: hile yapan biri
  /// en fazla bunu alır ve bu, günde iki iyi turla dürüstçe de ulaşılan bir
  /// miktardır.
  static const soloDailyCap = 45;
}
