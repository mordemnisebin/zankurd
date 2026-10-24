import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';

/// Seri onarımının tek giriş noktası: sunucudan ONAY alınmadan yerel seri
/// DEĞİŞMEZ.
///
/// ## Sıra neden böyle
///
/// Jeton sunucuda, seri cihazda. Önce yerel geri yükleme yapılsaydı ve ödeme
/// başarısız olsaydı bedava onarım olurdu; önce ödeme yapılıp yerel yazım
/// çökmeden önce uygulama kapansaydı jeton gider seri gelmezdi. Çözüm:
/// sunucu çağrısı IDEMPOTENT'tir (ay + kırılma günü anahtarı), önce o
/// çalışır; yerel yazım başarısız kalırsa teklif hâlâ görünür ve ikinci
/// dokunuş sunucudan `alreadyRepaired` alır, yeniden ücret kesilmez, seri
/// geri yüklenir.
class StreakRepairService {
  const StreakRepairService._();

  /// [offer] hâlâ geçerli değilse (ay hakkı kullanıldı, başka gün oynandı,
  /// gece yarısı geçti) sunucuya HİÇ gidilmez ve [StreakRepairOutcome.failed]
  /// döner.
  static Future<StreakRepairOutcome> repair({
    required ZanKurdRepository repository,
    required StreakStore store,
    required StreakRepairOffer offer,
    required bool premium,
    DateTime? now,
  }) async {
    final current = store.repairOffer(now: now);
    if (current == null || current.breakDay != offer.breakDay) {
      return StreakRepairOutcome.failed;
    }
    final result = await repository.spendStreakRepair(
      monthKey: offer.monthKey,
      breakDay: offer.breakDay,
      premium: premium,
    );
    if (result.succeeded) {
      await store.applyRepair(offer, now: now);
    }
    return result.outcome;
  }
}
