class AnswerRecord {
  const AnswerRecord({
    required this.questionId,
    required this.prompt,
    required this.answers,
    required this.correctAnswer,
    required this.selectedAnswer,
    required this.explanation,
    required this.imageUrl,
    required this.category,
  });

  final String questionId;
  final String prompt;
  final List<String> answers;
  final String correctAnswer;
  final String selectedAnswer;
  final String explanation;
  final String? imageUrl;
  final String category;

  bool get isCorrect => selectedAnswer == correctAnswer;
  bool get isUnanswered => selectedAnswer.isEmpty;
  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;
}
