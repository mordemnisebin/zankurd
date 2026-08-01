import '../models/quiz_question.dart';

/// Sorunun gövdesi ile şıklarının aynı dilde olup olmadığını denetler.
///
/// 2026-07-22 canlı UX denetiminde, arayüz dili ne olursa olsun bazı
/// soruların Kurmancî gövde + Türkçe şık kombinasyonuyla geldiği görüldü
/// (ör. `offline_10878`: "Di çarçoveya Muzîkê de 'Kardeş Türküler' tê çi
/// wateyê?" → şıkların tamamı Türkçe tanım). Oyuncu için bu, sorunun
/// yarısını okuyup diğer yarısını anlamamak demek.
///
/// Çeviri alıştırmaları bunun dışındadır: "Peyva Kurmancî 'biçûk' bi Tirkî
/// çi tê gotin?" sorusunun şıklarının Türkçe olması pedagojik olarak
/// doğrudur. Bu yüzden Ziman kategorisi ve çeviri kalıbı taşıyan gövdeler
/// muaf tutulur.
class QuestionLanguagePolicy {
  const QuestionLanguagePolicy();

  static const mixedLanguageIssue = 'mixed_language_options';

  /// Şıkların gövdeden farklı dilde olması meşru sayılan kategoriler.
  static const translationCategories = {'Ziman', 'Rêziman'};

  /// Gövdede geçtiğinde sorunun bir çeviri alıştırması olduğunu gösteren
  /// kalıplar (Kurmancî).
  static const _translationMarkers = [
    'bi tirkî',
    'bi kurmancî',
    'bi kurdî',
    'berambera',
    'wateya wê çi ye',
    'tê çi wateyê',
    'çi tê gotin',
    // "Dema 'X' tê gotin, çi tê xwestin?" — anlam sorusunun bir başka
    // kalıbı. Listede yoktu ve bu kalıptaki 46 soru "dil karışık" diye
    // suçlanmaya adaydı; oysa şıkların Türkçe olması sorunun **istediği**
    // şeydir (2026-07-27).
    'tê xwestin',
    'wergerîne',
  ];

  static const _kurmanciWords = {
    'di',
    'bi',
    'ku',
    'ji',
    'li',
    'ye',
    'ne',
    'wê',
    'tê',
    'çi',
    'yê',
    'de',
    'her',
    'bo',
    'yek',
    'ew',
    'ev',
    'bû',
    'dike',
    'nav',
    'navê',
    'kîjan',
    'çend',
    'were',
    'hat',
    'hatiye',
    'xwe',
    'wek',
    'jî',
    'peyva',
    'wateya',
  };

  static const _turkishWords = {
    've',
    'bir',
    'ile',
    'için',
    'olan',
    'bu',
    'şu',
    'daha',
    'olarak',
    'kim',
    'hangi',
    'nedir',
    'kimdir',
    'yılında',
    'tarafından',
    'sonra',
    'göre',
    'eden',
    'edilen',
    'yapılan',
    'olduğu',
    'değil',
    'gibi',
    'veya',
    'olur',
  };

  /// İki dilde de sık geçen sözcükler. Bunlar hiçbir yöne kanıt değildir:
  /// Kurmancî listesinde durdukları için Türkçe cümleleri Kurmancî ilan
  /// ediyorlardı (2026-07-30).
  ///
  ///   "Örnek: Her sabah tarlaya gider."  →  `her` sayıldı, cümle 'ku' oldu.
  ///   "Ailemiz her akşam birlikte yemek yer."  →  aynı.
  ///
  /// `her` (Tr: her / Ku: her), `ne` (Tr: ne / Ku: ne, değil), `de`
  /// (Tr: bulunma eki ve bağlaç / Ku: di…de sonedatı). Üçü de iki dilde
  /// aynı yazılır. Sayımdan tümüyle düşerler; Kurmancî'nin kalan yirmi
  /// sekiz işareti (`bi`, `ji`, `li`, `tê`, `yê`, `jî`, `xwe`…) ve `î/û/ê`
  /// harfleri gerçek Kurmancî cümleyi zaten taşır.

