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

    test('displayAnswers moves stored first answer for multiple choice', () {
      const question = QuizQuestion(
        id: 'q_shuffle',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Correct', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
        correctAnswer: 'Correct',
        explanation: 'This is correct',
      );

      expect(question.displayAnswers.toSet(), question.answers.toSet());
      expect(question.displayAnswers.first, isNot(question.answers.first));
    });

    test('optionKeyForAnswer keeps backend option keys tied to stored answers', () {
      const question = QuizQuestion(
        id: 'q_shuffle',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Correct', 'Wrong 1', 'Wrong 2', 'Wrong 3'],
        correctAnswer: 'Correct',
        explanation: 'This is correct',
      );

      expect(question.optionKeyForAnswer('Correct'), 'A');
      expect(question.optionKeyForAnswer('Wrong 1'), 'B');
      expect(question.optionKeyForAnswer('Wrong 2'), 'C');
      expect(question.optionKeyForAnswer('Wrong 3'), 'D');
    });

    test('true false display order stays stable', () {
      const question = QuizQuestion(
        id: 'q_tf',
        category: 'Ziman',
        prompt: 'Test question?',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        explanation: 'This is correct',
        type: QuestionType.trueFalse,
      );

      expect(question.displayAnswers, ['Rast', 'Şaş']);
    });

    test('getLocalizedExplanation returns localized explanations correctly', () {
      const question = QuizQuestion(
        id: 'q_explanation_test',
        category: 'Ziman',
        prompt: 'Test?',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        explanation: 'Default explanation',
        explanationKu: 'Kurdish explanation',
        explanationTr: 'Turkish explanation',
      );

      expect(question.getLocalizedExplanation(true), 'Kurdish explanation');
      expect(question.getLocalizedExplanation(false), 'Turkish explanation');
    });

    test('getLocalizedExplanation falls back to base explanation or local translation function', () {
      const question = QuizQuestion(
        id: 'q_explanation_fallback',
        category: 'Ziman',
        prompt: 'Test?',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        explanation: '"av" kelimesi "su" anlamına gelir.',
      );

      // Kurdish mode uses local translation mapping (explanationToKu) on the base explanation
      expect(question.getLocalizedExplanation(true), 'Peyva "av" tê wateya "su".');
      expect(question.getLocalizedExplanation(false), '"av" kelimesi "su" anlamına gelir.');
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
