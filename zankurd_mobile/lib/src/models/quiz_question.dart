enum QuestionType { multipleChoice, trueFalse, visual }

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.category,
    required this.prompt,
    required this.answers,
    required this.correctAnswer,
    required this.explanation,
    this.type = QuestionType.multipleChoice,
    this.imageUrl,
    this.difficulty = 2,
  });

  final String id;
  final String category;
  final String prompt;
  final List<String> answers;
  final String correctAnswer;
  final String explanation;
  final QuestionType type;
  final String? imageUrl;
  final int difficulty;

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  String get promptText => prompt;

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
    };
  }

  String typeLabelLocalized(bool isKu) {
    return switch (type) {
      QuestionType.multipleChoice => isKu ? 'Hilbijarin' : 'Şıklı',
      QuestionType.trueFalse => isKu ? 'Rast/Xelet' : 'Doğru/Yanlış',
      QuestionType.visual => isKu ? 'Entık' : 'Görselli',
    };
  }
}
