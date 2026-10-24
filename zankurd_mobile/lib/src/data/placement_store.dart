import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'progress_sync.dart';

import '../services/placement_scoring.dart';
import '../utils/error_reporter.dart';

/// Seviye belirleme sınavının sonucunu yerelde, sürümlü bir anahtarla tutar.
///
/// Sürüm ([_version]) ileride sınav içeriği/eşikleri değişirse temiz bir
/// geçiş sağlar: yeni sürüm eski anahtarı görmez, kullanıcıya (istenirse)
/// yeniden sorulur. `SharedPreferences` yoksa bellek-içi çalışır.
class PlacementStore {
  PlacementStore._(this._preferences, this._level, this._skipped);

  static const _version = 'v1';
  static String get _levelKey =>
      LocalProgressScope.physical('zankurd.placement.$_version.level');

  /// Son yazım zamanı (ms); eşitleme "en son yazan kazanır" der.
  static String get updatedAtKey =>
      LocalProgressScope.physical('zankurd.placement.$_version.updatedAt');
  static String get _skippedKey =>
      LocalProgressScope.physical('zankurd.placement.$_version.skipped');

  static PlacementStore? _instance;
  static Future<PlacementStore>? _loading;
  static int _loadGeneration = 0;

  final SharedPreferences? _preferences;
  PlacementLevel? _level;
  bool _skipped;

  static Future<PlacementStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    final inFlight = _loading;
    if (inFlight != null) return inFlight;

    final generation = _loadGeneration;
    final loading = _loadFresh().then((store) {
      if (_loadGeneration == generation) {
        return _instance ??= store;
      }
      return store;
    });
    _loading = loading;
    try {
      return await loading;
    } finally {
      if (identical(_loading, loading)) _loading = null;
    }
  }

  static Future<PlacementStore> _loadFresh() async {
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'placement_store');
      preferences = null;
    }
    final level = PlacementLevel.fromStorageKey(
      preferences?.getString(_levelKey),
    );
    final skipped = preferences?.getBool(_skippedKey) ?? false;
    return PlacementStore._(preferences, level, skipped);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() {
    _loadGeneration++;
    _instance = null;
    _loading = null;
  }

  /// Belirlenmiş seviye; henüz sınav tamamlanmadıysa null.
  PlacementLevel? get level => _level;

  /// Sınav tamamlandı (bir seviye kaydedildi) mi.
  bool get completed => _level != null;

  /// Kullanıcı "şimdilik geç" dedi mi.
  bool get skipped => _skipped;

  /// İlk kullanımda sınavı sun: henüz tamamlanmadı ve geçilmediyse.
  bool get shouldPrompt => _level == null && !_skipped;

  /// Sınav tamamlandığında sonucu yazar. Yeniden sınav da bunu kullanır
  /// (öncekini ezer). Geç işaretini de temizler.
  Future<void> saveResult(PlacementLevel level) async {
    _level = level;
    _skipped = false;
    await _preferences?.setString(_levelKey, level.storageKey);
    await _preferences?.remove(_skippedKey);
    await _stamp();
  }

  Future<void> _stamp() async {
    await _preferences?.setInt(
      updatedAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
    ProgressSyncService.markDirty();
  }

  /// "Şimdilik geç": ilk kullanımda bir daha otomatik sorulmaz.
  Future<void> markSkipped() async {
    _skipped = true;
    await _preferences?.setBool(_skippedKey, true);
    await _stamp();
  }

  /// Test/temizlik: tüm seviye durumunu sıfırlar.
  Future<void> clear() async {
    await removePersistedPreferenceKeys(_preferences, [
      _levelKey,
      _skippedKey,
      updatedAtKey,
    ]);
    _level = null;
    _skipped = false;
  }
}
