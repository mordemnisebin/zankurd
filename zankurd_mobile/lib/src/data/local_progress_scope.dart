import 'package:shared_preferences/shared_preferences.dart';

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
  };

  static const prefixes = <String>[
    'zankurd.streak.',
    'zankurd.mastery.',
    'zankurd.masteryAnswered.',
    'zankurd.masteryEvidenceCorrect.',
    'zankurd.missions.',
    'zankurd.achievements.',
    'zankurd.placement.',
    'zankurd.story.',
    'zankurd.offline.',
  ];

  static String? _activeUserId;
  static Future<bool>? _migration;

  static String? get activeUserId => _activeUserId;

  static void bind(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'Boş olamaz.');
    }
    _activeUserId = normalized;
  }

  static void debugReset() {
    _activeUserId = null;
    _migration = null;
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
    if (key == ownerKey || key == migratedKey) return false;
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
      if (preferences.getString(migratedKey) != null) return true;
      final owner = preferences.getString(ownerKey);
      final inheritTo = isHumanOwner(owner) ? owner!.trim() : incoming;
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
      return preferences.setString(migratedKey, inheritTo);
    } catch (_) {
      try {
        await preferences.reload();
      } catch (_) {}
      return false;
    }
  }

  static String physicalFor(String userId, String logical) =>
      '$_scopePrefix${userId.trim()}.$logical';

  /// İnsan sahip varsa onun alanına bağlanır. Yoksa genel anahtarlar
  /// görünür kalır ve ilk gerçek giriş onları devralabilsin diye sentinel
  /// yazılır.
  static Future<bool> activateOffline(SharedPreferences preferences) async {
    await preferences.reload();
    final owner = preferences.getString(ownerKey);
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
