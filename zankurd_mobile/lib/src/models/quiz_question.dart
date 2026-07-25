import '../l10n/explanation_ku.dart';
import '../l10n/explanation_overrides.dart';
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
  bool get hasHint =>
      (hintKu != null && hintKu!.trim().isNotEmpty) ||
      (hintTr != null && hintTr!.trim().isNotEmpty);

  String get promptText => prompt;

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

  String get typeLabel {
    return switch (type) {
      QuestionType.multipleChoice => 'Şıklı',
      QuestionType.trueFalse => 'Doğru/Yanlış',
      QuestionType.visual => 'Görselli',
      QuestionType.wordOrdering => 'Cümle Kurma',
      QuestionType.fillInBlank => 'Boşluk Doldurma',
    };
  }

  String typeLabelLocalized(bool isKu) {
    return switch (type) {
      QuestionType.multipleChoice => isKu ? 'Hilbijarin' : 'Şıklı',
      QuestionType.trueFalse => isKu ? 'Rast/Xelet' : 'Doğru/Yanlış',
      QuestionType.visual => isKu ? 'Wêneyî' : 'Görselli',
      QuestionType.wordOrdering => isKu ? 'Rêzkirin' : 'Cümle Kurma',
      QuestionType.fillInBlank => isKu ? 'Tijîkirin' : 'Boşluk Doldurma',
    };
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
