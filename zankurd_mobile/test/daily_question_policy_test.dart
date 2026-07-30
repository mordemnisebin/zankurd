import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  test('günlük quiz yalnız oynanabilir soruları döndürür', () async {
    const playable = QuizQuestion(
      id: 'approved-visible',
      category: 'Ziman',
      prompt: 'Pirsê derbasdar?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya derbasdar.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.approved),
    );
    const needsReview = QuizQuestion(
      id: 'needs-review',
      category: 'Ziman',
      prompt: 'Pirsê li benda kontrolê?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya li benda kontrolê.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.needsReview),
    );
    const rejected = QuizQuestion(
      id: 'rejected',
      category: 'Ziman',
      prompt: 'Pirsa hatiye redkirin?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya hatiye redkirin.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.rejected),
    );
    const hiddenCategory = QuizQuestion(
      id: 'approved-hidden-category',
      category: 'Sînema',
      prompt: 'Pirsa ji kategoriya veşartî?',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'Şîroveya kategoriya veşartî.',
      metadata: QuestionMetadata(reviewStatus: ReviewStatus.approved),
    );

    QuestionBankLoader.instance.setQuestionsForTest([
      playable,
      needsReview,
      rejected,
      hiddenCategory,
    ]);

    final questions = await MockZanKurdRepository().loadDailyQuestions(
      limit: 10,
    );

    expect(questions.map((question) => question.id).toSet(), {
      'approved-visible',
    });
  });
}
