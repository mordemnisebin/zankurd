import 'package:shared_preferences/shared_preferences.dart';

import 'local_progress_scope.dart';

/// Ders tamamlamanın yerel kopyası (kullanıcıya bağlı anahtarlar).
///
/// İki küme tutar:
/// * **bekleyen**: sunucu henüz onaylamadı; `SyncManager` kuyruğuyla birlikte
///   yaşar, onay gelince düşer.
/// * **eşitlenmiş**: sunucudan son okunan tamamlanmış ders kümesi; sunucuya
///   ulaşılamayan açılışta kilitleri doğru tutar.
///
/// Dersin kilit durumu `bekleyen ∪ eşitlenmiş ∪ sunucu` ile hesaplanır.
class LessonCompletionStore {
  LessonCompletionStore._();

  static const pendingKey = 'zankurd.offline.completedLessonIds';
  static const syncedKey = 'zankurd.offline.syncedLessonIds';

  static String _key(String logical, String? owner) {
    if (owner == null) return LocalProgressScope.physical(logical);
    if (LocalProgressScope.activeUserId == null) return logical;
    return LocalProgressScope.physicalFor(owner, logical);
  }

  static Future<Set<String>> _read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(key) ?? const <String>[]).toSet();
  }

  /// Bekleyen ∪ eşitlenmiş kümeyi etkin kullanıcı için okur.
  static Future<Set<String>> loadLocal() async {
    final pending = await _read(_key(pendingKey, null));
    final synced = await _read(_key(syncedKey, null));
    return {...synced, ...pending};
  }

  /// Dersi bekleyen kümeye yazar; kalıcı yazım kabul edilmezse `false`.
  static Future<bool> addPending(String lessonId, {String? owner}) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(pendingKey, owner);
    final ids = (preferences.getStringList(key) ?? const <String>[]).toSet()
      ..add(lessonId);
    return preferences.setStringList(key, ids.toList()..sort());
  }

  /// Sunucu onayından sonra dersi bekleyenlerden düşer (eşitlenmişe geçer).
  static Future<void> markSynced(String lessonId, {String? owner}) async {
    final preferences = await SharedPreferences.getInstance();
    final pendingStorageKey = _key(pendingKey, owner);
    final pending = preferences.getStringList(pendingStorageKey);
    if (pending != null && pending.contains(lessonId)) {
      await preferences.setStringList(
        pendingStorageKey,
        [...pending]..remove(lessonId),
      );
    }
    final syncedStorageKey = _key(syncedKey, owner);
    final synced =
        (preferences.getStringList(syncedStorageKey) ?? const <String>[])
            .toSet();
    if (synced.add(lessonId)) {
      await preferences.setStringList(
        syncedStorageKey,
        synced.toList()..sort(),
      );
    }
  }

  /// Sunucunun tamamlanmış ders kümesini önbelleğe alır (yalnız değişirse yazar).
  static Future<void> cacheServer(Set<String> serverIds) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(syncedKey, null);
    final current = (preferences.getStringList(key) ?? const <String>[])
        .toSet();
    if (current.length == serverIds.length && current.containsAll(serverIds)) {
      return;
    }
    await preferences.setStringList(key, serverIds.toList()..sort());
  }
}