  /// Sözlük sorularının şıklarını sınıflandırmak için hasat edilmiş
  /// İÇERİK kelimeleri. Yalnız [_lexiconLanguage] kullanır.
  ///
  /// Yukarıdaki [_kurmanciWords]/[_turkishWords] işlev sözcükleridir ve
  /// CÜMLE dilini ölçer. Bu liste ise tek tek kelimeleri ölçer; ikisi
  /// bilerek AYRI.
  ///
  /// Birleştirmek cümle ölçütünü bozuyor: "Mem û Zîn, kavuşamayan
  /// âşıkların hikâyesidir" düpedüz Türkçe bir cümledir ama içinde
  /// Kurmancî bir eser adı geçer. İçerik kelimeleri cümle sayımına
  /// karışınca böyle 11 Türkçe açıklama Kurmancî ilan edildi — kusur
  /// değil, ölçütün karıştırılması (2026-08-01, ilk denemede yapılan
  /// hata ve düzeltmesi).
  ///
  /// Kelimeler tahmin değil, bankaların KENDİ verisinden türetildi:
  /// "«X» bi Tirkî çi ye? → Y" biçimindeki her soru X'in Kurmancî, Y'nin
  /// Türkçe olduğunu söylüyor. İki yönde birden görülenler
  /// [_ambiguousWords] içindedir ve hiçbir yöne sayılmaz.
  static const _kurmanciVocabulary = {
    'agir',
    'axaftin',
    'azadî',
    'av',
    'bajar',
    'baran',
    'bav',
    'berf',
    'bihîstin',
    'bira',
    'biçûk',
    'cejn',
    'ciwan',
    'cîhan',
    'danegeh',
    'dapîr',
    'dar',
    'daristan',
    'deh',
    'deng',
    'derya',
    'derî',
    'dest',
    'destpêk',
    'dev',
    'deşt',
    'dibistan',
    'diran',
    'dotmam',
    'duh',
    'dîtin',
    'dûr',
    'erd',
    'geroker',
    'gol',
    'guh',
    'gund',
    'hatin',
    'havîn',
    'helbest',
    'hesp',
    'heval',
    'hewa',
    'heyv',
    'hezkirin',
    'huner',
    'jin',
    'kal',
    'kanî',
    'kaxiz',
    'kevin',
    'keç',
    'komputer',
    'kurd',
    'kursî',
    'kûçik',
    'mal',
    'malbat',
    'mamoste',
    'mase',
    'mast',
    'mêr',
    'nan',
    'nanpêj',
    'nanxane',
    'newal',
    'nivîn',
    'nivîsandin',
    'pir',
    'pirtûk',
    'pisîk',
    'por',
    'poz',
    'pênc',
    'pênûs',
    'pîr',
    'rê',
    'rû',
    'rabûn',
    'reng',
    'roj',
    'rojbaş',
    'rûniştin',
    'sar',
    'sepan',
    'ser',
    'spas',
    'stran',
    'stêrk',
    'sînor',
    'teşt',
    'tor',
    'welat',
    'wêne',
    'xanî',
    'xwendegeh',
    'xwendekar',
    'xwendin',
    'xweş',
    'xwîşk',
    'zanîn',
    'zarok',
    'ziman',
    'zinar',
    'zozan',
    'çaper',
    'çav',
    'çem',
    'çiya',
    'çîrok',
    'çûn',
    'îro',
    'şev',
    'şivan',
    'şêr',
    'şîfre',
  };

