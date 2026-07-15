class AnswerRecord {
  const AnswerRecord({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.explanation,
    this.responseMs,
    this.pointsEarned = 0,
    this.imageUrl,
  });

  final String id;
  final String category;
  final String prompt;
  final List<String> answers;
  final String correctAnswer;
  final String? selectedAnswer;
  final String explanation;
  final int? responseMs;
  final int pointsEarned;
  final String? imageUrl;

  bool get isCorrect =>
      selectedAnswer == correctAnswer && selectedAnswer != null;

  bool get isUnanswered => selectedAnswer == null || selectedAnswer!.isEmpty;

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
}
