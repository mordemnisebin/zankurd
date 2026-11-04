import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:shared_preferences/shared_preferences.dart';

import 'result_progress_journal.dart';

/// Yerel ilerlemeyi kullanıcı kimliğine bağlar.
///
/// Eski kurulumlar genel anahtar kullanır (`zankurd.xp.total`). İlk gerçek
/// kullanıcı bu anahtarları devralır; kayıtlı insan sahip varsa devralan
/// odur. `device-offline` insan sahip değildir: ağ yokken yazılan genel
/// anahtarlar, ilk gerçek girişe kadar görünür kalır ve ona taşınır.
///
/// Kapsam bağlı değilken okuma ve yazma genel anahtardadır. Böylece kapsam
/// açılmadan koşan testler ve henüz girişi olmayan çevrimdışı oturum bozulmaz.
class LocalProgressScope {
  LocalProgressScope._();

  static const ownerKey = 'zankurd.localProgress.deviceOwnerUserId';
  static const migratedKey = 'zankurd.localProgress.legacyMigratedTo';

  /// Genel anahtar göçünün KALICI niyeti: ilk anahtar taşınmadan önce hedef
  /// hesap yazılır; yeniden denemeler hep aynı hedefe gider. Eskiden hedef
  /// ancak bütün taşıma bitince kaydediliyordu: bazı anahtarlar A'ya taşınıp
  /// silindikten sonra uygulama kapanırsa sonraki B girişi kalanları B'ye
  /// taşıyıp tek misafir ilerlemesini iki hesaba bölüyordu (2026-11-04).
  static const migratingKey = 'zankurd.localProgress.legacyMigratingTo';
  static const offlineUserId = 'device-offline';
  static const _scopePrefix = 'zankurd.scope.';

  static const exactKeys = <String>{
    'zankurd.xp.total',
    'zankurd.mistakeQuestionIds',
    'zankurd.mistakeMetadata',
    'zankurd.dailyPerformance',
    'zankurd.seenQuestionIds',
    'zankurd.badges.unlocked',
    'zankurd.level.played',
    'zankurd.learning_goal.v1',
    'zankurd.storyMeta.v1',
    'zankurd.wordList.v1',
    ..._secondGenerationKeys,
  };

  /// İlk göç listesinde unutulan anahtarlar: bekleyen avatar değişikliği ve
  /// rozet tarihleri. İlk göçü ZATEN geçmiş kurulumlar için ayrıca bir kez
  /// (`legacyMigratedV2`) devralana taşınır.
  static const _secondGenerationKeys = <String>{
    'zankurd.avatarIdentity',
    'zankurd.avatarIdentity.dirtyPending',
    'zankurd.badges.unlockedAt',
  };
  static const migratedV2Key = 'zankurd.localProgress.legacyMigratedV2';

  static const prefixes = <String>[
    'zankurd.xp.total.resultJournal.',
    'zankurd.streak.',
    'zankurd.contest.',
    'zankurd.mastery.',
    'zankurd.masteryAnswered.',
    'zankurd.masteryEvidenceCorrect.',
    'zankurd.missions.',
    'zankurd.achievements.',
    'zankurd.placement.',
    'zankurd.story.',
    'zankurd.offline.',
  ];

  /// Buluttan birleştirme (ya da hesap sınırı) yerel ilerlemeyi DEĞİŞTİRDİ:
  /// bellek örnekleri atıldı. Açık ekranlar (Kelimelerim, Ana ekran...)
  /// elindeki eski nesneyi bırakıp diskten yeniden okumak için dinler;
  /// yoksa uzak ilerleme ekranda eski kalıyordu (2026-11-04 denetimi).
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static String? _activeUserId;
  static int _generation = 0;
  static int get generation => _generation;

  /// Auth geçişi, yerel kapsamın asenkron hazırlanmasından önce eski işleri iptal eder.
  static void invalidateSession() => _generation++;
  static Future<bool>? _migration;

  static String? get activeUserId => _activeUserId;

  static bool _forceOffline = false;

  /// Normal çıkışta sahip anahtarı `device-offline`a yazılamadıysa, diskte
  /// kalan çıkmış hesabın sahipliği bu süreçte çevrimdışı oturuma
  /// bağlanmaz: bir sonraki gerçek `bind` (giriş) bayrağı düşürür.
  static void forceOfflineScope() => _forceOffline = true;

