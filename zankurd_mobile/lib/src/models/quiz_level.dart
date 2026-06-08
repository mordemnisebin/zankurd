class QuizLevel {
  const QuizLevel({
    required this.number,
    required this.title,
    required this.category,
    required this.difficultyMin,
    required this.difficultyMax,
    required this.questionCount,
  });

  final int number;
  final String title;
  final String category;
  final int difficultyMin;
  final int difficultyMax;
  final int questionCount;

  String get difficultyLabel {
    if (difficultyMin == difficultyMax) return '$difficultyMin/5';
    return '$difficultyMin-$difficultyMax/5';
  }
}
