/// Serbest metinli yanıtın doğru cevapla ilişkisi.
enum FreeTextMatch {
  /// Normalleştirilmiş yazım birebir aynı (ya da editörün verdiği alternatif).
  exact,

  /// Yalnız `ç ş ê î û` inceltmeleri eksik/farklı: cevap doğru sayılır, ama
  /// ekran doğru yazımı gösterir (`cay` → «Doğru yazım: çay»).
  folded,

  none,
}

/// Gerçek bir Kurmancî sözcük olup, bir boşluk doldurma cevabından YALNIZ
/// inceltmeyle ayrılanlar (`şêr`/`şer`/`ser`, `dê`/`de`, `tê`/`te`, `çil`/`cil`).
///
/// Katlama kuralı bunlara uygulanmaz: oyuncu `şer` (savaş) yazdıysa `şêr`
/// (aslan) demek istememiştir. Liste elle durur; `fill_in_blank_fold_test`
/// bankadaki her yeni çakışmayı yakalayıp burada eksik olanı bildirir.
const Set<String> kFoldDistinctWords = {
  // 2026-10-25: gelecek zaman ön eki ve «bê» (gelmek) ayrı sözcükler;
  // yalnız inceltmeyle farklılar (dersler3/4 ve baslangic bankası).
  'ê',
  'be',
  'cil',
  'çil',
  'de',
  'dê',
  'me',
  'mê',
  'ser',
  'şer',
  'şêr',
  'te',
  'tê',
  'we',
  'wê',
  'ye',
  'yê',
};

/// `ç ş ê î û` harflerini ASCII karşılığına indirir (yalnız KARŞILAŞTIRMA).
String foldFreeTextDiacritics(String value) => value
    .replaceAll('ç', 'c')
    .replaceAll('ş', 's')
    .replaceAll('ê', 'e')
    .replaceAll('î', 'i')
    .replaceAll('û', 'u');

/// Yazılan yanıtı [options] (doğru cevap ve editörün alternatifleri) ile
/// karşılaştırır. Üç değerden biri döner, bkz. [FreeTextMatch].
///
/// Katlanmış eşleşme, yazılan sözcüğün kendisi başka bir gerçek sözcükse
/// ([kFoldDistinctWords]) ya da sorunun başka bir şıkkının [rivals]
/// katlanmışıyla aynıysa, ya da [allowFolding] kapalıysa (soru zaten harfin
/// yazımını sınıyorsa) REDDEDİLİR.
FreeTextMatch matchFreeTextAnswer(
  String candidate,
  Iterable<String> options, {
  Iterable<String> rivals = const [],
  bool isTurkish = false,
  bool allowFolding = true,
}) {
  final typed = normalizeFreeTextAnswer(candidate, isTurkish: isTurkish);
  if (typed.isEmpty) return FreeTextMatch.none;
  final normalizedOptions = [
    for (final option in options)
      normalizeFreeTextAnswer(option, isTurkish: isTurkish),
  ];
  if (normalizedOptions.contains(typed)) return FreeTextMatch.exact;
  if (!allowFolding || kFoldDistinctWords.contains(typed)) {
    return FreeTextMatch.none;
  }
  final foldedTyped = foldFreeTextDiacritics(typed);
  final rivalFolds = {
    for (final rival in rivals)
      foldFreeTextDiacritics(
        normalizeFreeTextAnswer(rival, isTurkish: isTurkish),
      ),
  };
  if (rivalFolds.contains(foldedTyped)) return FreeTextMatch.none;
  final matches = normalizedOptions.any(
    (option) => foldFreeTextDiacritics(option) == foldedTyped,
  );
  return matches ? FreeTextMatch.folded : FreeTextMatch.none;
}

/// Serbest metinli quiz yanıtını yalnız karşılaştırma için normalleştirir.
///
/// Kanonik Kurmancî yazım ekranda ve içerik bankasında korunur. Birleşik ve
/// ayrık Unicode yazımları eşitlenir. Bu işlev harfleri katlamaz; inceltmesiz
/// yazım [matchFreeTextAnswer] ile ayrıca, doğru yazım gösterilerek kabul
/// edilir.
///
/// Türkçe cevapta `I/ı` ve `İ/i` eşlenir; küçük `i` hiçbir zaman `ı`ya
/// çevrilmez. Böylece `sik` ile `sık` farklı kalır.
String normalizeFreeTextAnswer(String value, {bool isTurkish = false}) {
  final localeAwareValue = isTurkish
      ? value
            .replaceAll('I\u0307', 'i')
            .replaceAll('İ', 'i')
            .replaceAll('I', 'ı')
      : value;
  return localeAwareValue
      .trim()
      .toLowerCase()
      .replaceAll('i\u0302', 'î')
      .replaceAll('e\u0302', 'ê')
      .replaceAll('u\u0302', 'û')
      .replaceAll('s\u0327', 'ş')
      .replaceAll('c\u0327', 'ç')
      .replaceAll(RegExp(r'\s+'), ' ');
}
