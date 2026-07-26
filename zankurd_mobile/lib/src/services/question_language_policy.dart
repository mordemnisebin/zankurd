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

    var ku = words.where(_kurmanciWords.contains).length.toDouble();
    var tr = words.where(_turkishWords.contains).length.toDouble();
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

    final answerLanguages = question.answers
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

  List<String> offLanguageDistractors(QuizQuestion question) {
    if (question.correctAnswer.length < _minLengthForLanguageCall) {
      return const [];
    }
    final target = detectLanguage(question.correctAnswer);
    if (target == null) return const [];
    return [
      for (final answer in question.answers)
        if (answer != question.correctAnswer &&
            answer.length >= _minLengthForLanguageCall &&
            !looksLikeProperName(answer) &&
            detectLanguage(answer) != null &&
            detectLanguage(answer) != target)
          answer,
    ];
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
