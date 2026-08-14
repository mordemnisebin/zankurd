import '../l10n/explanation_ku.dart';
import '../l10n/explanation_overrides.dart';
import '../l10n/strings.dart';
import 'question_metadata.dart';

enum QuestionType {
  multipleChoice,
  trueFalse,
  visual,
  wordOrdering,
  fillInBlank,
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctAnswer,
    required this.explanation,
    this.explanationKu,
    this.explanationTr,
    this.promptTr,
    this.answersTr,
    this.correctAnswerTr,
    this.hintKu,
    this.hintTr,
    this.audioUrl,
    this.type = QuestionType.multipleChoice,
    this.imageUrl,
    this.difficulty = 2,
    this.metadata,
  });

  final String id;
  final String category;
  final String prompt;
  final List<String> answers;
  final String correctAnswer;
  final String explanation;
  final String? explanationKu;
  final String? explanationTr;

  /// Sorunun Türkçe karşılığı. Yoksa [prompt] (Kurmancî) kullanılır.
  ///
  /// 2026-07-25 denetimi: arayüz TR seçilebiliyor ama soruların %100'ü
  /// Kurmancî. TR seçen kullanıcı Türkçe menülerde gezip Kurmancî soruyla
  /// karşılaşıyordu. Model tek bir `prompt` alanı taşıdığı için bu bir
  /// içerik eksiği değil, *şema* eksiğiydi: çeviri yazılacak yer yoktu.
  ///
  /// Alanlar bilinçli olarak nullable: banka kademeli çevrilecek, çevirisi
  /// olmayan soru Kurmancî gösterilir — eksik çeviri, boş ekrandan iyidir.
  final String? promptTr;

  /// Şıkların Türkçe karşılıkları. [answers] ile aynı uzunlukta olmalı;
  /// değilse yok sayılır (bkz. [answersFor]).
  final List<String>? answersTr;

  /// Doğru cevabın Türkçe karşılığı — [answersTr] içinde yer almalı.
  final String? correctAnswerTr;

  final String? hintKu;
  final String? hintTr;
  final String? audioUrl;
  final QuestionType type;
  final String? imageUrl;
  final int difficulty;

  /// Editör/kalite meta verisi (opsiyonel, geriye uyumlu). Eski verilerde
  /// `null`'dır ve [ContentQualityPolicy] bunu "uygun ama doğrulanmamış"
  /// olarak ele alır.
  final QuestionMetadata? metadata;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
  bool get hasAudio => audioUrl != null && audioUrl!.trim().isNotEmpty;

  /// Doğru cevap istemciye hiç gönderilmemiş (`_roomQuestionFromRow`
  /// deseni — sunucu odalarında hile önlemi için `correctAnswer: ''`
  /// verilir, gerçek doğrulama sunucuda yapılır). Böyle bir soru yerel
  /// olarak (sunucu doğrulaması olmadan) yeniden puanlanamaz.
  bool get hasHiddenAnswer => correctAnswer.trim().isEmpty;
  bool get hasHint =>
      (hintKu != null && hintKu!.trim().isNotEmpty) ||
      (hintTr != null && hintTr!.trim().isNotEmpty);

  String get promptText => prompt;

  /// Seçili dile göre soru metni. Çeviri yoksa Kurmancî'ye düşer.
  String promptFor({required bool isKu}) {
    if (isKu) return prompt;
    final translated = promptTr?.trim();
    return (translated == null || translated.isEmpty) ? prompt : translated;
  }

  /// Türkçe şık çevirisi *bütün olarak* tutarlı mı?
  ///
  /// Tutarlılık tek tek alanlarda değil, küme olarak değerlendirilir:
  /// şıklar çevrilip doğru cevap çevrilmezse (ya da çevrilen doğru cevap
  /// şıklar arasında bulunmazsa) hiçbir şık doğru işaretlenmez ve tur
  /// sessizce bozulur. Bu yüzden "kısmen çevrilmiş" diye bir durum yok:
  /// ya hepsi Türkçe, ya hepsi Kurmancî.
  bool get _hasConsistentTurkishAnswers {
    final translated = answersTr;
    if (translated == null || translated.length != answers.length) return false;
    if (translated.any((option) => option.trim().isEmpty)) return false;
    final translatedCorrect = correctAnswerTr?.trim();
    if (translatedCorrect == null || translatedCorrect.isEmpty) return false;
    return translated.map((o) => o.trim()).contains(translatedCorrect);
  }

  /// Seçili dile göre şıklar. Çeviri kümesi tutarlı değilse tamamı
  /// Kurmancî döner — yarısı çevrilmiş bir şık listesi, hiç çevrilmemiş
  /// olandan daha kafa karıştırıcıdır.
  List<String> answersFor({required bool isKu}) {
    if (isKu || !_hasConsistentTurkishAnswers) return answers;
    return answersTr!;
  }

  /// Seçili dile göre doğru cevap. [answersFor] ile daima aynı kümeden
  /// gelir; ikisi birlikte düşer ya da birlikte çevrilir.
  String correctAnswerFor({required bool isKu}) {
    if (isKu || !_hasConsistentTurkishAnswers) return correctAnswer;
    return correctAnswerTr!.trim();
  }

  /// Alanların bir bölümünü değiştirerek kopya üretir. Yalnız [localized]
  /// yansıtması için gereken alanlar parametreleşmiştir; gerisi taşınır.
  QuizQuestion copyWith({
    String? prompt,
    List<String>? answers,
    String? correctAnswer,
  }) {
    return QuizQuestion(
      id: id,
      category: category,
      prompt: prompt ?? this.prompt,
      answers: answers ?? this.answers,
      correctAnswer: correctAnswer ?? this.correctAnswer,
      explanation: explanation,
      explanationKu: explanationKu,
      explanationTr: explanationTr,
      promptTr: promptTr,
      answersTr: answersTr,
      correctAnswerTr: correctAnswerTr,
      hintKu: hintKu,
      hintTr: hintTr,
      audioUrl: audioUrl,
      type: type,
      imageUrl: imageUrl,
      difficulty: difficulty,
      metadata: metadata,
    );
  }

  /// Soruyu seçili dile *yansıtır*: `prompt`, `answers` ve `correctAnswer`
  /// alanları hedef dilde doldurulmuş yeni bir kopya döner.
  ///
  /// Dili çağrı yerine taşımak yerine tek noktada yansıtmak bilinçli bir
  /// tercih: quiz ekranı doğru/yanlış kararını onlarca yerde `answer ==
  /// question.correctAnswer` karşılaştırmasıyla veriyor. Bu karşılaştırmalara
  /// dil parametresi eklemek, birinin unutulması hâlinde sessizce yanlış
  /// puanlamaya yol açardı. Yansıtma ile aşağı akıştaki tüm mantık
  /// değişmeden doğru kalır.
  ///
  /// Çevirisi eksik sorularda alanlar Kurmancî kalır (bkz. [answersFor]).
  QuizQuestion localized({required bool isKu}) {
    if (isKu) return this;
    final localizedAnswers = answersFor(isKu: false);
    if (identical(localizedAnswers, answers) &&
        promptFor(isKu: false) == prompt) {
      return this;
    }
    return copyWith(
      prompt: promptFor(isKu: false),
      answers: localizedAnswers,
      correctAnswer: correctAnswerFor(isKu: false),
    );
  }

  /// Bu soru [isKu] olmayan dilde tam olarak gösterilebiliyor mu?
  /// Çeviri kapsamını ölçen testler bunu kullanır.
  bool get hasTurkishTranslation {
    final translatedPrompt = promptTr?.trim();
    if (translatedPrompt == null || translatedPrompt.isEmpty) return false;
    return _hasConsistentTurkishAnswers;
  }

  List<String> get displayAnswers {
    if (type == QuestionType.trueFalse || answers.length < 3) {
      return List.unmodifiable(answers);
    }

    final rotated = List<String>.of(answers);
    final offset = _stableAnswerOffset(rotated.length);
    return List.unmodifiable([
      ...rotated.skip(offset),
      ...rotated.take(offset),
    ]);
  }

  String optionKeyForAnswer(String answer) {
    // Cümle kurmada `answers` şık listesi değil kelime havuzudur;
    // gönderilen değer bir seçenek metni değil, kullanıcının birleştirdiği
    // cümledir. Havuzda böyle bir dize aramak `indexOf`'u hep -1'e
    // düşürüyor, cevap sessizce boş dizeye indirgeniyor ve bu tip sorular
    // yerel puanlama hattında HİÇ doğru işaretlenemiyordu (2026-08-14
    // denetimi). Ham cümle olduğu gibi taşınır; karşılaştırma
    // `correctAnswer`la doğrudan yapılır (bkz. `MockZanKurdRepository`).
    if (type == QuestionType.wordOrdering) return answer;
    final index = answers.indexOf(answer);
    return switch (index) {
      0 => 'A',
      1 => 'B',
      2 => 'C',
      3 => 'D',
      _ => '',
    };
  }

  String? answerForOptionKey(String? optionKey) {
    final index = switch (optionKey) {
      'A' => 0,
      'B' => 1,
      'C' => 2,
      'D' => 3,
      _ => -1,
    };
    return index >= 0 && index < answers.length ? answers[index] : null;
  }

  QuizQuestion withRevealedAnswer({
    required String correctAnswer,
    String? explanation,
    String? explanationKu,
    String? explanationTr,
    String? hintKu,
    String? hintTr,
    String? audioUrl,
  }) {
    return QuizQuestion(
      id: id,
      category: category,
      prompt: prompt,
      answers: answers,
      correctAnswer: correctAnswer,
      explanation: explanation ?? this.explanation,
      explanationKu: explanationKu ?? this.explanationKu,
      explanationTr: explanationTr ?? this.explanationTr,
      hintKu: hintKu ?? this.hintKu,
      hintTr: hintTr ?? this.hintTr,
      audioUrl: audioUrl ?? this.audioUrl,
      type: type,
      imageUrl: imageUrl,
      difficulty: difficulty,
      metadata: metadata,
    );
  }

  int _stableAnswerOffset(int length) {
    final seed = id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    final offset = seed % length;
    return offset == 0 ? 1 : offset;
  }

  String get levelPrefix {
    return switch (difficulty) {
      1 => 'Easy',
      2 => 'Medium',
      3 => 'Hard',
      _ => 'Medium',
    };
  }

  /// Soru kartındaki tip rozeti.
  ///
  /// Metinler anahtar defterinde durur. Bir zamanlar burada satır içiydi
  /// ve iki kusur taşıyordu: çoktan seçmelinin Kurmancîsi 'Hilbijarin'
  /// yazılmıştı (doğrusu 'Hilbijartin' — hilbijartin fiil kökünden), ve
  /// yalnız Türkçe döndüren ölü bir ikiz (`typeLabel`) üretimde hiç
  /// çağrılmadığı hâlde testle canlı tutuluyordu. Defterdeki metinler
  /// Kurmancî alfabe bekçisinin ve `Tr.missingFor` bütünlük testinin
  /// kapsamına girer; satır içi olanlar girmiyordu (2026-07-31 denetimi).
  String typeLabelLocalized(bool isKu) {
    return Tr.forKu(switch (type) {
      QuestionType.multipleChoice => K.qTypeMultipleChoice,
      QuestionType.trueFalse => K.qTypeTrueFalse,
      QuestionType.visual => K.qTypeVisual,
      QuestionType.wordOrdering => K.qTypeWordOrdering,
      QuestionType.fillInBlank => K.qTypeFillInBlank,
    }, isKu);
  }

  String getLocalizedExplanation(bool isKu) {
    // Öncelik: soruya özel açıklama (DB) > elle yazılmış override > ham metin.
    // Şablon-üretimi (bilgi taşımayan) açıklamalar her seviyede elenir;
    // boş dönüş "açıklama gösterme" demektir.
    final db = isKu ? explanationKu : explanationTr;
    if (db != null && db.trim().isNotEmpty && !isTemplateExplanation(db)) {
      return db;
    }
    return resolveRawExplanation(id: id, explanation: explanation, isKu: isKu);
  }

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      category: json['category'] as String,
      prompt: json['prompt'] as String,
      answers: List<String>.from(json['answers'] as List),
      correctAnswer: json['correctAnswer'] as String,
      explanation:
          (json['explanation'] as String?) ??
          (json['explanationTr'] as String?) ??
          (json['explanationKu'] as String?) ??
          '',
      explanationKu: json['explanationKu'] as String?,
      explanationTr: json['explanationTr'] as String?,
      // Çok dilli alanlar opsiyoneldir; eski kayıtlarda hiç bulunmaz.
      promptTr: json['promptTr'] as String?,
      answersTr: (json['answersTr'] as List?)?.cast<String>(),
      correctAnswerTr: json['correctAnswerTr'] as String?,
      hintKu: json['hintKu'] as String?,
      hintTr: json['hintTr'] as String?,
      audioUrl: json['audioUrl'] as String?,
      type: QuestionType.values.byName(
        (json['type'] as String?) ?? 'multipleChoice',
      ),
      imageUrl: json['imageUrl'] as String?,
      difficulty: (json['difficulty'] as num?)?.toInt() ?? 2,
      metadata: json['metadata'] == null
          ? null
          : QuestionMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'prompt': prompt,
    'answers': answers,
    'correctAnswer': correctAnswer,
    'explanation': explanation,
    if (explanationKu != null) 'explanationKu': explanationKu,
    if (explanationTr != null) 'explanationTr': explanationTr,
    if (promptTr != null) 'promptTr': promptTr,
    if (answersTr != null) 'answersTr': answersTr,
    if (correctAnswerTr != null) 'correctAnswerTr': correctAnswerTr,
    if (hintKu != null) 'hintKu': hintKu,
    if (hintTr != null) 'hintTr': hintTr,
    if (audioUrl != null) 'audioUrl': audioUrl,
    'type': type.name,
    if (imageUrl != null) 'imageUrl': imageUrl,
    'difficulty': difficulty,
    if (metadata != null) 'metadata': metadata!.toJson(),
  };
}