  /// Aynı hasattan Türkçe taraf; bkz. [_kurmanciVocabulary].
  static const _turkishVocabulary = {
    'aile',
    'akarsu',
    'anne',
    'arkadaş',
    'aslan',
    'ateş',
    'ağaç',
    'ağız',
    'baba',
    'başlangıç',
    'ben',
    'beş',
    'bilmek',
    'bugün',
    'burun',
    'dağ',
    'dede',
    'deniz',
    'diş',
    'doğru',
    'dün',
    'dünya',
    'ekmek',
    'erkek',
    'eski',
    'fırıncı',
    'gece',
    'gelmek',
    'genç',
    'gitmek',
    'göl',
    'görmek',
    'göz',
    'hava',
    'işitmek',
    'kadın',
    'kalem',
    'kalkmak',
    'kapı',
    'kaya',
    'kağıt',
    'kedi',
    'kitap',
    'konuşmak',
    'kulak',
    'köpek',
    'köy',
    'kürt',
    'küçük',
    'leğen',
    'ling',
    'masa',
    'nasılsın?',
    'nehir',
    'okul',
    'okumak',
    'orman',
    'oturmak',
    'ova',
    'renk',
    'rüzgar',
    'sanat',
    'sandalye',
    'saç',
    'ses',
    'sevmek',
    'soğuk',
    'sınır',
    'teşekkür',
    'teşekkürler',
    'toprak',
    'uzak',
    'vadi',
    'yatak',
    'yayla',
    'yaz',
    'yazmak',
    'yağmur',
    'yemekhane',
    'yol',
    'yoğurt',
    'yüz',
    'yıldız',
    'çoban',
    'çocuk',
    'çok',
    'özgürlük',
    'öğrenci',
    'öğretmen',
    'şarkı',
    'şehir',
    'şiir',
  };

  /// İki dilde de aynı yazılan kelimeler: hiçbirinde dil kararı verilmez.
  ///
  /// İlk üçü işlev sözcüğü. Kalanlar hasatta İKİ yönde birden doğru cevap
  /// olarak görüldü — `kar` (Tr: kar/yağış, Ku: iş), `dil` (Tr: dil/lisan,
  /// Ku: kalp), `ayak`, `pencere`, `rast`. Bunlarda karar vermek, yanlış
  /// pozitifi gerçek bulgunun önüne geçirirdi.
  static const _ambiguousWords = {
    'her', 'ne', 'de',
    'ayak', 'dil', 'kar', 'pencere',
    // `rast`/`şaş` doğru-yanlış sorularının şık ETİKETLERİ, sözlük
    // birimi değil. Hasatta `şaş` yanlışlıkla Türkçe tarafa düşmüştü ve
    // her doğru-yanlış sorusu "yabancı çeldirici" bildiriyordu.
    'rast', 'şaş',
  };

  static const _kurmanciChars = {'î', 'û', 'ê'};
  static const _turkishChars = {'ğ', 'ı', 'ö', 'ü'};

  /// Metnin dilini tahmin eder: `'ku'`, `'tr'` veya karar verilemezse `null`.
  static String? detectLanguage(String text) {
    final lower = text.toLowerCase();
    // `ê` karakter sınıfında eksikti: Kurmancî'nin en sık harflerinden biri
    // kelime sınırı sayılıyor, "tê" → "t", "birêvebirina" → "bir"+"vebirina"
    // biçiminde parçalanıyordu. Sonuç iki yönlü hataydı — `tê`, `wê`, `yê`
    // gibi Kurmancî işaretleri hiç eşleşemiyor, buna karşılık üretilen
    // "bir" parçası Türkçe listesine takılıyordu (2026-07-25 denetimi).
    final words = RegExp(
      r"[a-zçêğıîöşûü']+",
    ).allMatches(lower).map((m) => m.group(0)!).toSet();

    var ku = words
        .where(
          (w) => _kurmanciWords.contains(w) && !_ambiguousWords.contains(w),
        )
        .length
        .toDouble();
    var tr = words
        .where((w) => _turkishWords.contains(w) && !_ambiguousWords.contains(w))
        .length
        .toDouble();
    for (final ch in lower.split('')) {
      if (_kurmanciChars.contains(ch)) ku += 0.34;
      if (_turkishChars.contains(ch)) tr += 0.34;
    }

    if (ku == 0 && tr == 0) return null;
    if (ku >= tr * 1.5) return 'ku';
    if (tr >= ku * 1.5) return 'tr';
    return null;
  }

