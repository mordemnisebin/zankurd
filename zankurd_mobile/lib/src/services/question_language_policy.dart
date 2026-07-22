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
    'di', 'bi', 'ku', 'ji', 'li', 'ye', 'ne', 'wê', 'tê', 'çi', 'yê', 'de',
    'her', 'bo', 'yek', 'ew', 'ev', 'bû', 'dike', 'nav', 'navê', 'kîjan',
    'çend', 'were', 'hat', 'hatiye', 'xwe', 'wek', 'jî', 'peyva', 'wateya',
  };

  static const _turkishWords = {
    've', 'bir', 'ile', 'için', 'olan', 'bu', 'şu', 'daha', 'olarak', 'kim',
    'hangi', 'nedir', 'kimdir', 'yılında', 'tarafından', 'sonra', 'göre',
    'eden', 'edilen', 'yapılan', 'olduğu', 'değil', 'gibi', 'veya', 'olur',
  };

  static const _kurmanciChars = {'î', 'û', 'ê'};
  static const _turkishChars = {'ğ', 'ı', 'ö', 'ü'};

  /// Metnin dilini tahmin eder: `'ku'`, `'tr'` veya karar verilemezse `null`.
  static String? detectLanguage(String text) {
    final lower = text.toLowerCase();
    final words = RegExp(
      r"[a-zçğıîöşûü']+",
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
}
