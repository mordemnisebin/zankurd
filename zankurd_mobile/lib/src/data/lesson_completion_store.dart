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
    return LocalProgressScope.physicalFor(owner, logical);
  }

  static Future<Set<String>> _read(String key) async {
    final preferences = await SharedPreferences.getInstance();
    return (preferences.getStringList(key) ?? const <String>[]).toSet();
  }

  /// Bekleyen ∪ eşitlenmiş kümeyi etkin kullanıcı için okur.
  static Future<Set<String>> loadLocal({String? owner}) async {
    final pendingStorageKey = _key(pendingKey, owner);
    final syncedStorageKey = _key(syncedKey, owner);
    final pending = await _read(pendingStorageKey);
    final synced = await _read(syncedStorageKey);
    return {...synced, ...pending};
  }

  /// Dersi bekleyen kümeye yazar; kalıcı yazım kabul edilmezse `false`.
  static Future<bool> addPending(String lessonId, {String? owner}) async {
    final key = _key(pendingKey, owner);
    final preferences = await SharedPreferences.getInstance();
    final ids = (preferences.getStringList(key) ?? const <String>[]).toSet()
      ..add(lessonId);
    return preferences.setStringList(key, ids.toList()..sort());
  }

  /// Sunucu onayından sonra dersi bekleyenlerden düşer (eşitlenmişe geçer).
  ///
  /// SIRA önemlidir: önce eşitlenmiş hedef KALICI yazılır, sonra bekleyen kayıt
  /// düşer. Eskiden bekleyen önce siliniyor, iki yazının sonucu da
  /// denetlenmiyordu: aradaki kapanma ya da ikinci yazının reddi, sunucuda
  /// tamamlanmış dersin yerel izini kaybettirip çevrimdışı açılışta kilitleri
  /// geri getiriyordu (2026-11-04 denetimi). Yazım reddedilirse fırlatır;
  /// bekleyen kayıt yerinde kalır, ders bir sonraki eşitlemede yeniden onaylanır.
  static Future<void> markSynced(String lessonId, {String? owner}) =>
      _serialized(() async {
        final pendingStorageKey = _key(pendingKey, owner);
        final syncedStorageKey = _key(syncedKey, owner);
        final preferences = await SharedPreferences.getInstance();
        final synced =
            (preferences.getStringList(syncedStorageKey) ?? const <String>[])
                .toSet();
        if (synced.add(lessonId)) {
          final saved = await preferences.setStringList(
            syncedStorageKey,
            synced.toList()..sort(),
          );
          if (!saved) {
            throw StateError('Synced lesson set was not persisted.');
          }
        }
        final pending = preferences.getStringList(pendingStorageKey);
        if (pending != null && pending.contains(lessonId)) {
          final saved = await preferences.setStringList(
            pendingStorageKey,
            [...pending]..remove(lessonId),
          );
          if (!saved) {
            throw StateError('Pending lesson set was not persisted.');
          }
        }
      });

  /// Sunucunun tamamlanmış ders kümesini önbelleğe alır (yalnız değişirse yazar).
  ///
  /// Ders tamamlanması geri alınmaz: sunucu kümesi yereldekinin ÜSTÜNE yazılmaz,
  /// BİRLEŞTİRİLİR. Onaydan önce başlamış eski bir okuma geç dönerse, arada
  /// `markSynced` ile eklenen yeni tamamlama önbellekten silinmez. Aynı sahibin
  /// önbellek yazımları sıraya girer.
  static Future<void> cacheServer(Set<String> serverIds, {String? owner}) =>
      _serialized(() async {
        final key = _key(syncedKey, owner);
        final preferences = await SharedPreferences.getInstance();
        final current = (preferences.getStringList(key) ?? const <String>[])
            .toSet();
        final merged = {...current, ...serverIds};
        if (merged.length == current.length) return;
        final saved = await preferences.setStringList(
          key,
          merged.toList()..sort(),
        );
        if (!saved) throw StateError('Server lesson set was not persisted.');
      });

  static Future<void> _tail = Future<void>.value();

  static Future<void> _serialized(Future<void> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.catchError((Object _) {});
    return next;
  }
}
