import 'package:flutter/widgets.dart';

import '../models/quiz_question.dart';

/// Bir tura servis edilecek soru kümesinin *kendi içindeki* tutarlılığını
/// koruyan saf politika.
///
/// Tek tek doğru olan sorular, yan yana geldiklerinde birbirini bozabilir.
/// 2026-07-25 canlı denetiminde görülen örnek:
///
///   1. soru: "'rênivîsa Hawarê' hangi açıklamayla anlaşılır?"
///      → doğru cevap: "Celadet Bedirxan'ın latin harfli alfabe sistemi"
///   2. soru: "Şu açıklama hangi terimdir: ...?"
///      → şıklardan biri: "rênivîsa Hawarê"
///
/// Birinci soru ikincinin cevabını, ikinci de birincinin terimini açık
/// ediyordu: aynı terim havuzundan ters çevrilerek üretilmiş sorular arka
/// arkaya düşünce tur bir bilgi ölçümü olmaktan çıkıyor.
///
/// Politika saf ve senkrondur; hem mock hem sunucu deposu aynı süzgeci
/// kullanır ki davranış ortamlar arasında ayrışmasın.
class QuestionSetPolicy {
  const QuestionSetPolicy._();

  /// Bir metni karşılaştırma için sadeleştirir: küçük harf, kenar boşlukları
  /// ve tırnak/noktalama kırpılmış. Kurmancî özel karakterleri (î, ê, û, ş,
  /// ç) *korunur* — ASCII'ye katlamak "şer" ile "ser" gibi farklı sözcükleri
  /// eşitler.
  static String normalize(String value) {
    final lowered = value.toLowerCase().trim();
    final buffer = StringBuffer();
    for (final rune in lowered.runes) {
      final char = String.fromCharCode(rune);
      // Noktalama ve tırnak atılır; harf, rakam ve boşluk kalır.
      if (RegExp(r'[\p{L}\p{N}\s]', unicode: true).hasMatch(char)) {
        buffer.write(char);
      }
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// [a] ve [b] birbirinin cevabını sızdırıyor mu?
  ///
  /// Sızıntı sayılan durumlar:
  /// - Birinin doğru cevabı, diğerinin soru metninde geçiyor.
  /// - Birinin doğru cevabı, diğerinin şıklarından biriyle aynı.
  ///
  /// Karşılaştırma iki yönlü yapılır; hangisinin önce geldiği önemsizdir.
  static bool leaksBetween(QuizQuestion a, QuizQuestion b) {
    if (a.id == b.id) return true;
    return _leaksInto(a, b) || _leaksInto(b, a);
  }

  static bool _leaksInto(QuizQuestion source, QuizQuestion target) {
    final answer = normalize(source.correctAnswer);
    // Çok kısa cevaplar ("5", "ez") tesadüfen her yerde geçer; eşiğin
    // altında kalanlar sızıntı sayılmaz, aksi halde geçerli sorular da
    // elenirdi.
    if (answer.length < 4) return false;

    final prompt = normalize(target.prompt);
    if (prompt.contains(answer)) return true;

    for (final option in target.answers) {
      if (normalize(option) == answer) return true;
    }
    return false;
  }

  /// [candidates] listesini sırasını koruyarak süzer: daha önce seçilmiş
  /// hiçbir soruyla sızıntı ilişkisi olmayan sorular tutulur.
  ///
  /// Süzgeç [limit] kadar soru bulamazsa listeyi zorla doldurmaz; eksik
  /// dönmek, kullanıcıya kendi kendini ele veren bir tur sunmaktan iyidir.
  /// Çağıran taraf isterse [fillFrom] ile havuzun kalanından tamamlayabilir.
  static List<QuizQuestion> withoutLeaks(
    List<QuizQuestion> candidates, {
    int? limit,
  }) {
    final kept = <QuizQuestion>[];
    for (final candidate in candidates) {
      if (limit != null && kept.length >= limit) break;
      final conflicts = kept.any((q) => leaksBetween(q, candidate));
      if (!conflicts) kept.add(candidate);
    }
    return kept;
  }

  // ─── Tur içi konu çeşitliliği ────────────────────────────────────────
  //
  // Kusur (2026-10-02): "Edebiyat › Helbest › 1. Seviye" dokuz soruluk bir
  // turda üç kez Cegerxwîn'i soruyor, iki de neredeyse aynı "qafiye/kafiye"
  // sorusu içeriyordu. Her soru tek başına doğruydu; tekrar tur İÇİNDEKİ
  // soruların birbirine benzemesindeydi. Mevcut süzgeçler yalnız aynı metni
  // (`dedupeByPrompt`), aynı kelime çiftini (`dedupeByTranslationPair`) ve
  // cevap sızıntısını yakalıyordu; "aynı kişi hakkında üç ayrı soru" hiçbirine
  // takılmıyordu.

  static final RegExp _quotedTerm = RegExp('[«"“\']([^«»"”\']{2,40})[»"”\']');

  /// Soru cümlesini açan ama özel ad olmayan sözcükler (büyük harfle
  /// başlarlar çünkü cümle başıdır). Liste kapsamlı değil, ucuz bir
  /// buluşsal: kaçırılan bir sözcük yalnız o iki soruyu "aynı konu" sayar ve
  /// çeşitlilik kuralı zaten yumuşaktır (havuz küçükse vazgeçer).
  static const Set<String> _sentenceStarters = {
    'kîjan',
    'kijan',
    'kî',
    'çi',
    'çawa',
    'çend',
    'çima',
    'kengê',
    'kû',
    'gelo',
    'rast',
    'şaş',
    'ev',
    'ew',
    'di',
    'ji',
    'bi',
    'li',
    'ber',
    'piştî',
    'berî',
    'dema',
    'gava',
    'heke',
    'eger',
    'ger',
    'ku',
    'her',
    'yek',
    'hin',
    'têgeha',
    'têgeh',
    'peyva',
    'peyvên',
    'bêjeya',
    'rêbaza',
    'cureyê',
    'cure',
    'wêne',
    'wêneyê',
    'wêneya',
    'navê',
    'nav',
    'hevoka',
    'hevok',
    'gotina',
    'wateya',
    'dîwan',
    'destan',
    'helbest',
    'helbesta',
    'wêje',
    'wêjeya',
    'ziman',
    'zimanê',
    'zaravayê',
    'nivîsa',
    'nivîs',
    'kurmancî',
    'kurdî',
    'ka',
    'tu',
    'min',
    'em',
    'hûn',
    'ez',
    'wan',
    'wî',
    'wê',
    'rojek',
    'roja',
    'salê',
    'mehê',
    'mehek',
    'cihê',
    'bajarê',
    'bajar',
    'welatê',
    'gundê',
    'çiyayê',
    'çemê',
    'avê',
    'xwarina',
    'xwarin',
    'heywanê',
    'heywan',
    'rengê',
    'reng',
    'jimara',
    'jimar',
    'hejmara',
    'hejmar',
    'dengê',
    'deng',
    'tîpa',
    'tîp',
    'alfabeya',
    'ferhenga',
    'ferheng',
    'komeke',
    'nimûne',
    'mînak',
    'tiştê',
    'tişt',
    'kesê',
    'kes',
    'wek',
    'weke',
    'wekî',
    'bê',
    'bêyî',
    'bo',
    'ne',
    'na',
    'erê',
    'belê',
  };

  /// Doğru/yanlış tipi cevaplar konu taşımaz.
  static const Set<String> _verdictWords = {
    'rast',
    'şaş',
    'erê',
    'na',
    'evet',
    'hayır',
    'doğru',
    'yanlış',
    'true',
    'false',
  };

  /// Sorunun *konusu*: aynı turda iki kez sorulmaması istenen kişi/terim.
  ///
  /// Sırayla: (1) soru metnindeki tırnaklı terim, (2) metnin başındaki
  /// büyük harfli özel ad ("Cegerxwîn bi çi tê naskirin?"), (3) doğru cevap
  /// kısa bir terim ya da özel adsa o. Doğru/yanlış cevapları (Rast, Şaş) ve
  /// sayılar konu sayılmaz. Hiçbiri yoksa `null`: o soru çeşitlilik
  /// kuralından muaftır (tarih, dilbilgisi gibi konusuz sorular).
  static String? subjectKey(QuizQuestion question) {
    final key = _rawSubjectKey(question);
    // Yazım değişkeleri aynı konudur: "qafiye" / "kafiye" (banka ikisini de
    // kullanıyor). Yalnız karşılaştırma anahtarında q -> k katlanır.
    return key?.replaceAll('q', 'k');
  }

  static String? _rawSubjectKey(QuizQuestion question) {
    final quoted = _quotedTerm.firstMatch(question.prompt);
    if (quoted != null) {
      final term = normalize(quoted.group(1) ?? '');
      if (term.length >= 3) return term;
    }

    final leading = _leadingName(question.prompt);
    if (leading != null) return leading;

    if (question.type == QuestionType.trueFalse) return null;
    final answer = normalize(question.correctAnswer);
    if (answer.length < 3 || answer.length > 24) return null;
    if (_verdictWords.contains(answer)) return null;
    if (RegExp(r'^[\d\s]+$').hasMatch(answer)) return null;
    if (answer.split(' ').length > 3) return null;
    return answer;
  }

  /// Metnin başındaki büyük harfli ad öbeği (en çok üç sözcük); yoksa null.
  static String? _leadingName(String prompt) {
    final words = prompt.trim().split(RegExp(r'\s+'));
    final name = <String>[];
    for (final raw in words) {
      final word = raw.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');
      if (word.isEmpty) break;
      final first = String.fromCharCode(word.runes.first);
      final isCapital =
          first != first.toLowerCase() && first == first.toUpperCase();
      if (!isCapital || name.length >= 3) break;
      // Cümle başı sözcüğü ad değildir; ad öbeğinin içinde kalan "Mela" gibi
      // sözcükler ise listede olsa bile yalnız İLK sözcükte süzülür.
      if (name.isEmpty && _sentenceStarters.contains(word.toLowerCase())) {
        return null;
      }
      name.add(word);
      // Virgül ya da nokta öbeği bitirir ("Mela Ehmed, ku ...").
      if (RegExp(r'[,.;:?!]$').hasMatch(raw)) break;
    }
    if (name.isEmpty) return null;
    final key = normalize(name.join(' '));
    if (name.length == 1 && key.length < 4) return null;
    return key;
  }

  /// Karşılaştırma için sade belirteç kümesi: "Rast e an şaş e" kalıbı
  /// atılır (yoksa iki ilgisiz doğru/yanlış sorusu kalıp yüzünden benzer
  /// görünürdü).
  static Set<String> _promptTokens(String prompt) {
    final text = ' ${normalize(prompt)} '
        .replaceAll(' ev rast e an şaş e ', ' ')
        .replaceAll(' rast e an şaş e ', ' ');
    return text.split(' ').where((token) => token.isNotEmpty).toSet();
  }

  /// İki soru metninin belirteç Jaccard benzerliği (0–1). Üçten az
  /// belirteçli metinlerde 0 döner: kısa kalıplar ("X kî bû?") kalıbın
  /// kendisi yüzünden benzer çıkardı.
  static double promptSimilarity(String a, String b) {
    final left = _promptTokens(a);
    final right = _promptTokens(b);
    if (left.length < 3 || right.length < 3) return 0;
    final shared = left.intersection(right).length;
    final union = left.length + right.length - shared;
    return union == 0 ? 0 : shared / union;
  }

  /// Benzer metin eşiği (belirteç Jaccard).
  static const double similarPromptThreshold = 0.6;

  /// [a] ve [b] aynı turda birlikte "tekrar" sayılır mı: aynı konu ya da
  /// neredeyse aynı soru metni.
  static bool repeatsSubject(QuizQuestion a, QuizQuestion b) {
    final keyA = subjectKey(a);
    if (keyA != null && keyA == subjectKey(b)) return true;
    return promptSimilarity(a.prompt, b.prompt) >= similarPromptThreshold;
  }

  /// [candidate] [chosen] içindeki herhangi bir soruyu tekrar ediyor mu?
  static bool repeatsAny(
    QuizQuestion candidate,
    Iterable<QuizQuestion> chosen,
  ) {
    return chosen.any(
      (other) => other.id != candidate.id && repeatsSubject(other, candidate),
    );
  }

  /// [withoutLeaks] + konu çeşitliliği: tur ([limit] soru) önce hem
  /// sızıntısız hem tekrarsız sorularla kurulur; yetmezse eksik, yalnız
  /// çeşitlilik yüzünden atlanan (ama sızıntısız) sorularla tamamlanır.
  /// Yani kural bir TERCİHTİR, turu asla kısaltmaz: havuz küçükse eski
  /// davranış (yalnız sızıntı süzgeci) aynen geçerlidir.
  static List<QuizQuestion> diverseWithoutLeaks(
    List<QuizQuestion> candidates, {
    required int limit,
  }) {
    final kept = <QuizQuestion>[];
    final deferred = <QuizQuestion>[];
    for (final candidate in candidates) {
      if (kept.length >= limit) break;
      if (kept.any((q) => leaksBetween(q, candidate))) continue;
      if (repeatsAny(candidate, kept)) {
        deferred.add(candidate);
        continue;
      }
      kept.add(candidate);
    }
    if (kept.length >= limit) return kept;
    // Aday sırası korunur: tekrar sayılan sorular, kalan yeri doldururken
    // yine sızıntı denetiminden geçer.
    for (final candidate in deferred) {
      if (kept.length >= limit) break;
      if (kept.any((q) => leaksBetween(q, candidate))) continue;
      kept.add(candidate);
    }
    return kept;
  }

  /// Sorunun *okuma yükü*: metin ve şık uzunluğundan türetilen kaba bir
  /// karmaşıklık ölçüsü. Düşük = kısa ve doğrudan.
  ///
  /// Bankadaki `difficulty` etiketi konu zorluğunu anlatıyor ama okuma
  /// yükünü hiç yansıtmıyor: 2026-07-25 ölçümünde zorluk 1'in şık uzunluğu
  /// medyanı (50 karakter) tüm seviyelerin en yükseğiydi — yani tanım
  /// biçimli, altı satırlık sorular "Destpêk" (başlangıç) basamağına
  /// düşüyordu. Yeni öğrenen ilk temasında en ağır metinle karşılaşıyordu.
  static int readingLoad(QuizQuestion question) {
    final promptLength = question.prompt.characters.length;
    final longestOption = question.answers.fold<int>(
      0,
      (maximum, option) => option.characters.length > maximum
          ? option.characters.length
          : maximum,
    );
    // Şık uzunluğu iki kat ağırlıklı: dört uzun şıkkı karşılaştırmak, uzun
    // bir soru metnini okumaktan daha yorucudur.
    return promptLength + longestOption * 2;
  }

  /// Cevabı tanımak yerine ÜRETMEYİ isteyen soru türleri: yazmalı
  /// (boşluk doldurma) ve kelime sıralama.
  static bool isProductionTask(QuizQuestion question) =>
      question.type == QuestionType.fillInBlank ||
      question.type == QuestionType.wordOrdering;

  /// [candidates] listesini hafiften ağıra sıralar: önce tanıma soruları
  /// (şıklı, doğru/yanlış, görselli), sonra üretim soruları; her grup kendi
  /// içinde okuma yüküne göre.
  ///
  /// Okuma yükü üretim sorusunu yanlış tartıyordu: yazmalı sorunun "şıkkı"
  /// yazılacak cevabın kendisidir ve kısadır ("mirovekî"), bu yüzden hafif
  /// sayılıyordu. "Ziman › Rêziman › Destpêk"in İLK sorusu, "mirov"un
  /// belirsiz tekil bükümünü klavyeyle yazdıran bir soruydu (2026-09-27
  /// simülatör turu). Cevabı hatırlayıp yazmak, dört şıktan tanımaktan
  /// ağırdır; yeni öğrenenin ilk teması tanıma olmalı.
  ///
  /// Kararlılık için eşit yükte olanlar özgün sıralarını korur; böylece
  /// aynı havuz her seferinde aynı turu üretir (test edilebilirlik).
  static List<QuizQuestion> byReadingLoad(List<QuizQuestion> candidates) {
    int tier(QuizQuestion q) => isProductionTask(q) ? 1 : 0;
    final indexed = candidates.indexed.toList()
      ..sort((a, b) {
        final byTier = tier(a.$2).compareTo(tier(b.$2));
        if (byTier != 0) return byTier;
        final byLoad = readingLoad(a.$2).compareTo(readingLoad(b.$2));
        return byLoad != 0 ? byLoad : a.$1.compareTo(b.$1);
      });
    return [for (final entry in indexed) entry.$2];
  }

  /// Açıklama sorunun kendisini tekrar ediyor mu?
  ///
  /// "«lêkera gerguhêz» şu anlama gelir: lêkerên ku hewcedariya wan bi
  /// artêla tewandî heye…" — soru zaten bu tanımı verip terimi soruyordu;
  /// açıklama hiçbir yeni bilgi eklemiyor (2026-07-25 canlı denetimi).
  ///
  /// Üretim akışında soru banka araçları bu bayrağı kalite raporunda
  /// kullanır; uygulama çalışırken içerik elemek için değil, denetim için.
  static bool explanationIsTautological(QuizQuestion question) {
    final explanation = normalize(
      question.explanationTr ?? question.explanationKu ?? question.explanation,
    );
    if (explanation.isEmpty) return false;
    final prompt = normalize(question.prompt);
    if (prompt.isEmpty) return false;

    // Sorunun tırnak içindeki tanım kısmı açıklamada birebir geçiyorsa,
    // açıklama soruyu yeniden yazmaktan ibarettir.
    final quoted = RegExp(r"'([^']{12,})'").allMatches(question.prompt);
    for (final match in quoted) {
      final fragment = normalize(match.group(1) ?? '');
      if (fragment.length >= 12 && explanation.contains(fragment)) return true;
    }

    // Ya da açıklamanın büyük bölümü doğrudan soru metninden kopyalanmışsa.
    final promptWords = prompt.split(' ').where((w) => w.length > 3).toSet();
    if (promptWords.length < 5) return false;
    final explanationWords = explanation
        .split(' ')
        .where((w) => w.length > 3)
        .toList();
    if (explanationWords.length < 5) return false;
    final shared = explanationWords.where(promptWords.contains).length;
    return shared / explanationWords.length >= 0.8;
  }
}