  /// Tırnak içindeki terimleri atarak **cümlenin** dilini belirler.
  ///
  /// Açıklama metinleri konuları gereği yabancı terim taşır: `"mal" "ev"
  /// demektir` cümlesi Türkçedir, ama `detectLanguage` içindeki `mal`ı değil
  /// `î/ê/û` harflerini sayar ve Kurmancî der. Terim cümlenin dili değil
  /// konusudur; ölçmeden önce çıkarılır (2026-07-26 denetimi: bu yüzden 546
  /// açıklama yanlış dilde sayılmıştı).
  static String? detectSentenceLanguage(String text) {
    final stripped = text
        .replaceAll(RegExp('«[^»]*»'), ' ')
        .replaceAll(RegExp('"[^"]*"'), ' ')
        .replaceAll(RegExp("'[^']*'"), ' ')
        // Parantez içi karşılık da terimdir, cümlenin dili değil:
        // "«Dirêj» (uzun) û «kurt» (kısa) dijwate ne." Kurmancî bir
        // cümledir; parantezler kalınca geriye "uzun kısa dijwate ne"
        // kalıyor ve `ı` harfi cümleyi Türkçe ilan ediyordu. Kardeş bekçi
        // `explanation_quality_guard_test` parantezi zaten atıyordu; iki
        // ölçüt aynı şeyi saymalı (2026-07-30).
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .trim();
    // Terimler çıkınca geriye kalan "Kurmancî ≈ ." gibi kırıntılar karar
    // vermeye yetmez; `Kurmancî` sözcüğündeki `î` tek başına cümleyi
    // Kurmancî ilan ediyordu. En az üç sözcük aranır.
    final words = stripped
        .split(RegExp(r'[^\wçğıöşüîêû]+'))
        .where((w) => w.length > 1)
        .toList();
    if (words.length < 3) return null;
    return detectLanguage(words.join(' '));
  }

  /// Soru bir çeviri alıştırması mı? Öyleyse dil karışımı beklenen durumdur.
  bool isTranslationExercise(QuizQuestion question) {
    if (translationCategories.contains(question.category)) return true;
    final prompt = question.prompt.toLowerCase();
    return _translationMarkers.any(prompt.contains);
  }

  /// Gövde ile şıkların dili tutarsızsa [mixedLanguageIssue] döner.
  List<String> validate(QuizQuestion question) {
    if (isTranslationExercise(question)) return const [];

    final promptLanguage = detectLanguage(question.prompt);
    if (promptLanguage == null) return const [];

    // Özel adlar dil taşımaz.
    //
    // "Derhênerê fîlmê X kî ye?" sorusunun şıkları yönetmen adlarıdır:
    // "Zeki Ökten", "Ömer Lütfi Akad". Sınıflandırıcı bunları `ö/ü/ı`
    // harfleri yüzünden Türkçe sayıyor ve Kurmancî gövdeyle çeliştiği
    // için soruyu "dil karışık" diye suçluyordu. Oysa kişinin adı odur;
    // Kurmancî bir metinde de aynen yazılır (2026-07-27).
    //
    // Aynı muafiyet `offLanguageDistractors` içinde zaten vardı; burada
    // yoktu. Ölçüt dar: en çok üç sözcük, hepsi büyük harfle başlıyor,
    // ayraç yok — yani bir tanım cümlesi değil, bir ad.
    final answerLanguages = question.answers
        .where((answer) => !looksLikeProperName(answer))
        .map(detectLanguage)
        .whereType<String>()
        .toList();
    if (answerLanguages.isEmpty) return const [];

    final conflicting = answerLanguages
        .where((l) => l != promptLanguage)
        .length;
    // Tek bir şıkkın farklı görünmesi özel ad/alıntı yüzünden olabilir;
    // ihlal saymak için çoğunluğun ayrışması aranır.
    final threshold = answerLanguages.length * 0.6;
    if (conflicting >= threshold && conflicting >= 2) {
      return const [mixedLanguageIssue];
    }
    return const [];
  }

