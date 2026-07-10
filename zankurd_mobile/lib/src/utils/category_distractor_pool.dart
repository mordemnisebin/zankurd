import '../models/quiz_question.dart';

/// Kategori-havuzlu çeldirici yeniden üretimi.
///
/// Sorun: şablon üretimde çeldiriciler bazen alakasız karışıyor
/// (Ziman sorusunda "Yumurta"/"Kırmızı" gibi).
///
/// Çözüm: her kategori için doğru cevap metinlerinden bir havuz kur;
/// her soruda doğru cevabı koru, diğer şıkları aynı kategoriden
/// (ve mümkünse benzer uzunlukta) rastgele/deterministik doldur.
///
/// Bu sınıf salt saf fonksiyondur — bankayı yerinde yazmaz; tool veya
/// SQL üreticisi çıktıyı uygular.
class CategoryDistractorPool {
  CategoryDistractorPool(this.questions, {this.seed = 42});

  final List<QuizQuestion> questions;
  final int seed;

  /// Kategori → o kategorideki doğru cevap metinleri (normalize + tekil).
  Map<String, List<String>> buildPools() {
    final pools = <String, Set<String>>{};
    for (final q in questions) {
      if (q.type == QuestionType.trueFalse) continue;
      final correct = q.correctAnswer.trim();
      if (correct.isEmpty) continue;
      pools.putIfAbsent(q.category, () => <String>{}).add(correct);
    }
    return {
      for (final e in pools.entries)
        e.key: e.value.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())),
    };
  }

  /// Tek soru için yeni şık listesi.
  /// Doğru cevap korunur; diğer şıklar kategori havuzundan seçilir.
  /// Havuz yetersizse mevcut çeldiriciler doldurma olarak kalır.
  List<String> rebuildAnswers(QuizQuestion q, Map<String, List<String>> pools) {
    if (q.type == QuestionType.trueFalse) {
      return List<String>.from(q.answers);
    }
    final correct = q.correctAnswer.trim();
    final targetCount = q.answers.length;
    if (targetCount < 2) return List<String>.from(q.answers);

    final pool = List<String>.from(pools[q.category] ?? const []);
    // Doğru cevabı ve case-varyantlarını çıkar.
    pool.removeWhere((c) => _norm(c) == _norm(correct));

    final rng = _DetRand(seed ^ q.id.hashCode);
    // Benzer uzunluk tercih et.
    pool.sort((a, b) {
      final da = (a.length - correct.length).abs();
      final db = (b.length - correct.length).abs();
      return da.compareTo(db);
    });

    final picked = <String>[];
    final used = <String>{_norm(correct)};
    for (final candidate in pool) {
      if (picked.length >= targetCount - 1) break;
      final n = _norm(candidate);
      if (used.contains(n)) continue;
      picked.add(candidate);
      used.add(n);
    }

    // Havuz yetmezse eski çeldiricilerden tamamla.
    if (picked.length < targetCount - 1) {
      for (final old in q.answers) {
        if (picked.length >= targetCount - 1) break;
        final n = _norm(old);
        if (used.contains(n)) continue;
        picked.add(old);
        used.add(n);
      }
    }

    // Konum: doğru cevabı orijinal indekste tut (mümkünse).
    final correctIndex = q.answers.indexWhere(
      (a) => _norm(a) == _norm(correct),
    );
    final result = List<String>.filled(targetCount, '');
    final slot = correctIndex >= 0 && correctIndex < targetCount
        ? correctIndex
        : 0;
    result[slot] = correct;

    var pi = 0;
    for (var i = 0; i < targetCount; i++) {
      if (i == slot) continue;
      if (pi < picked.length) {
        result[i] = picked[pi++];
      } else {
        result[i] = '—';
      }
    }

    // Hafif karıştır (doğru cevabı sabitleyerek diğerlerini).
    final distractorSlots = <int>[
      for (var i = 0; i < targetCount; i++)
        if (i != slot) i,
    ];
    for (var i = distractorSlots.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final a = distractorSlots[i];
      final b = distractorSlots[j];
      final tmp = result[a];
      result[a] = result[b];
      result[b] = tmp;
    }

    return result;
  }

  /// Tüm banka için yeniden üretilmiş kopyalar (doğru cevap aynı).
  List<QuizQuestion> rebuildAll() {
    final pools = buildPools();
    return [
      for (final q in questions)
        QuizQuestion(
          id: q.id,
          category: q.category,
          prompt: q.prompt,
          answers: rebuildAnswers(q, pools),
          correctAnswer: q.correctAnswer,
          explanation: q.explanation,
          difficulty: q.difficulty,
          type: q.type,
          imageUrl: q.imageUrl,
          explanationKu: q.explanationKu,
          explanationTr: q.explanationTr,
        ),
    ];
  }

  /// Kalite skoru: aynı kategoriden gelen çeldirici oranı (0–1).
  double categoryCohesionScore(
    QuizQuestion q,
    Map<String, List<String>> pools,
  ) {
    if (q.type == QuestionType.trueFalse) return 1;
    final poolNorm = {
      for (final c in pools[q.category] ?? const <String>[]) _norm(c),
    };
    final distractors = q.answers.where(
      (a) => _norm(a) != _norm(q.correctAnswer),
    );
    final list = distractors.toList();
    if (list.isEmpty) return 1;
    final hits = list.where((a) => poolNorm.contains(_norm(a))).length;
    return hits / list.length;
  }

  static String _norm(String s) => s.trim().toLowerCase();
}

/// Küçük deterministik PRNG (test ve yeniden üretilebilir tool çıktısı).
class _DetRand {
  _DetRand(int seed) : _s = seed == 0 ? 1 : seed;
  int _s;

  int nextInt(int max) {
    if (max <= 0) return 0;
    // xorshift32
    var x = _s;
    x ^= x << 13;
    x ^= x >> 17;
    x ^= x << 5;
    _s = x;
    return x.abs() % max;
  }
}