  static void bind(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Boş olamaz.');
    }
    if (normalized != offlineUserId) _forceOffline = false;
    if (_activeUserId != normalized) _generation++;
    _activeUserId = normalized;
  }

  static void debugReset() {
    _activeUserId = null;
    _generation++;
    _migration = null;
    _forceOffline = false;
  }

  static String physical(String logical) {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) return logical;
    return '$_scopePrefix$userId.$logical';
  }

  static bool isHumanOwner(String? owner) {
    final value = owner?.trim();
    return value != null && value.isNotEmpty && value != offlineUserId;
  }

  static bool isLegacyProgressKey(String key) {
    if (key.startsWith(_scopePrefix)) return false;
    if (key == ownerKey ||
        key == migratedKey ||
        key == migratedV2Key ||
        key == migratingKey) {
      return false;
    }
    if (exactKeys.contains(key)) return true;
    for (final prefix in prefixes) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Genel anahtarları devralana kopyalar ve genel kopyayı siler.
  ///
  /// Silme kabul edilmezse işaret yazılmaz; çağıran sahip kaydını güncellemez.
  static Future<bool> migrateLegacy(
    SharedPreferences preferences, {
    required String incomingUserId,
  }) {
    final inFlight = _migration;
    if (inFlight != null) return inFlight;
    final flight = _migrateLegacy(preferences, incomingUserId: incomingUserId);
    _migration = flight;
    return flight.whenComplete(() {
      if (identical(_migration, flight)) _migration = null;
    });
  }

  static Future<bool> _migrateLegacy(
    SharedPreferences preferences, {
    required String incomingUserId,
  }) async {
    final incoming = incomingUserId.trim();
    if (incoming.isEmpty || incoming == offlineUserId) return false;
    try {
      await preferences.reload();
      final migratedTo = preferences.getString(migratedKey);
      if (migratedTo != null) {
        return _migrateSecondGeneration(preferences, migratedTo);
      }
      // Prepared günlüklerin hedefleri eski fiziksel anahtarlardır. Önce
      // tamamla; yalnız done kayıtları ve tamamlanmış değerler taşınsın.
      for (final namespace in [
        'zankurd.xp.total.resultJournal',
        'zankurd.achievements.resultJournal',
        'zankurd.achievements.masteryResultJournal',
        'zankurd.missions.resultJournal',
      ]) {
        await ResultProgressJournal.recover(
          preferences: preferences,
          namespace: namespace,
        );
      }
      final owner = preferences.getString(ownerKey);
      final intent = preferences.getString(migratingKey)?.trim();
      final inheritTo = intent != null && intent.isNotEmpty
          ? intent
          : (isHumanOwner(owner) ? owner!.trim() : incoming);
      if (intent != inheritTo &&
          !await preferences.setString(migratingKey, inheritTo)) {
        return false;
      }
      final keys = preferences
          .getKeys()
          .where(isLegacyProgressKey)
          .toList(growable: false);
      for (final key in keys) {
        final value = preferences.get(key);
        if (value == null) continue;
        final saved = await _write(
          preferences,
          physicalFor(inheritTo, key),
          value,
        );
        if (!saved) return false;
        if (!await preferences.remove(key)) return false;
      }
      if (!await preferences.setString(migratedKey, inheritTo)) return false;
      await preferences.remove(migratingKey);
      return true;
    } catch (_) {
      try {
        await preferences.reload();
      } catch (_) {}
      return false;
    }
  }

  /// Bir hesabın cihazdaki BÜTÜN kalıcı kayıtlarını tanıyan önekler: kapsamlı
  /// ilerleme (`zankurd.scope.<uid>.`: kelime listesi, ders kümeleri, çevrimdışı
  /// favoriler, profil adı, avatar kimliği ve bekleyen bayrağı, rozet
  /// tarihleri...), sonuç makbuzları, sohbet susturma listesi ve isim kapısı
  /// bayrağı. Hesap silmede tek tek depo sayılmaz; liste burada TEK yerde
  /// durur (elle sıralı temizlik yeni anahtarları unutuyordu).
  static List<String> userOwnedKeyPrefixes(String userId) {
    final uid = userId.trim();
    return [
      '$_scopePrefix$uid.',
      'zankurd.quiz_result_progress_receipt.$uid:',
      'chat_muted_v1_$uid',
      'zankurd.profileName.completed.$uid',
      // Bozuk günlük girdilerinin karantinası: ad alanı kapsamlı anahtardır
      // (`zankurd.scope.<uid>....`), karantina onu öne ekler.
      'zankurd.quarantine.$_scopePrefix$uid.',
    ];
  }

  /// Sahip kimliği SONA eklenen kalıcı kayıtlar: bekleyen işlem niyetleri
  /// (`zankurd.pendingOp.<tür>.<uid>`; çark, düello, seri onarımı...).
  static bool _isOwnerSuffixedKey(String key, String uid) =>
      key.startsWith('zankurd.pendingOp.') && key.endsWith('.$uid');

  /// Yalnız [userId]'ye ait kayıtları siler (başka hesaplara dokunmaz) ve her
  /// silmenin kalıcı olduğunu doğrular; olmazsa fırlatır.
  static Future<void> clearUserOwnedKeys(
    SharedPreferences preferences,
    String userId,
  ) async {
    if (userId.trim().isEmpty || userId.trim() == offlineUserId) return;
    await preferences.reload();
    final prefixes = userOwnedKeyPrefixes(userId);
    final keys = preferences
        .getKeys()
        .where(
          (key) =>
              prefixes.any(key.startsWith) ||
              _isOwnerSuffixedKey(key, userId.trim()),
        )
        .toList(growable: false);
    try {
      for (final key in keys) {
        if (!await preferences.remove(key)) {
          throw StateError('Account key removal was not persisted.');
        }
      }
    } catch (_) {
      await preferences.reload();
      rethrow;
    }
  }

  static Future<bool> _migrateSecondGeneration(
    SharedPreferences preferences,
    String inheritedBy,
  ) async {
    if (preferences.getString(migratedV2Key) != null) return true;
    final owner = inheritedBy.trim();
    if (owner.isEmpty) return true;
    for (final key in _secondGenerationKeys) {
      if (!preferences.containsKey(key)) continue;
      final target = physicalFor(owner, key);
      // Devralanın kendi (daha yeni) kaydı varsa ezilmez; genel kopya düşer.
      if (!preferences.containsKey(target)) {
        final value = preferences.get(key);
        if (value != null && !await _write(preferences, target, value)) {
          return false;
        }
      }
      if (!await preferences.remove(key)) return false;
    }
    return preferences.setString(migratedV2Key, owner);
  }

  static String physicalFor(String userId, String logical) =>
      '$_scopePrefix${userId.trim()}.$logical';

  /// İnsan sahip varsa onun alanına bağlanır. Yoksa genel anahtarlar
  /// görünür kalır ve ilk gerçek giriş onları devralabilsin diye sentinel
  /// yazılır.
  static Future<bool> activateOffline(SharedPreferences preferences) async {
    await preferences.reload();
    final owner = preferences.getString(ownerKey);
    if (_forceOffline && preferences.getString(migratedKey) != null) {
      bind(offlineUserId);
      return true;
    }
    if (isHumanOwner(owner)) {
      bind(owner!.trim());
      return true;
    }
    // İlk taşıma bitmeden genel anahtarlar görünür kalır; ilk gerçek giriş
    // onları devralır. Taşıma bittiyse sahipsiz oturum sentinel alanına
    // yazar, sonraki hesabın genel anahtarına karışmaz.
    if (preferences.getString(migratedKey) != null) {
      bind(offlineUserId);
      if (owner == null || owner.trim().isEmpty) {
        return preferences.setString(ownerKey, offlineUserId);
      }
      return true;
    }
    _activeUserId = null;
    _generation++;
    if (owner == null || owner.trim().isEmpty) {
      return preferences.setString(ownerKey, offlineUserId);
    }
    return true;
  }

  static Future<bool> _write(
    SharedPreferences preferences,
    String key,
    Object value,
  ) async {
    if (value is int) return preferences.setInt(key, value);
    if (value is bool) return preferences.setBool(key, value);
    if (value is double) return preferences.setDouble(key, value);
    if (value is String) return preferences.setString(key, value);
    if (value is List<String>) return preferences.setStringList(key, value);
    if (value is List) {
      return preferences.setStringList(
        key,
        value.map((item) => '$item').toList(growable: false),
      );
    }
    return false;
  }
}
