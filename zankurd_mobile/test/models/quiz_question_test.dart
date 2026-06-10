import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
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

  group('MockZanKurdRepository question bank', () {
    test(
      'ships a broad offline question bank instead of the tiny demo set',
      () {
        final repository = MockZanKurdRepository();
        final uniquePrompts = repository.questions
            .map((question) => question.prompt)
            .toSet();
        final visualQuestions = repository.questions
            .where((question) => question.hasImage)
            .toList();

        expect(repository.questions.length, greaterThanOrEqualTo(200));
        expect(uniquePrompts.length, greaterThanOrEqualTo(180));
        expect(visualQuestions.length, greaterThanOrEqualTo(40));
      },
    );

    test('loadQuestions rotates results between calls', () async {
      final repository = MockZanKurdRepository();

      final first = await repository.loadQuestions(limit: 10);
      final second = await repository.loadQuestions(limit: 10);

      expect(
        first.map((question) => question.id),
        isNot(second.map((q) => q.id)),
      );
    });
  });
}
