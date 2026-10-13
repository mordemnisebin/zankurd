/// Jeton harcamalarının istemci tarafındaki tek kaynağı.
///
/// ## Niçin tek yerde
///
/// `spend_coins` RPC'si tutarı KENDİ tablosundan doğrular: gönderilen miktar
/// sunucunun beklediği değerle birebir aynı değilse çağrı
/// `{'success': false, 'error': 'invalid price'}` döner. `spendCoins` bu
/// dizeyi atıp yalnız `false` döndürdüğü için ekranda gerekçesiz bir
/// başarısızlık kalır — 2026-08-02'deki neon çerçeve kusuru (ürün istemcide
/// vardı, sunucunun izin listesinde yoktu) tam olarak böyle görünmüştü.
///
/// Seri dondurma ücreti 2026-08-17'ye kadar ÜÇ yerde yazılıydı: sunucu
/// RPC'sinde, `home_screen`de ve `quiz_result_screen`de birer özel sabit
/// olarak. Üçü de aynı sayıyı söylüyordu, ama biri değiştiğinde ötekilerin
/// haberi olmazdı ve tek görünür sonuç "satın alma başarısız" olurdu.
/// İstemci tarafı artık tek bir yerde; sunucuyla eşitliği
/// `wildcard_price_contract_test` ölçer.
///
/// Joker fiyatları burada DEĞİL, `WildcardType.coinCost` içinde durur:
/// fiyat, jokerin kendi tanımının yanında yaşamalı. Aynı bekçi onları da
/// göç dosyasıyla karşılaştırır.
class CoinPrices {
  const CoinPrices._();

  /// Serinin bir günlük korunması. `spend_coins` gerekçesi: `streak_freeze`.
  static const streakFreeze = 50;

  /// Seri dondurmanın RPC gerekçesi.
  ///
  /// Idempotent yol (`spendStreakFreeze`) da aynı gerekçeyi kullanır; bkz.
  /// `streak_freeze_idempotency_contract_test`.
  static const streakFreezeReason = 'streak_freeze';
}
