import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../utils/error_reporter.dart';

/// Seri onarımının tek giriş noktası: sunucudan ONAY alınmadan yerel seri
/// DEĞİŞMEZ.
///
/// ## Sıra neden böyle
///
/// Jeton sunucuda, seri cihazda. Önce yerel geri yükleme yapılsaydı ve ödeme
/// başarısız olsaydı bedava onarım olurdu; önce ödeme yapılıp yerel yazım
/// çökmeden önce uygulama kapansaydı jeton gider seri gelmezdi. Çözüm:
/// sunucu çağrısı IDEMPOTENT'tir (kırılma günü anahtarı; ay değişse de aynı
/// kırılma günü "zaten onarıldı" döner), önce o çalışır.
///
/// ## Kalıcı niyet
///
/// Tahsilat ile yerel [StreakStore.applyRepair] arasında uygulama kapanır ya
/// da yanıt kaybolursa, teklifin geçerlilik günü geçince yerel ön kontrol
/// sunucuya yeniden başvurmayı engelliyordu: jeton gitmiş, seri onarılmamış
/// kalıyordu. Bu yüzden sunucuya GİTMEDEN ÖNCE teklif (tarihli anlık
/// görüntüsüyle) kalıcı yazılır; yalnız kesin sonuçta (onarım uygulandı,
/// yetersiz bakiye, aylık hak dolu) silinir. Açılışta [recoverPending] aynı
/// niyetle sunucuya yeniden başvurur (aynı kırılma günü → yeniden ücret
/// kesilmez) ve onarımı TEKLİFİN ANINDA uygular.
class StreakRepairService {
  const StreakRepairService._();

  static const _intentPrefix = 'zankurd.pendingOp.streak_repair.';

  /// Niyet bu süreden eskiyse bırakılır (sunucu zaten kırılma gününü bugünden
  /// en çok 1 gün önce kabul eder; eski niyet yeni ücret kesmesin).
  static const intentMaxAge = Duration(hours: 48);

  /// [offer] hâlâ geçerli değilse (ay hakkı kullanıldı, başka gün oynandı,
  /// gece yarısı geçti) sunucuya HİÇ gidilmez ve [StreakRepairOutcome.failed]
  /// döner.
  static Future<StreakRepairOutcome> repair({
    required ZanKurdRepository repository,
    required StreakStore store,
    required StreakRepairOffer offer,
    DateTime? now,
  }) async {
    final current = store.repairOffer(now: now);
    if (current == null || current.breakDay != offer.breakDay) {
      return StreakRepairOutcome.failed;
    }
    final owner = repository.currentUserId;
    if (owner != null &&
        !await _writeIntent(owner, offer, now ?? DateTime.now())) {
      // Niyet kalıcı yazılamadıysa ücretli çağrı BAŞLATILMAZ: yanıt kaybolursa
      // uzlaştıracak kayıt olmazdı. Mevcut "onarılamadı" yolu gösterilir.
      return StreakRepairOutcome.failed;
    }
    final result = await repository.spendStreakRepair(
      monthKey: offer.monthKey,
      breakDay: offer.breakDay,
      // Sunucu p_premium'u yok sayar; abonelik doğrulaması gelene dek hep false.
      premium: false,
    );
    if (result.succeeded) {
      await store.applyRepair(offer, now: now);
    }
    // Niyet yalnız KESİN sonuçta silinir; `failed` (ağ/sunucu belirsiz) kalır.
    if (owner != null && _isDefinite(result.outcome)) {
      await _clearIntent(owner);
    }
    return result.outcome;
  }

  /// Açılışta: ödenmiş ama yerel olarak uygulanamamış onarımı tamamlar.
  /// Sunucu kaydı varsa `alreadyRepaired` döner (ücret yeniden kesilmez);
  /// yoksa ve pencere hâlâ açıksa kullanıcının daha önce verdiği onay
  /// sürdürülür, pencere kapanmışsa sunucu reddeder ve niyet bırakılır.
  /// Seri yerelde uygulandıysa `true`.
  static Future<bool> recoverPending({
    required ZanKurdRepository repository,
    required StreakStore store,
    DateTime? now,
  }) async {
    final owner = repository.currentUserId;
    if (owner == null) return false;
    final intent = await _readIntent(owner);
    if (intent == null) return false;
    final at = now ?? DateTime.now();
    final offeredAt = DateTime.fromMillisecondsSinceEpoch(intent.offeredAtMs);
    final age = at.difference(offeredAt);
    if (age.isNegative || age > intentMaxAge) {
      await _clearIntent(owner);
      return false;
    }
    // Yerel durum hâlâ AYNI kırılmayı gösteriyor mu? Gösteriyorsa onarım henüz
    // uygulanmamıştır. Göstermiyorsa (uygulandı, başka gün oynandı) yerelde
    // yapılacak bir şey yoktur; niyet bırakılır, sunucuya gidilmez.
    final stillBroken = store.repairOffer(now: offeredAt);
    if (stillBroken == null || stillBroken.breakDay != intent.offer.breakDay) {
      await _clearIntent(owner);
      return false;
    }
    final result = await repository.spendStreakRepair(
      monthKey: intent.offer.monthKey,
      breakDay: intent.offer.breakDay,
      premium: false,
    );
    var applied = false;
    if (result.succeeded) {
      // YEREL durumdan yeniden türetilen teklif uygulanır (niyet anındaki
      // değil): o arada bugün oynandıysa `playedToday` değişmiş olabilir.
      await store.applyRepair(stillBroken, now: offeredAt);
      applied = true;
    }
    if (_isDefinite(result.outcome)) await _clearIntent(owner);
    return applied;
  }

  static bool _isDefinite(StreakRepairOutcome outcome) =>
      outcome != StreakRepairOutcome.failed;

  static Future<bool> _writeIntent(
    String owner,
    StreakRepairOffer offer,
    DateTime at,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final key = '$_intentPrefix$owner';
      final encoded = jsonEncode({
        'lostStreak': offer.lostStreak,
        'breakDay': offer.breakDay,
        'monthKey': offer.monthKey,
        'playedToday': offer.playedToday,
        'offeredAtMs': at.millisecondsSinceEpoch,
      });
      return await preferences.setString(key, encoded) &&
          preferences.getString(key) == encoded;
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_repair_intent_write');
      return false;
    }
  }

  static Future<void> _clearIntent(String owner) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove('$_intentPrefix$owner');
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_repair_intent_clear');
    }
  }

  static Future<({StreakRepairOffer offer, int offeredAtMs})?> _readIntent(
    String owner,
  ) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final raw = preferences.getString('$_intentPrefix$owner');
      if (raw == null) return null;
      final map = jsonDecode(raw);
      if (map is Map &&
          map['lostStreak'] is int &&
          map['breakDay'] is String &&
          map['monthKey'] is String &&
          map['playedToday'] is bool &&
          map['offeredAtMs'] is int) {
        return (
          offer: StreakRepairOffer(
            lostStreak: map['lostStreak'] as int,
            breakDay: map['breakDay'] as String,
            monthKey: map['monthKey'] as String,
            playedToday: map['playedToday'] as bool,
          ),
          offeredAtMs: map['offeredAtMs'] as int,
        );
      }
      await _clearIntent(owner); // Bozuk kayıt: tekrar tekrar okunmasın.
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_repair_intent_read');
    }
    return null;
  }
}