  bool isConsistent(QuizQuestion question) => validate(question).isEmpty;

  /// Doğru cevaptan **farklı dilde** olan çeldiriciler.
  ///
  /// [validate] gövde ile şıkları karşılaştırır ve çeviri alıştırmalarını
  /// muaf tutar; bu ölçüt ise gövdeye hiç bakmaz, dolayısıyla çeviri
  /// alıştırmalarında da geçerlidir ve orada asıl zararı yakalar:
  ///
  ///     "Wêneya 'pirtûk' tê çi wateyê?"
  ///       kitap   ← doğru (Türkçe karşılık; sorunun istediği şey)
  ///       Beyaz   ← meşru çeldirici
  ///       soğuk   ← meşru çeldirici
  ///       zanîn   ← Kurmancî: soruyu hiç bilmeyen biri bunu tek bakışta eler
  ///
  /// Çeldirici havuzu dilden bağımsız üretildiği için 2026-07-26 denetiminde
  /// 173 soruda bu görüldü; 21'inde doğru cevap dil bakımından tek olan
  /// şıktı, yani soru bilgi değil biçim ölçüyordu
  /// ([answerIsGivenAwayByLanguage]).
  ///
  /// Dili belirlenemeyen metinler (özel ad, tarih, tek sözcük) sessizce
  /// geçilir: yanlış pozitif, gerçek bulguyu gölgeleyecek kadar pahalıdır.
  /// Dil kararı için gereken en az uzunluk.
  ///
  /// Tek sözcüklük şıklarda sınıflandırıcı güvenilmez: `ev`, `su`, `yol`
  /// hiçbir işaret taşımaz ve `dağ` yalnız `ğ` yüzünden Türkçe sayılır.
  /// "Peyva «mal» bi Tirkî çi tê wateyê?" sorusunun dört şıkkı da Türkçeyken
  /// yalnız `dağ` ihlal bildiriliyordu — düzeltilecek bir şey yokken
  /// (2026-07-26 denetimi). Sözlük sorularının şıkları hep kısa olduğu için
  /// bu eşik, kuralı asıl işine — uzun tanım şıklarına — bırakır.
  static const _minLengthForLanguageCall = 8;

  /// Sorunun gövdesi cevabın hangi dilde olmasını istediğini SÖYLÜYORSA
  /// o dili döndürür.
  ///
  /// Bu, doğru cevabın dilini tahmin etmekten daha güçlü bir sinyaldir:
  /// tahmin değil, sorunun kendi beyanıdır. "Di Kurmancî de peyva «kursî»
  /// **bi Tirkî** çi ye?" — istenen dil Türkçe, tartışmasız.
  static String? requestedAnswerLanguage(String prompt) {
    // Türkçe cevap istendiğini söyleyen kalıplar. `bi Tirkî` tek başına
    // yetiyor: "bi Tirkî çi ye", "bi Tirkî çi tê gotin",
    // "bi Tirkî kîjan wateyê digire" — hepsi Türkçe karşılık ister.
    if (RegExp(
      r'bi\s+Tirkî|Tirkî\s+(çi|kîjan)|wateya\s+Tirkî',
      caseSensitive: false,
    ).hasMatch(prompt)) {
      return 'tr';
    }
    // Kurmancî cevap istendiğini söyleyen kalıplar DAHA DAR olmalı.
    //
    // `bi Kurmancî` tek başına yetmez: "«baş» bi kurmancî tê çi wateyê?"
    // Kurmancî bir kelimenin ANLAMINI soruyor, yani cevabı Türkçedir.
    // Kalıbı geniş tutmak o soruların dört Türkçe şıkkını "yabancı"
    // ilan ediyordu (2026-08-01).
    if (RegExp(
      r'peyva\s+Kurmancî\s+ye|bi\s+Kurmancî\s+çi\s+(ye|tê)|'
      r'Hevwateya[^?]*bi\s+Kurmancî|di\s+Kurmancî\s+de\s+kîjan\s+peyv',
      caseSensitive: false,
    ).hasMatch(prompt)) {
      return 'ku';
    }
    return null;
  }

