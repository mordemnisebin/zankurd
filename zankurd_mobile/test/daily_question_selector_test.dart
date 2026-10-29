import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/services/daily_question_selector.dart';

QuizQuestion _question(String id, String category) {
  return QuizQuestion(
    id: id,
    category: category,
    prompt: 'Pirs $id?',
    answers: const ['A', 'B'],
    correctAnswer: 'A',
    explanation: 'Şîrove $id.',
  );
}

QuizQuestion _approvedQuestion(String id, String category) {
  return QuizQuestion(
    id: id,
    category: category,
    prompt: 'Pirs $id?',
    answers: const ['A', 'B'],
    correctAnswer: 'A',
    explanation: 'Şîrove $id.',
    metadata: const QuestionMetadata(reviewStatus: ReviewStatus.approved),
  );
}

void main() {
  test('Kurmancî hedefi Ziman sorularını günlük turun başına alır', () {
    final selected = selectDailyQuestionsForGoal(
      candidates: [
        _question('culture', 'Çand'),
        _question('ziman-1', 'Ziman'),
        _question('tech', 'Teknolojî'),
        _question('ziman-2', 'Ziman'),
      ],
      goal: LearningGoal.learnKurmanci,
      limit: 3,
    );

    expect(selected.map((question) => question.id), [
      'ziman-1',
      'ziman-2',
      'culture',
    ]);
  });

  test('kültür hedefi dört kültür kategorisini diğerlerinden önce tutar', () {
    final selected = selectDailyQuestionsForGoal(
      candidates: [
        _question('ziman', 'Ziman'),
        _question('history', 'Dîrok'),
        _question('politics', 'Siyaset'),
        _question('culture', 'Çand'),
        _question('literature', 'Edebiyat'),
        _question('geography', 'Cografya'),
      ],
      goal: LearningGoal.discoverCulture,
      limit: 5,
    );

    expect(selected.map((question) => question.category), [
      'Dîrok',
      'Çand',
      'Edebiyat',
      'Cografya',
      'Ziman',
    ]);
  });

  test('hedef havuzu yetersizse günlük turu kalan havuzla doldurur', () {
    final selected = selectDailyQuestionsForGoal(
      candidates: [
        _question('ziman', 'Ziman'),
        _question('culture', 'Çand'),
        _question('history', 'Dîrok'),
        _question('tech', 'Teknolojî'),
      ],
      goal: LearningGoal.learnKurmanci,
      limit: 6,
    );

    expect(selected, hasLength(4));
    expect(selected.first.category, 'Ziman');
    expect(selected.skip(1).map((question) => question.id), [
      'culture',
      'history',
      'tech',
    ]);
  });

  test('hedef seçilmemişse mevcut günlük sıra korunur', () {
    final candidates = [
      _question('first', 'Teknolojî'),
      _question('second', 'Ziman'),
      _question('third', 'Çand'),
    ];

    final selected = selectDailyQuestionsForGoal(
      candidates: candidates,
      goal: null,
      limit: 2,
    );

    expect(selected.map((question) => question.id), ['first', 'second']);
  });

  test(
    'yeterli onaylı içerik varsa metadata eksik soru öğrenme turuna girmez',
    () {
      final selected = selectDailyQuestionsForGoal(
        candidates: [
          _question('unreviewed', 'Ziman'),
          _approvedQuestion('approved-ziman', 'Ziman'),
          _approvedQuestion('approved-culture', 'Çand'),
        ],
        goal: LearningGoal.learnKurmanci,
        limit: 2,
      );

      expect(selected.map((question) => question.id), [
        'approved-ziman',
        'approved-culture',
      ]);
    },
  );

  // Codex denetimi 2026-10-29 (içerik #3): ilk pratikte zorluk sınırı yoktu;
  // sıfırdan başlayan ilk soruda ileri bilgiyle karşılaşabiliyordu.
  QuizQuestion hard(String id, int difficulty) => QuizQuestion(
    id: id,
    category: 'Ziman',
    prompt: 'Pirs $id?',
    answers: const ['A', 'B'],
    correctAnswer: 'A',
    explanation: 'Şîrove $id.',
    difficulty: difficulty,
  );

  test(
    'ilk oturum zorluk sınırı: kolaylar önce, zorlar kolaydan zora doldurur',
    () {
      final selected = selectDailyQuestionsForGoal(
        candidates: [
          hard('d5', 5),
          hard('e1', 1),
          hard('d3', 3),
          hard('e2', 2),
        ],
        goal: null,
        limit: 3,
        maxDifficulty: 2,
      );
      expect(selected.map((q) => q.id), ['e1', 'e2', 'd3']);
    },
  );

  test('ilk oturum yeterli kolay soruda hiç zor soru almaz', () {
    final selected = selectDailyQuestionsForGoal(
      candidates: [hard('d5', 5), hard('e1', 1), hard('e2', 2), hard('e1b', 1)],
      goal: null,
      limit: 3,
      maxDifficulty: 2,
    );
    expect(selected.every((q) => q.difficulty <= 2), isTrue);
  });
}
