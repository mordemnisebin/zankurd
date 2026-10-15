import 'package:shared_preferences/shared_preferences.dart';
import 'checked_preferences_removal.dart';
import 'local_progress_scope.dart';

/// Seviye yolunda hangi düğümlerin oynandığını yerelde tutar.
/// Diğer store'larla aynı kalıp: tekil örnek + resetInstance (test izolasyonu).
class LevelProgressStore {
  LevelProgressStore._(this._prefs);

  static String get _key => LocalProgressScope.physical('zankurd.level.played');
  static LevelProgressStore? _instance;

  final SharedPreferences _prefs;

  static Future<LevelProgressStore> load() async {
    return _instance ??= LevelProgressStore._(
      await SharedPreferences.getInstance(),
    );
  }

  static void resetInstance() => _instance = null;

  static String _entry(String category, String? subCategory, int level) =>
      '$category|${subCategory ?? '-'}|$level';

  Set<String> get _played => (_prefs.getStringList(_key) ?? const []).toSet();

  bool isPlayed(String category, String? subCategory, int level) =>
      _played.contains(_entry(category, subCategory, level));

  /// Seviyeyi geçmek için gereken doğru oranı.
  static const double passRatio = 0.6;

  /// [correct]/[total] seviyeyi geçmeye yeter mi. Toplam bilinmiyorsa (0)
  /// oyuncu cezalandırılmaz.
  static bool passes(int correct, int total) =>
      total <= 0 || correct >= (total * passRatio).ceil();

  static String _attempt(String category, String? subCategory, int level) =>
      '${_entry(category, subCategory, level)}|denendi';

  /// Seviye denendi ama geçilmedi (eşiğin altında bitti).
  bool isAttempted(String category, String? subCategory, int level) =>
      _played.contains(_attempt(category, subCategory, level));

  /// Biten turun sonucunu işler; seviye GEÇİLDİYSE `true` döner.
  ///
  /// Geçilmeyen tur yalnız "denendi" olarak kaydedilir: altın yıldız ve bir
  /// sonraki seviyenin kilidi geçme şartına bağlıdır. Eski kayıtlar (eşik
  /// öncesi `markPlayed` ile yazılanlar) geçilmiş sayılmaya devam eder.
  Future<bool> recordResult(
    String category,
    String? subCategory,
    int level, {
    required int correct,
    required int total,
  }) async {
    if (passes(correct, total)) {
      await markPlayed(category, subCategory, level);
      return true;
    }
    final entries = _played..add(_attempt(category, subCategory, level));
    await _prefs.setStringList(_key, entries.toList()..sort());
    return false;
  }

  Future<void> markPlayed(
    String category,
    String? subCategory,
    int level,
  ) async {
    final entries = _played..add(_entry(category, subCategory, level));
    await _prefs.setStringList(_key, entries.toList()..sort());
  }

  /// Hesap değişiminde önceki kullanıcının seviye geçmişini temizler.
  Future<void> clear() => removePersistedPreferenceKeys(_prefs, [_key]);
}