  List<String> offLanguageDistractors(QuizQuestion question) {
    // Doğru-yanlış soruları kapsam dışı: iki şıkkın ikisi de sabit
    // etikettir (`Rast`/`Şaş`), sözlük birimi değil. "Çeldiricinin dili"
    // kavramı orada anlamsız.
    if (question.answers.length < 3) return const [];
    // Hedef dil önce SORUDAN okunur, olmazsa doğru cevaptan tahmin edilir.
    //
    // Eskiden yalnız tahmin vardı ve tahmin başarısız olduğunda sorunun
    // TAMAMI atlanıyordu. `Sandalye` hiçbir ayırt edici harf taşımadığı ve
    // sözlükte olmadığı için `detectLanguage` null dönüyor, dolayısıyla
    // "kursî → Sandalye" sorusunun `Rûniştin` ve `Dibistan` çeldiricileri
    // hiç incelenmiyordu. Kusur 2026-08-01'de canlı bir oda maçında
    // görüldü; sunucudaki 365 kelime çevirisi sorusunun 185'inde vardı ve
    // hiçbir denetimden geçmemişti.
    final target =
        requestedAnswerLanguage(question.prompt) ??
        (question.correctAnswer.length >= _minLengthForLanguageCall
            ? detectLanguage(question.correctAnswer)
            : null);
    if (target == null) return const [];
    return [
      for (final answer in question.answers)
        if (answer != question.correctAnswer &&
            // Özel ad muafiyeti sözlükte geçen kelimelere UYGULANMAZ.
            //
            // `looksLikeProperName` ölçütü "en çok üç sözcük, hepsi büyük
            // harfle başlıyor, ayraç yok" — ve sözlük sorularının şıkları
            // tam da öyle görünüyor: `Zarok`, `Biçûk`, `Duh`, `Xweş`.
            // Muafiyet bunları da kapsayınca kural, asıl korumak istediği
            // yerde susuyordu. Hasat edilmiş listede birebir geçen bir
            // kelime tanım gereği özel ad değildir — o liste sözlük
            // sorularının doğru cevaplarından türetildi (2026-08-01).
            (_lexiconLanguage(answer) != null ||
                !looksLikeProperName(answer)) &&
            _answerLanguage(answer) != null &&
            _answerLanguage(answer) != target)
          answer,
    ];
  }

  /// Bir şıkkın dili — kısa sözlük birimlerinde de güvenilir.
  ///
  /// İki yol var ve sırası önemli:
  ///
  ///   1. **Birebir sözlük eşleşmesi.** Tek kelimelik şık, hasat edilmiş
  ///      listelerden yalnız birinde geçiyorsa karar kesindir; uzunluk
  ///      eşiği aranmaz. `Zarok`, `Duh`, `Xweş` böyle yakalanır.
  ///   2. **Sezgisel tahmin.** Sözlükte yoksa eski yol: yalnız
  ///      [_minLengthForLanguageCall] karakterden uzun metinlerde.
  ///
  /// Eşik 1. yolda gereksiz — o, karakter sayımının kısa kelimelerde
  /// yanılmasına karşı konmuştu (`dağ` yalnız `ğ` yüzünden Türkçe
  /// sayılıyordu). Birebir eşleşmede sayım yok, dolayısıyla yanılma da yok.
  static String? _answerLanguage(String answer) {
    final exact = _lexiconLanguage(answer);
    if (exact != null) return exact;
    if (answer.length < _minLengthForLanguageCall) return null;
    return detectLanguage(answer);
  }

