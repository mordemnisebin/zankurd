import 'package:shared_preferences/shared_preferences.dart';

/// Yanlış cevaplanan soruların kimliklerini yerelde tutar.
///
/// Yanlış cevap soruyu listeye ekler; doğru cevap (hangi modda olursa
/// olsun) listeden düşürür. "Yanlışlarım" çalışma modu bu listeden
/// beslenir. SharedPreferences yoksa bellek-içi çalışır.
class MistakeStore {
  MistakeStore._(this._preferences, this._ids);

  static const _storageKey = 'zankurd.mistakeQuestionIds';
  static MistakeStore? _instance;

  static Future<MistakeStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final ids = preferences?.getStringList(_storageKey)?.toSet() ?? <String>{};
    return _instance = MistakeStore._(preferences, ids);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  final Set<String> _ids;

  Set<String> get ids => Set.unmodifiable(_ids);
  int get count => _ids.length;
  bool contains(String id) => _ids.contains(id);

  Future<void> markMistake(String id) async {
    if (_ids.add(id)) await _persist();
  }

  Future<void> markResolved(String id) async {
    if (_ids.remove(id)) await _persist();
  }

  Future<void> clear() async {
    _ids.clear();
    await _persist();
  }

  Future<void> _persist() async {
    await _preferences?.setStringList(_storageKey, _ids.toList());
  }
}
