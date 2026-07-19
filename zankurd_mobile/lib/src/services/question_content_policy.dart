import '../config/category_visibility.dart';
import '../models/quiz_question.dart';

/// Son kullanıcıya gösterilmeden önce sorunun yapısal oynanabilirliğini
/// doğrular. Editör dili ve kategori anlamı ayrı bir editör kontrolüdür.
class QuestionContentPolicy {
  const QuestionContentPolicy();

  bool isPlayable(QuizQuestion question) {
    // Gizli kategori (ör. içeriği hazır olmayan Teknolojî) hiçbir akışta
    // oynanabilir değildir — quiz seçimi, günlük soru ve offline banka
    // sızıntıları bu tek noktadan kapanır.
    if (!isCategoryVisible(question.category)) return false;
    return validate(question).isEmpty;
  }

  List<String> validate(QuizQuestion question) {
    final issues = <String>[];
    if (question.prompt.trim().isEmpty) issues.add('empty_prompt');
    if (question.category.trim().isEmpty) issues.add('empty_category');
    if (question.answers.length < 2) issues.add('too_few_answers');
    if (!question.answers.contains(question.correctAnswer)) {
      issues.add('correct_answer_missing');
    }
    if (question.type == QuestionType.multipleChoice &&
        question.answers.length < 4) {
      issues.add('multiple_choice_requires_four_answers');
    }
    if (question.type == QuestionType.visual && !question.hasImage) {
      issues.add('visual_image_missing');
    }
    return List.unmodifiable(issues);
  }
}