/// Üretim-şablonu, bilgi taşımayan açıklama desenleri. Bunları göstermek
/// hiç açıklama göstermemekten kötüdür (özensizlik sinyali verir).
final List<RegExp> _templateExplanationPatterns = [
  RegExp(r"^Ev ravekirin têgeha '.*' nîşan dide\.$"),
  RegExp(r"^'.*' di vê kategoriyê de têgeheke girîng e\.$"),
  RegExp(r"^Têgeha '.*' di qada .* de bi vê ravekirinê tê bikaranîn\.$"),
  RegExp(r"^Ev ravekirin bi '.*' û qada .* re girêdayî ye\.$"),
  // Yalnız doğru cevabı tekrar eden şablonlar (cevap zaten ekranda).
  RegExp(r"^Görsel '.*' kavramını gösterir; doğru yanıt: .*\.$"),
  RegExp(r'iddia doğru değildir; doğru cevap'),
  RegExp(r'^Doğru yanıt: [^.]+\.$'),
  RegExp(r'^Görsel soru ".*" kelimesini pekiştirir\.$'),
  // Döngüsel kategori cümleleri ("X, Y kategorisinde ele alınır").
  RegExp(
    r'(kategorisinde ele alınır|kategorisinde değerlendirilir'
    r'|geçerli bir kavramdır|bir kavram olarak kullanılabilir)\.$',
  ),
  // Canlı DB'deki görsel-soru şablonu.
  RegExp(r'^Pirsa wêneyî peyva'),
];

bool isTemplateExplanation(String text) {
  final t = text.trim();
  return t.isEmpty || _templateExplanationPatterns.any((p) => p.hasMatch(t));
}

/// Ham (tek dilli) açıklama taşıyan yerler (QuizQuestion, AnswerRecord) için
/// ortak çözümleme: override > şablon eleme > yerelleştirme.
String resolveRawExplanation({
  required String id,
  required String explanation,
  required bool isKu,
}) {
  final override = explanationOverrides[id];
  if (override != null) return isKu ? override.ku : override.tr;
  if (isTemplateExplanation(explanation)) return '';
  return isKu ? explanationToKu(explanation) : explanation;
}
