import 'package:shared_preferences/shared_preferences.dart';

import '../services/placement_scoring.dart';

/// Seviye belirleme sınavının sonucunu yerelde, sürümlü bir anahtarla tutar.
///
/// Sürüm ([_version]) ileride sınav içeriği/eşikleri değişirse temiz bir
/// geçiş sağlar: yeni sürüm eski anahtarı görmez, kullanıcıya (istenirse)
/// yeniden sorulur. `SharedPreferences` yoksa bellek-içi çalışır.
class PlacementStore {
  PlacementStore._(this._preferences, this._level, this._skipped);

  static const _version = 'v1';
  static const _levelKey = 'zankurd.placement.$_version.level';
  static const _skippedKey = 'zankurd.placement.$_version.skipped';

  static PlacementStore? _instance;

  final SharedPreferences? _preferences;
  PlacementLevel? _level;
  bool _skipped;

  static Future<PlacementStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final level = PlacementLevel.fromStorageKey(
      preferences?.getString(_levelKey),
    );
    final skipped = preferences?.getBool(_skippedKey) ?? false;
    return _instance = PlacementStore._(preferences, level, skipped);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

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
  }

  /// "Şimdilik geç": ilk kullanımda bir daha otomatik sorulmaz.
  Future<void> markSkipped() async {
    _skipped = true;
    await _preferences?.setBool(_skippedKey, true);
  }

  /// Test/temizlik: tüm seviye durumunu sıfırlar.
  Future<void> clear() async {
    _level = null;
    _skipped = false;
    await _preferences?.remove(_levelKey);
    await _preferences?.remove(_skippedKey);
  }
}