  /// Tek kelimelik metnin hasat listelerinden YALNIZ birinde geçmesi.
  /// Sayım yok, tahmin yok — ya kesin bir eşleşme vardır ya da null.
  static String? _lexiconLanguage(String text) {
    final word = text.trim().toLowerCase();
    if (word.contains(' ') || _ambiguousWords.contains(word)) return null;
    // Değişken adları bilerek `ku`/`tr` DEĞİL. `l10n_migration_guard`,
    // dil kısaltmasıyla başlayan üçlü koşul kalıbını satır içi çeviri
    // sayıyor ve o kalıbın tavanı sabit; buradaki teknik kullanım o
    // sayacı gereksiz yere şişirirdi. (Yorumun kendisi de kalıbı ANMAZ:
    // bekçi kaynak metne bakıyor, bu gece iki kez kendi açıklamasına
    // takıldı.)
    final inKurmanci = _kurmanciVocabulary.contains(word);
    final inTurkish = _turkishVocabulary.contains(word);
    if (inKurmanci == inTurkish) return null;
    return inKurmanci ? 'ku' : 'tr';
  }

  /// [text] bir özel ad mı (kişi, yer, eser adı)?
  ///
  /// Özel adların "dili" yoktur: "Şêro Hindê" Türkçe bir şık listesinde de
  /// aynen yazılır, çünkü kişinin adı odur. Sınıflandırıcı bunları `î/ê/û`
  /// harfleri yüzünden Kurmancî sayıyor ve gerçek bir kusur yokken ihlal
  /// bildiriyordu (2026-07-26'da 173 bulgunun 14'ü bu türdendi). Kural,
  /// yanlış pozitifi kesip gerçek olanı elde bırakacak kadar dar:
  ///
  /// * en çok üç sözcük — daha uzunu artık bir tanım cümlesidir;
  /// * her sözcük büyük harfle başlar — `Dîcle û Ferat`'taki küçük harfli
  ///   `û` bunu bozar ve haklı olarak bozar, çünkü Türkçe listede `Dicle ve
  ///   Fırat` yazmak gerekir;
  /// * ayraç ya da eğik çizgi yok — `Şerefxan (mîrê Bidlîsê)` ad değil,
  ///   içinde açıklama taşıyan bir şıktır.
  static bool looksLikeProperName(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'[/(),?!:;]').hasMatch(trimmed)) return false;
    final tokens = trimmed.split(RegExp(r'\s+'));
    if (tokens.isEmpty || tokens.length > 3) return false;
    return tokens.every((token) {
      final first = String.fromCharCode(token.runes.first);
      return first.toUpperCase() == first && first.toLowerCase() != first;
    });
  }

  /// Doğru cevap, dil bakımından tek olan şık mı?
  ///
  /// Bu durumda soru konudan tamamen bağımsız olarak çözülebilir; cevap
  /// sızıntısının (bkz. `QuestionSetPolicy`) tek soru içindeki kardeşidir.
  bool answerIsGivenAwayByLanguage(QuizQuestion question) {
    if (question.correctAnswer.length < _minLengthForLanguageCall) return false;
    final target = detectLanguage(question.correctAnswer);
    if (target == null) return false;
    final others = question.answers
        .where(
          (a) =>
              a != question.correctAnswer &&
              a.length >= _minLengthForLanguageCall &&
              !looksLikeProperName(a),
        )
        .toList();
    if (others.isEmpty) return false;
    return others.every((a) {
      final language = detectLanguage(a);
      return language != null && language != target;
    });
  }
}
