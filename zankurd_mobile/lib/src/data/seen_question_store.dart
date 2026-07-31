import 'dart:collection';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quiz_question.dart';
import '../utils/error_reporter.dart';

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

  /// Kümedeki en fazla kimlik sayısı — EN ESKİ olanlar düşer (FIFO).
  ///
  /// Küme bugün pratikte banka boyutuyla (~1.832) sınırlı: havuz tükendiğinde
  /// `preferUnseen` o havuzun izlerini siliyor. Ama bu bir tesadüf, kural
  /// değil — banka büyüdükçe ya da sunucudan soru gelmeye başladıkça sayı
  /// serbestçe artar ve her `markSeen` çağrısı listenin TAMAMINI diske
  /// yeniden yazar (2026-07-31 denetimi).
  ///
  /// 3.000 bilerek bugünkü bankanın üstünde: davranış aynı kalıyor, yalnız
  /// tavan yazılı hâle geliyor.
  static const _maxTrackedIds = 3000;

  static SeenQuestionStore? _instance;

  static Future<SeenQuestionStore> load() async {
    final cached = _instance;
    if (cached != null) return cached;
    SharedPreferences? preferences;
    try {
      preferences = await SharedPreferences.getInstance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'seen_question_store');
      preferences = null;
    }
    // `LinkedHashSet` ekleme sırasını korur; budama en eskiden başlar.
    final stored = preferences?.getStringList(_storageKey) ?? const <String>[];
    final seen = LinkedHashSet<String>.of(stored);
    return _instance = SeenQuestionStore._(preferences, seen);
  }

  /// Testlerde tekil örneği sıfırlamak için.
  static void resetInstance() => _instance = null;

  final SharedPreferences? _preferences;
  final LinkedHashSet<String> _seen;

  bool isSeen(String id) => _seen.contains(id);
  int get seenCount => _seen.length;

  Future<void> markSeen(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    _seen.addAll(ids);
    _trim();
    await _persist();
  }

  /// Tavanı aşan en eski kimlikleri düşürür.
  ///
  /// En eski görülen soru, tekrar gösterilmesi en zararsız olandır: aradan
  /// en çok zaman geçmiştir.
  void _trim() {
    if (_seen.length <= _maxTrackedIds) return;
    final excess = _seen.length - _maxTrackedIds;
    final oldest = _seen.take(excess).toList(growable: false);
    _seen.removeAll(oldest);
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
    List<QuizQuestion> rawPool,
    int limit, {
    Random? random,
  }) {
    if (rawPool.isEmpty || limit <= 0) return const [];

    // Soru bankası, aynı sorunun farklı zorluk katmanlarını ayrı kayıt
    // (farklı id) olarak tutar. Aynı prompt'un birden çok kopyası tek bir
    // seçimde/quizde tekrar olarak görünmesin diye prompt'a göre tekilleştir;
    // her benzersiz prompt'tan ilk kopyayı koru.
    final pool = _dedupeByPrompt(rawPool);

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

  /// Aynı prompt'a sahip kopyalardan yalnızca ilkini tutar; sıra korunur.
  static List<QuizQuestion> _dedupeByPrompt(List<QuizQuestion> pool) {
    final seenPrompts = <String>{};
    final result = <QuizQuestion>[];
    for (final question in pool) {
      if (seenPrompts.add(question.prompt.trim())) {
        result.add(question);
      }
    }
    return result;
  }

  Future<void> _persist() async {
    await _preferences?.setStringList(_storageKey, _seen.toList());
  }
}
