import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'learner_lexicon.dart';

/// Tekrar alıştırmasının türü. Kelime kutusu ilerledikçe tanımadan
/// hatırlamaya geçilir (Memrise/Duolingo kalıbı; kurul 2026-10-25:
/// Codex + Gemini 4 Argon, kelime tekrarı 10/10):
///
/// * [meaning]: Kurmancî sözcük → Türkçe anlam (tanıma).
/// * [reverse]: Türkçe anlam → Kurmancî sözcük (geri çağırma).
/// * [listen]: ses → doğru Hawar yazılışı; şıklarda e/ê, i/î, u/û, c/ç,
///   s/ş karışık yazımlar da bulunur (harf–ses köprüsü).
/// * [spell]: Türkçe anlam → harfleri dizerek Kurmancî yazım (üretim).
enum WordReviewMode { meaning, reverse, listen, spell }

/// Kelime tekrarı sorusu.
@immutable
class WordReviewQuestion {
  const WordReviewQuestion({
    required this.entry,
    required this.options,
    this.mode = WordReviewMode.meaning,
    this.letters = const [],
  });

  final LearnerLexiconEntry entry;

  /// [WordReviewMode.meaning]: dört Türkçe anlam. [reverse]/[listen]: dört
  /// Kurmancî yazım. [spell]: boş (harfler [letters]'ta).
  final List<String> options;

  final WordReviewMode mode;

  /// [WordReviewMode.spell] için karışık harfler (küçük harf).
  final List<String> letters;

  String get correctMeaning => entry.meaningTr;

  /// Beklenen cevap: anlam sorusunda Türkçe anlam, ötekilerde Kurmancî
  /// sözcük.
  String get answer =>
      mode == WordReviewMode.meaning ? entry.meaningTr : entry.termKu;

  /// Yazımda harf İŞARETLERİ önemlidir (e ≠ ê): yalnız büyük/küçük harf
  /// yok sayılır.
  bool isCorrect(String option) => mode == WordReviewMode.meaning
      ? option == entry.meaningTr
      : option.trim().toLowerCase() == entry.termKu.trim().toLowerCase();

  /// Harf dizme yalnız tek sözcüklü, 2–9 harfli maddelerde sorulur.
  static bool canSpell(LearnerLexiconEntry entry) {
    final term = entry.termKu.trim();
    return term.length >= 2 &&
        term.length <= 9 &&
        RegExp(r'^\p{L}+$', unicode: true).hasMatch(term);
  }

  /// Kutuya göre tür. Ses yoksa dinleme yerine geri çağırma sorulur.
  static WordReviewMode modeForBox(
    int box, {
    required LearnerLexiconEntry entry,
    required bool canListen,
  }) {
    if (box <= 1) return WordReviewMode.meaning;
    if (box == 2) return WordReviewMode.reverse;
    if (box == 3) {
      return canListen ? WordReviewMode.listen : WordReviewMode.reverse;
    }
    if (canSpell(entry)) return WordReviewMode.spell;
    return canListen ? WordReviewMode.listen : WordReviewMode.reverse;
  }

  /// [mode] türünde soru kurar.
  static WordReviewQuestion buildFor(
    LearnerLexiconEntry entry,
    WordReviewMode mode, {
    math.Random? random,
  }) {
    final rng = random ?? math.Random();
    switch (mode) {
      case WordReviewMode.meaning:
        return build(entry, random: rng);
      case WordReviewMode.reverse:
        return WordReviewQuestion(
          entry: entry,
          mode: mode,
          options: _termOptions(entry, rng, const []),
        );
      case WordReviewMode.listen:
        return WordReviewQuestion(
          entry: entry,
          mode: mode,
          options: _termOptions(entry, rng, hawarVariants(entry.termKu)),
        );
      case WordReviewMode.spell:
        final letters = entry.termKu.trim().toLowerCase().split('');
        final shuffled = [...letters];
        // Harfler doğru sırada gelmesin (tek harf tekrarı dışında).
        for (var i = 0; i < 6; i++) {
          shuffled.shuffle(rng);
          if (shuffled.join() != letters.join()) break;
        }
        return WordReviewQuestion(
          entry: entry,
          mode: mode,
          options: const [],
          letters: shuffled,
        );
    }
  }

  static const Map<String, String> _hawarPairs = {
    'e': 'ê',
    'ê': 'e',
    'i': 'î',
    'î': 'i',
    'u': 'û',
    'û': 'u',
    'c': 'ç',
    'ç': 'c',
    's': 'ş',
    'ş': 's',
    'E': 'Ê',
    'Ê': 'E',
    'I': 'Î',
    'Î': 'I',
    'U': 'Û',
    'Û': 'U',
    'C': 'Ç',
    'Ç': 'C',
    'S': 'Ş',
    'Ş': 'S',
  };

  /// Sözcüğün tek harfi Hawar çiftiyle değiştirilmiş yazımları (`şêr` →
  /// `sêr`, `şer`). Dinleme sorusunda çeldiricidir: öğrenen duyduğu sesi
  /// doğru işaretli harfle eşlemeyi öğrenir.
  static List<String> hawarVariants(String term) {
    final out = <String>[];
    final chars = term.split('');
    for (var i = 0; i < chars.length; i++) {
      final swap = _hawarPairs[chars[i]];
      if (swap == null) continue;
      final replaced = [...chars]..[i] = swap;
      final variant = replaced.join();
      if (variant.toLowerCase() != term.toLowerCase() &&
          !out.contains(variant)) {
        out.add(variant);
      }
    }
    return out;
  }

  /// Doğru Kurmancî yazım + en çok iki Hawar varyantı + sözlükten gerçek
  /// çeldiriciler (toplam dört). Gerçek çeldiricinin anlamı doğru anlamla
  /// parça paylaşamaz (iki doğru şık olmasın).
  static List<String> _termOptions(
    LearnerLexiconEntry entry,
    math.Random rng,
    List<String> variants,
  ) {
    const count = 4;
    final term = entry.termKu.trim();
    final taken = <String>{term.toLowerCase()};
    final picked = <String>[];
    final shuffledVariants = [...variants]..shuffle(rng);
    for (final v in shuffledVariants.take(2)) {
      if (taken.add(v.toLowerCase())) picked.add(v);
    }
    final meaningParts = _parts(entry.meaningTr);
    void pick(List<LearnerLexiconEntry> pool) {
      if (pool.isEmpty) return;
      final start = rng.nextInt(pool.length);
      for (var i = 0; i < pool.length && picked.length < count - 1; i++) {
        final candidate = pool[(start + i) % pool.length];
        if (candidate.id == entry.id) continue;
        final candidateTerm = candidate.termKu.trim();
        if (candidateTerm.isEmpty || candidateTerm.contains(' ')) continue;
        if (_parts(candidate.meaningTr).any(meaningParts.contains)) continue;
        if (taken.add(candidateTerm.toLowerCase())) picked.add(candidateTerm);
      }
    }

    pick(LearnerLexicon.entriesForSource(entry.sourceId));
    if (picked.length < count - 1) pick(LearnerLexicon.entries);
    final options = [...picked];
    options.insert(rng.nextInt(options.length + 1), term);
    return options;
  }

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
