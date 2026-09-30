import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

class _InjectedQuestionsRepository extends MockZanKurdRepository {
  _InjectedQuestionsRepository(this.seededQuestions);

  final List<QuizQuestion> seededQuestions;

  @override
  List<QuizQuestion> get questions => seededQuestions;
}

QuizQuestion _question({
  required String id,
  required String category,
  String? learningLessonId,
  bool recall = false,
}) {
  return QuizQuestion(
    id: id,
    category: category,
    prompt: '$id?',
    answers: const ['A', 'B', 'C', 'D'],
    correctAnswer: 'A',
    explanation: 'A',
    type: QuestionType.multipleChoice,
    metadata: QuestionMetadata(
      learningLessonId: learningLessonId,
      reviewStatus: recall ? ReviewStatus.approved : null,
      productiveRecallEligible: recall,
    ),
  );
}

void main() {
  group('lesson-specific learning quiz', () {
    late _InjectedQuestionsRepository repository;

    setUp(() {
      repository = _InjectedQuestionsRepository([
        _question(id: 'food', category: 'Ziman', learningLessonId: 'food_1'),
        _question(
          id: 'animals',
          category: 'Ziman',
          learningLessonId: 'animals_1',
        ),
        _question(id: 'legacy', category: 'Ziman'),
        _question(
          id: 'wrong-category',
          category: 'Çand',
          learningLessonId: 'food_1',
        ),
      ]);
    });

    test('explicit lesson tags win without unrelated fillers', () async {
      final questions = await repository.loadLearningQuizQuestions(
        category: 'Ziman',
        learningLessonId: 'food_1',
        limit: 5,
      );

      // Etiketli soru önce gelir; eksik yer yalnız aynı dersin sözlük
      // sorularıyla dolar (2026-09-30: önceden tek soruluk quiz açılıyordu).
      expect(questions.first.id, 'food');
      expect(questions, hasLength(5));
      expect(
        questions.every((q) => q.metadata?.learningLessonId == 'food_1'),
        isTrue,
      );
      expect(
        questions.map((q) => q.id),
        isNot(anyOf(contains('legacy'), contains('wrong-category'))),
      );
    });

    test(
      'etiketli ders havuzuna etiketsiz hatırlama sorusu karışmaz',
      () async {
        repository = _InjectedQuestionsRepository([
          _question(id: 'food', category: 'Ziman', learningLessonId: 'food_1'),
          _question(id: 'recall', category: 'Ziman', recall: true),
        ]);

        final questions = await repository.loadLearningQuizQuestions(
          category: 'Ziman',
          learningLessonId: 'food_1',
          limit: 5,
        );

        expect(questions.first.id, 'food');
        expect(questions.map((q) => q.id), isNot(contains('recall')));
      },
    );

    test(
      'missing explicit mapping uses only lesson-authored assessment',
      () async {
        final questions = await repository.loadLearningQuizQuestions(
          category: 'Ziman',
          learningLessonId: 'time_1',
          limit: 5,
        );

        expect(questions, hasLength(5));
        expect(
          questions.every((q) => q.metadata?.learningLessonId == 'time_1'),
          isTrue,
        );
        expect(questions.map((q) => q.id), isNot(contains('legacy')));
      },
    );
  });

  test('production bank keeps the reviewed lesson alignment seed', () {
    final tagged = QuestionBankLoader.instance.allQuestions
        .where((q) => q.metadata?.learningLessonId != null)
        .toList(growable: false);

    expect(tagged.map((q) => q.id).toSet(), {
      'offline_curated_30013',
      'edit_ziman_0038',
      'offline_0062',
      'ziman_x_0004',
      'offline_0055',
      'ziman_x_0050',
      'offline_5268',
      'edit_ziman_0011',
      'ziman_x_0014',
      'offline_5016',
      'offline_5094',
      'offline_5903',
      // 2026-09-30: Muse Spark ve Gemini 3.1 Pro'nun ayrı ayrı aynı derse
      // koyduğu 20 soru (uyuşmayanlar ve karantinadaki DeepSeek bankası
      // dışarıda).
      'edit_ziman_0020',
      'edit_ziman_0030',
      'fill_ziman_0002',
      'fill_ziman_0005',
      'offline_0005',
      'offline_0065',
      'offline_0090',
      'offline_0095',
      'offline_2599',
      'offline_2780',
      'offline_curated_30014',
      'offline_curated_30016',
      'offline_curated_30017',
      'offline_curated_30018',
      'wo-ku-008',
      'ziman_x_0016',
      'ziman_x_0025',
      'ziman_x_0031',
      'ziman_x_0052',
      'ziman_x_0054',
      // İkinci tur: Folklor, Bayramlar, Coğrafya, Yönler (Çand/Cografya).
      'comm_cog_0001',
      'edit_cand_0003',
      'edit_cand_0034',
      'edit_cografya_0004',
      'edit_cografya_0024',
      'offline_2052',
      'offline_2141',
      'offline_2354',
      'offline_2436',
      'offline_6260',
      'offline_6406',
      'restore_2026_08_07_0007',
      'restore_2026_08_07_0014',
      'restore_2026_08_07_0015',
    });
  });

  test('seeded production lessons put their exact tagged pool first', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = MockZanKurdRepository();
    const expectedCounts = {
      'everyday_1': 3,
      'everyday_3': 5,
      'grammar_1': 2,
      'grammar_2': 5,
      'food_1': 4,
      'animals_1': 4,
      'animals_2': 2,
      'emotions_1': 1,
      'time_2': 5,
    };

    for (final entry in expectedCounts.entries) {
      final questions = await repository.loadLearningQuizQuestions(
        category: 'Ziman',
        learningLessonId: entry.key,
        limit: 5,
      );

      // Etiketli sorular önce ve eksiksiz gelir; quiz sözlük sorularıyla
      // beşe tamamlanır.
      expect(questions, hasLength(5), reason: entry.key);
      // Sözlükten üretilenler `lesson_` önekli; etiketli banka soruları
      // hepsi ve önde.
      final tagged = questions.takeWhile((q) => !q.id.startsWith('lesson_'));
      expect(tagged, hasLength(entry.value), reason: entry.key);
      expect(
        questions.every((q) => q.metadata?.learningLessonId == entry.key),
        isTrue,
        reason: '${entry.key} broad filler karıştırmamalı',
      );
    }
  });

  test(
    'all 17 packaged lessons have explicit aligned mini-quiz coverage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final repository = MockZanKurdRepository();
      const categories = <String, String>{
        'everyday': 'Ziman',
        'grammar': 'Ziman',
        'culture': 'Çand',
        'food': 'Ziman',
        'animals': 'Ziman',
        'geography': 'Cografya',
        'emotions': 'Ziman',
        'time': 'Ziman',
      };
      var lessonCount = 0;

      for (final entry in categories.entries) {
        final lessons = await repository.loadLessonsByCategory(entry.key);
        lessonCount += lessons.length;
        for (final lesson in lessons) {
          final questions = await repository.loadLearningQuizQuestions(
            category: entry.value,
            learningLessonId: lesson.id,
            limit: 5,
          );

          expect(
            questions,
            isNotEmpty,
            reason: '${lesson.id} quizsiz kalmamalı',
          );
          expect(
            questions.every(
              (question) => question.metadata?.learningLessonId == lesson.id,
            ),
            isTrue,
            reason: '${lesson.id} geniş kategori filler almamalı',
          );
        }
      }

      expect(lessonCount, 17);
    },
  );
}
