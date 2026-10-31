import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';
import 'progress_sync.dart';
import 'placement_persistence.dart';

import '../services/placement_scoring.dart';
import '../utils/error_reporter.dart';

/// Seviye belirleme sınavının sonucunu yerelde, sürümlü bir anahtarla tutar.
///
/// Sürüm ([_version]) ileride sınav içeriği/eşikleri değişirse temiz bir
/// geçiş sağlar: yeni sürüm eski anahtarı görmez, kullanıcıya (istenirse)
/// yeniden sorulur. Depolama yoksa sonuç kaydı hata verir.
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
    final saved = preferences == null
        ? null
        : PlacementPersistence.read(preferences);
    final level = PlacementLevel.fromStorageKey(saved?.level);
    return PlacementStore._(preferences, level, saved?.skipped ?? false);
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
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('Placement storage is unavailable.');
    }
    await PlacementPersistence.write(preferences, (
      level: level.storageKey,
      skipped: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    _level = level;
    _skipped = false;
    ProgressSyncService.markDirty();
  }

  /// "Şimdilik geç": ilk kullanımda bir daha otomatik sorulmaz.
  Future<void> markSkipped() async {
    final preferences = _preferences;
    if (preferences == null) {
      throw StateError('Placement storage is unavailable.');
    }
    await PlacementPersistence.write(preferences, (
      level: _level?.storageKey,
      skipped: true,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    ));
    _skipped = true;
    ProgressSyncService.markDirty();
  }

  /// Test/temizlik: tüm seviye durumunu sıfırlar.
  Future<void> clear() async {
    await removePersistedPreferenceKeys(_preferences, [
      _levelKey,
      _skippedKey,
      updatedAtKey,
      PlacementPersistence.key('pending'),
    ]);
    _level = null;
    _skipped = false;
  }
}
