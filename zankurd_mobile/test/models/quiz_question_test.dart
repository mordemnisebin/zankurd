import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  group('QuizQuestion', () {
    test('hasImage returns true when imageUrl is not null', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'This is correct',
        imageUrl: 'assets/image.jpg',
      );

      expect(question.hasImage, true);
    });

    test('hasImage returns false when imageUrl is null', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'This is correct',
      );

      expect(question.hasImage, false);
    });

    test('typeLabel returns correct label for multipleChoice', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        explanation: 'This is correct',
      );

      expect(question.typeLabel, 'Şıklı');
    });

    test('typeLabel returns correct label for trueFalse', () {
      const question = QuizQuestion(
        id: 'q_001',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        explanation: 'This is correct',
        type: QuestionType.trueFalse,
      );

      expect(question.typeLabel, 'Doğru/Yanlış');
    });
  });
}
