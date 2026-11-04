import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_progress_write_lock.dart';
import 'progress_snapshot.dart';

/// Seri dondurma jetonunun cihaz DEFTERİ (yerel yarısı).
///
/// ## Niçin var
///
/// Bakiye eskiden `zankurd.streak.freeze` adlı tek bir MUTLAK sayıydı ve
/// bulutta "son zaman damgalı kazanır" kuralıyla birleşiyordu. İki cihaz aynı
/// sıfır bakiyeden birer jeton satın alınca ikisi de yerelde `1` yazıyor,
/// birleşimde `1` kalıyor ve iki ödemeye karşı tek jeton kalıyordu (GPT-6 Pro
/// ALAN 5, 2026-11-04). Şimdi her işlem bu cihazın defter satırına +1
/// eklenir ([record]); satırlar yalnız artar, bulutta cihaz başına en büyük
/// sayaç alınır (`SnapshotStreak`), bakiye `taban + kazanılan − harcanan`dır.
///
/// ## Depolama
///
/// * `zankurd.streak.freezeBase`: defter öncesi mutlak bakiye. Anahtarın
///   VARLIĞI "bu hesap defter modunda" demektir; ilk işlemde o ana dek
///   görünen bakiye taban olarak yazılır.
/// * `zankurd.streak.freezeLedger`: `{cihaz: [kazanılan, harcanan]}` JSON.
/// * `zankurd.streak.freeze` (eski mutlak sayı) yalnız aynadır: eski kodun
///   okuduğu yer. Defter modunda GERÇEK bakiye defterdendir ([effective]);
///   ayna yazımı yarıda kalırsa bile bakiye doğru kalır.
///
/// Anahtarlar `zankurd.streak.` önekinde olduğundan kullanıcı kapsamına,
/// hesap silme temizliğine ve genel anahtar göçüne kendiliğinden girer.
/// Cihaz kimliği ise hesaba değil kuruluma aittir ([deviceKey]); kapsamlı
/// değildir ve hesap silinse de durur (içinde kişisel veri yok).
class FreezeLedger {
  const FreezeLedger._();

  static const _baseLogical = 'zankurd.streak.freezeBase';
  static const _ledgerLogical = 'zankurd.streak.freezeLedger';

  /// Kuruluma ait rastgele cihaz kimliği (kullanıcı kapsamlı DEĞİL).
  static const deviceKey = 'zankurd.device.freezeId.v1';

  static String get baseKey => LocalProgressWriteLock.physical(_baseLogical);
  static String get ledgerKey =>
      LocalProgressWriteLock.physical(_ledgerLogical);

  /// Süreç içi yedek kimlik: depolama hiç yazılamıyorsa bile tek süreçte
  /// kararlı kalır (sayaçlar zaten cihaz başına kimlik başına artar; yeni bir
  /// kimlik yalnız ek satır demektir, kayıp değil).
  static String? _memoryId;

  static String _newId() {
    final random = Random.secure();
    return List.generate(
      12,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  /// Bu kurulumun defter kimliği; yoksa üretilip kalıcılaştırılır.
  static Future<String> deviceId(SharedPreferences preferences) async {
    final existing = preferences.getString(deviceKey);
    if (existing != null && existing.isNotEmpty && existing.length <= 40) {
      return existing;
    }
    final fresh = _memoryId ?? _newId();
    _memoryId = fresh;
    try {
      await preferences.setString(deviceKey, fresh);
    } catch (_) {
      // Yazılamadı: süreç kimliği kullanılır.
    }
    return fresh;
  }

  /// Test için süreç içi kimliği unut.
  static void debugReset() => _memoryId = null;

  static int? readBase(SharedPreferences preferences) {
    final value = preferences.get(baseKey);
    return value is int && value >= 0 ? value : null;
  }

  static Map<String, SnapshotFreezeEntry> readLedger(
    SharedPreferences preferences,
  ) {
    final raw = preferences.getString(ledgerKey);
    if (raw == null) return const {};
    try {
      return SnapshotFreezeEntry.mapFrom(jsonDecode(raw));
    } catch (_) {
      return const {};
    }
  }

  /// Ledger'ın JSON hâli (yazım ve karşılaştırma için kararlı).
  static String encodeLedger(Map<String, SnapshotFreezeEntry> ledger) =>
      jsonEncode({
        for (final key in ledger.keys.toList()..sort())
          key: [ledger[key]!.gained, ledger[key]!.spent],
      });

  /// Etkin bakiye: defter modundaysa defterden, değilse [fallback] (eski
  /// mutlak sayı).
  static int effective(SharedPreferences preferences, {required int fallback}) {
    final base = readBase(preferences);
    if (base == null) return fallback;
    return SnapshotStreak.balanceOf(base, readLedger(preferences));
  }

  /// Bu cihazın satırına bir işlem yazar ve YENİ etkin bakiyeyi döner.
  /// [current] işlemden önceki görünen bakiyedir (defter modunda değilse
  /// taban olur). Çağıran [LocalProgressWriteLock] altında olmalıdır.
  static Future<int> record(
    SharedPreferences preferences, {
    required bool gained,
    required int current,
  }) async {
    final base = readBase(preferences) ?? current;
    final ledger = Map<String, SnapshotFreezeEntry>.of(readLedger(preferences));
    final id = await deviceId(preferences);
    final row = ledger[id] ?? const SnapshotFreezeEntry();
    ledger[id] = gained
        ? SnapshotFreezeEntry(gained: row.gained + 1, spent: row.spent)
        : SnapshotFreezeEntry(gained: row.gained, spent: row.spent + 1);
    // Önce taban, sonra defter: taban yazılıp defter yazılamazsa bakiye
    // değişmemiş kalır ve aynı işlem güvenle yeniden denenir. (Ters sırada
    // defter satırı taban olmadan kalır; yeniden deneme satırı ikinci kez
    // artırıp tek işlemi iki sayardı.)
    // İki yazımın SONUCU denetlenir; başarısızlık başarı sayılmaz (çağıran
    // jeton verilmedi bilir, ödeme anahtarıyla yeniden dener) ve taban yazımı
    // diskte geri alınır: yarım yazım bir sonraki okumada jetonu yutmasın.
    final previousBase = preferences.get(baseKey);
    var baseChanged = false;
    Future<void> rollbackBase() async {
      try {
        if (!baseChanged) return;
        if (previousBase is int) {
          await preferences.setInt(baseKey, previousBase);
        } else {
          await preferences.remove(baseKey);
        }
      } catch (_) {}
      try {
        await preferences.reload();
      } catch (_) {}
    }

    try {
      if (previousBase != base) {
        if (!await preferences.setInt(baseKey, base)) {
          throw StateError('Freeze ledger base was not persisted.');
        }
        baseChanged = true;
      }
      if (!await preferences.setString(ledgerKey, encodeLedger(ledger))) {
        throw StateError('Freeze ledger was not persisted.');
      }
    } catch (_) {
      await rollbackBase();
      rethrow;
    }
    return SnapshotStreak.balanceOf(base, ledger);
  }
}
