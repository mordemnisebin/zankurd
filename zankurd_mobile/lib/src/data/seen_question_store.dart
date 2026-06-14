import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_question.dart';

/// Oyuncunun gördüğü soruları yerelde izler ve yeni seçimlerde
/// görülmemiş soruları öne alır; böylece aynı sorular kısa sürede
/// tekrar karşısına çıkmaz.
///
/// Havuzdaki tüm sorular görüldüğünde o havuzun izleri sıfırlanır ve
/// tur baştan başlar. SharedPreferences erişilemiyorsa (test/desteksiz
/// platform) bellek-içi çalışır.
class SeenQuestionStore {
  SeenQuestionStore._(this._preferences, this._seen);

  static const _storageKey = 'zankurd.seenQuestionIds';
  static SeenQuestionStore? _instance;

  static Future<SeenQuestionStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (_) {
      preferences = null;
    }
    final seen = preferences?.getStringList(_storageKey)?.toSet() ?? <String>{};
    return _instance = SeenQuestionStore._(preferences, seen);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  final Set<String> _seen;

  bool isSeen(String id) => _seen.contains(id);
  int get seenCount => _seen.length;

  Future<void> markSeen(Iterable<String> ids) async {
    _seen.addAll(ids);
    await _persist();
  }

  Future<void> clear() async {
    _seen.clear();
    await _persist();
  }

  /// Havuzdan [limit] soru seçer; görülmemişler önceliklidir ve
  /// rastgele sıralanır. Görülmemiş soru yetmezse görülenlerle
  /// tamamlanır. Havuzun tamamı görülmüşse havuza ait izler silinir
  /// ve havuzdan rastgele seçim yapılır.
  List<QuizQuestion> preferUnseen(
    List<QuizQuestion> pool,
    int limit, {
    Random? random,
  }) {
    if (pool.isEmpty || limit <= 0) return const [];

    final unseen = pool.where((q) => !_seen.contains(q.id)).toList();
    if (unseen.isEmpty) {
      _seen.removeAll(pool.map((q) => q.id));
      _persist();
      final recycled = [...pool]..shuffle(random);
      return recycled.take(limit).toList(growable: false);
    }

    unseen.shuffle(random);
    if (unseen.length >= limit) {
      return unseen.take(limit).toList(growable: false);
    }

    final seenFill = pool.where((q) => _seen.contains(q.id)).toList()
      ..shuffle(random);
    return [...unseen, ...seenFill.take(limit - unseen.length)];
  }

  Future<void> _persist() async {
    await _preferences?.setStringList(_storageKey, _seen.toList());
  }
}
