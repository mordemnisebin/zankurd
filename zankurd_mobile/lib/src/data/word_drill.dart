import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'learner_lexicon.dart';

/// Kelime tekrarı sorusu: Kurmancî sözcük + dört Türkçe anlam şıkkı.
@immutable
class WordReviewQuestion {
  const WordReviewQuestion({required this.entry, required this.options});

  final LearnerLexiconEntry entry;

  /// Dört (sözlük küçükse daha az) Türkçe anlam; biri doğrudur.
  final List<String> options;

  String get correctMeaning => entry.meaningTr;

  bool isCorrect(String option) => option == entry.meaningTr;

  /// [entry] için soru kurar; çeldiriciler sözlükten gelir.
  ///
  /// ## Kural
  ///
  /// Çeldirici, doğru anlamla AYNI olamaz ve anlam parçası paylaşamaz:
  /// `Günaydın / İyi günler` doğruyken `İyi günler` çeldiricisi iki doğru
  /// şık üretirdi. Çeldiriciler de birbirinden farklıdır. Önce aynı kaynak
  /// dersten (benzer konu = gerçekçi çeldirici), yetmezse bütün sözlükten
  /// seçilir. [random] verilirse sonuç belirlenimli olur (test, ekran turu).
  static WordReviewQuestion build(
    LearnerLexiconEntry entry, {
    math.Random? random,
    int optionCount = 4,
  }) {
    final rng = random ?? math.Random();
    final taken = <String>{..._parts(entry.meaningTr)};
    final distractors = <String>[];

    // Havuzu kopyalayıp karıştırmak her soruda binlerce madde demekti; yalnız
    // gereken çeldirici kadar RASTGELE örnek alınır: rastgele indeksler
    // denenir, yetmezse (küçük/çarpışmalı havuz) rastgele bir başlangıçtan
    // tek turluk doğrusal tarama yapılır.
    void pick(List<LearnerLexiconEntry> pool) {
      if (pool.isEmpty) return;
      bool tryAdd(LearnerLexiconEntry candidate) {
        if (candidate.id == entry.id) return false;
        final parts = _parts(candidate.meaningTr);
        if (parts.isEmpty || parts.any(taken.contains)) return false;
        taken.addAll(parts);
        distractors.add(candidate.meaningTr);
        return true;
      }

      final need = optionCount - 1;
      for (var i = 0; i < need * 8 && distractors.length < need; i++) {
        tryAdd(pool[rng.nextInt(pool.length)]);
      }
      if (distractors.length >= need) return;
      final start = rng.nextInt(pool.length);
      for (var i = 0; i < pool.length && distractors.length < need; i++) {
        tryAdd(pool[(start + i) % pool.length]);
      }
    }

    pick(LearnerLexicon.entriesForSource(entry.sourceId));
    if (distractors.length < optionCount - 1) pick(LearnerLexicon.entries);

    final options = <String>[...distractors];
    options.insert(rng.nextInt(options.length + 1), entry.meaningTr);
    return WordReviewQuestion(entry: entry, options: options);
  }

  static final RegExp _split = RegExp(r'\s*[/,;()]\s*');

  static Set<String> _parts(String meaning) => {
    for (final part in meaning.split(_split))
      if (part.trim().isNotEmpty) LearnerLexicon.foldForSearch(part),
  };
}
