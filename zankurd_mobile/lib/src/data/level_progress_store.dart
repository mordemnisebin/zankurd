import 'package:shared_preferences/shared_preferences.dart';

/// Seviye yolunda hangi düğümlerin oynandığını yerelde tutar.
/// Diğer store'larla aynı kalıp: tekil örnek + resetInstance (test izolasyonu).
class LevelProgressStore {
  LevelProgressStore._(this._prefs);

  static const _key = 'zankurd.level.played';
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

  Future<void> markPlayed(
    String category,
    String? subCategory,
    int level,
  ) async {
    final entries = _played..add(_entry(category, subCategory, level));
    await _prefs.setStringList(_key, entries.toList()..sort());
  }
}
