class AnswerRecord {
  const AnswerRecord({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.explanation,
    this.explanationKu,
    this.explanationTr,
    this.responseMs,
    this.pointsEarned = 0,
    this.imageUrl,
    this.adjudicatedCorrect,
  });

  final String id;
  final String category;
  final String prompt;
  final List<String> answers;
  final String correctAnswer;
  final String? selectedAnswer;
  final String explanation;

  /// Sorunun yazılmış açıklamaları.
  ///
  /// Kayıt yalnız ham `explanation`ı taşıyordu ve tur sonu özeti onu kural
  /// motoruna sokuyordu. Oysa sorunun elle yazılmış Kurmancî/Türkçe
  /// açıklaması varsa doğru metin odur: motor yalnız **yedek**tir. Sonuç,
  /// Kurmancî turda özetin `Şirove: <Türkçe cümle>` göstermesiydi — yani
  /// bankada yazılı Kurmancî açıklama hiç kullanılmıyordu (2026-07-27).
  final String? explanationKu;
  final String? explanationTr;

  final int? responseMs;
  final int pointsEarned;
  final String? imageUrl;

  /// Cevap gönderildiği anda repository/yerel fallback tarafından verilen
  /// yetkili karar. Eski kayıtlar için `null` bırakılır ve metin eşitliği
  /// geriye uyumlu yedek olarak kullanılır.
  final bool? adjudicatedCorrect;

  bool get isCorrect =>
      adjudicatedCorrect ??
      (selectedAnswer == correctAnswer && selectedAnswer != null);

  bool get isUnanswered => selectedAnswer == null || selectedAnswer!.isEmpty;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
