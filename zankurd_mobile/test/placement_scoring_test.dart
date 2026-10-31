import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

QuizQuestion _q(
  String id,
  int difficulty, {
  String category = 'Ziman',
  QuestionMetadata metadata = const QuestionMetadata(
    reviewStatus: ReviewStatus.approved,
    learningLessonId: 'lesson',
  ),
}) => QuizQuestion(
  id: id,
  category: category,
  prompt: 'p$id',
  answers: const ['a', 'b', 'c', 'd'],
  correctAnswer: 'a',
  explanation: '',
  difficulty: difficulty,
  metadata: metadata,
);

void main() {
  // 12 soruluk dengeli zorluk dağılımı: 4 kolay(1-2), 4 orta(3), 4 zor(4-5).
  const difficulties = [1, 2, 1, 2, 3, 3, 3, 3, 4, 5, 4, 5];

  List<PlacementItem> items(List<bool> correct) {
    return [
      for (var i = 0; i < difficulties.length; i++)
        PlacementItem(difficulty: difficulties[i], correct: correct[i]),
    ];
  }

  test('tümü doğru → Pêşketî (ileri)', () {
    final result = PlacementScoring.evaluate(items(List.filled(12, true)));
    expect(result.level, PlacementLevel.pesketi);
    expect(result.correctCount, 12);
    expect(result.totalCount, 12);
  });

  test('tümü yanlış → Destpêk (başlangıç)', () {
    final result = PlacementScoring.evaluate(items(List.filled(12, false)));
    expect(result.level, PlacementLevel.destpek);
    expect(result.correctCount, 0);
  });

  test('yalnız kolaylar doğru → Destpêk', () {
    // Kolaylar (index 0-3) doğru, geri kalan yanlış.
    final correct = [
      true, true, true, true, // kolay
      false, false, false, false, // orta
      false, false, false, false, // zor
    ];
    final result = PlacementScoring.evaluate(items(correct));
    expect(result.level, PlacementLevel.destpek);
  });

  test('kolay + orta doğru, zorlar yanlış → Navîn (orta)', () {
    final correct = [
      true, true, true, true, // kolay
      true, true, true, true, // orta
      false, false, false, false, // zor
    ];
    final result = PlacementScoring.evaluate(items(correct));
    expect(result.level, PlacementLevel.navin);
  });

  test('eksik cevaplar yanlış sayılır (total korunur)', () {
    // Sadece ilk 3 kolay cevaplanmış, geri kalan atlanmış (yanıtsız = yanlış).
    final answered = [
      const PlacementItem(difficulty: 1, correct: true),
      const PlacementItem(difficulty: 2, correct: true),
      const PlacementItem(difficulty: 1, correct: true),
    ];
    final result = PlacementScoring.evaluate(answered, totalQuestions: 12);
    expect(result.totalCount, 12);
    expect(result.correctCount, 3);
    expect(result.level, PlacementLevel.destpek);
  });

  test(
    'bildirilen pozitif toplam cevap sayısından küçükse tüm cevaplar sayılır',
    () {
      final answers = List.filled(
        5,
        const PlacementItem(difficulty: 2, correct: true),
      );
      final result = PlacementScoring.evaluate(answers, totalQuestions: 3);
      expect(result.totalCount, 5);
      expect(result.correctCount, 5);
      expect(result.weightedRatio, 1);
    },
  );

  test('açıkça sıfır veya negatif toplam verilirse puan hesaplanmaz', () {
    final answers = [const PlacementItem(difficulty: 3, correct: true)];
    for (final total in [0, -1]) {
      final result = PlacementScoring.evaluate(answers, totalQuestions: total);
      expect(result.totalCount, 0);
      expect(result.correctCount, 0);
      expect(result.weightedRatio, 0);
      expect(result.level, PlacementLevel.destpek);
    }
  });

  test('boş liste güvenli varsayılan Destpêk döner', () {
    final result = PlacementScoring.evaluate(const []);
    expect(result.level, PlacementLevel.destpek);
    expect(result.totalCount, 0);
  });

  test('seviye etiketleri iki dilli', () {
    expect(PlacementLevel.destpek.labelKu, 'Destpêk');
    expect(PlacementLevel.destpek.labelTr, 'Başlangıç');
    expect(PlacementLevel.navin.labelKu, 'Navîn');
    expect(PlacementLevel.navin.labelTr, 'Orta');
    expect(PlacementLevel.pesketi.labelKu, 'Pêşketî');
    expect(PlacementLevel.pesketi.labelTr, 'İleri');
  });

  group('selectQuestions', () {
    test('sıfır veya negatif soru isteği boş döner', () {
      expect(PlacementScoring.selectQuestions([_q('a', 1)], count: 0), isEmpty);
      expect(
        PlacementScoring.selectQuestions([_q('a', 1)], count: -1),
        isEmpty,
      );
    });

    test('genel bilgi, onaysız içerik ve ders dışı dil tarihi alınmaz', () {
      final language = _q('language', 3);
      final selected = PlacementScoring.selectQuestions([
        _q('politics', 3, category: 'Siyaset'),
        _q('history', 3, category: 'Dîrok'),
        _q('unreviewed', 3, metadata: const QuestionMetadata()),
        _q(
          'draft',
          3,
          metadata: const QuestionMetadata(
            reviewStatus: ReviewStatus.draft,
            learningLessonId: 'lesson',
          ),
        ),
        _q(
          'language-history',
          3,
          metadata: const QuestionMetadata(reviewStatus: ReviewStatus.approved),
        ),
        language,
      ]);
      expect(selected.map((q) => q.id), ['language']);
    });

    test('yazmalı hatırlamaya onaylı dil sorusu ders etiketsiz de seçilir', () {
      final question = _q(
        'recall',
        3,
        metadata: const QuestionMetadata(
          reviewStatus: ReviewStatus.approved,
          productiveRecallEligible: true,
        ),
      );
      expect(PlacementScoring.selectQuestions([question]), [question]);
    });

    test('seçenek ekranında çözülemeyen soru türleri sınava alınmaz', () {
      final base = _q('choice', 2);
      final selected = PlacementScoring.selectQuestions([
        _q('ordering', 2).copyWith(
          type: QuestionType.wordOrdering,
          answers: const ['a', 'b'],
          correctAnswer: 'a b',
        ),
        _q(
          'fill',
          2,
        ).copyWith(type: QuestionType.fillInBlank, answers: const ['a']),
        _q('visual', 2).copyWith(type: QuestionType.visual),
        _q('missing-answer', 2).copyWith(correctAnswer: 'absent'),
        base,
      ]);
      expect(selected.map((q) => q.id), ['choice']);
    });

    test('dil ölçme adayı yoksa genel bilgiyle doldurulmaz', () {
      expect(
        PlacementScoring.selectQuestions([_q('culture', 1, category: 'Çand')]),
        isEmpty,
      );
    });

    test('gerçek bankada ardışık iki sınava yetecek orta ve zor hedef var', () {
      final pool = QuestionBankLoader.instance.allQuestions;
      final candidates = PlacementScoring.selectQuestions(
        pool,
        count: pool.length,
      );
      final easy = candidates.where((q) => q.difficulty <= 2).length;
      final medium = candidates.where((q) => q.difficulty == 3).length;
      final hard = candidates.where((q) => q.difficulty >= 4).length;
      expect(
        medium,
        greaterThanOrEqualTo(8),
        reason: 'Havuz: $easy/$medium/$hard',
      );
      expect(hard, greaterThanOrEqualTo(8));
      expect(candidates.any((q) => q.id == 'edit_ziman_0019'), isFalse);
    });

    test(
      'önceki sınav bilinmese de yeni çekilişler bankanın başına sabitlenmez',
      () {
        final pool = QuestionBankLoader.instance.allQuestions;
        Set<String> draw(int seed) => PlacementScoring.selectQuestions(
          pool,
          random: Random(seed),
        ).map((q) => q.id).toSet();
        expect(draw(0), draw(0));
        expect(draw(1), isNot(draw(0)));
      },
    );

    test('yeni sınav aynı zorluklarda farklı kimlik ve kökler sunar', () {
      final pool = QuestionBankLoader.instance.allQuestions;
      var previous = <QuizQuestion>[];
      for (var i = 0; i < 20; i++) {
        final exam = PlacementScoring.selectQuestions(
          pool,
          previous: previous,
          random: Random(i),
        );
        expect(exam.where((q) => q.difficulty <= 2), hasLength(4));
        expect(exam.where((q) => q.difficulty == 3), hasLength(4));
        expect(exam.where((q) => q.difficulty >= 4), hasLength(4));
        final ids = previous.map((q) => q.id).toSet();
        final prompts = previous
            .map((q) => QuestionSetPolicy.normalize(q.prompt))
            .toSet();
        expect(exam.where((q) => ids.contains(q.id)), isEmpty);
        expect(
          exam.where(
            (q) => prompts.contains(QuestionSetPolicy.normalize(q.prompt)),
          ),
          isEmpty,
        );
        previous = exam;
      }
    });

    test('farklı kimlikli aynı kök yalnız bir defa ve gerekirse seçilir', () {
      final prior = _q('old', 3);
      final alias = _q('alias', 3).copyWith(prompt: prior.prompt.toUpperCase());
      final other = _q('other', 3);
      final pool = [prior, alias, other];
      expect(
        PlacementScoring.selectQuestions(pool, count: 1, previous: [prior]),
        [other],
      );
      final all = PlacementScoring.selectQuestions(pool);
      expect(all, hasLength(2));
      expect(all, contains(other));
    });

    test('gerçek bankada onaylı dil hedefleriyle 4/4/4 soru sağlanır', () {
      final selected = PlacementScoring.selectQuestions(
        QuestionBankLoader.instance.allQuestions,
      );
      expect(selected, hasLength(12));
      expect(selected.map((q) => q.id).toSet(), hasLength(12));
      expect(selected.every((q) => q.category == 'Ziman'), isTrue);
      expect(
        selected.every(
          (q) => q.metadata?.reviewStatus == ReviewStatus.approved,
        ),
        isTrue,
      );
      expect(selected.where((q) => q.difficulty <= 2), hasLength(4));
      expect(selected.where((q) => q.difficulty == 3), hasLength(4));
      expect(selected.where((q) => q.difficulty >= 4), hasLength(4));
    });

    test('dengeli havuzdan 12 soru seçer, zorluk kovalarını karıştırır', () {
      final pool = [
        for (var i = 0; i < 10; i++) _q('e$i', 1),
        for (var i = 0; i < 10; i++) _q('m$i', 3),
        for (var i = 0; i < 10; i++) _q('h$i', 5),
      ];
      final selected = PlacementScoring.selectQuestions(pool, count: 12);
      expect(selected.length, 12);
      expect(selected.any((q) => q.difficulty <= 2), isTrue);
      expect(selected.any((q) => q.difficulty == 3), isTrue);
      expect(selected.any((q) => q.difficulty >= 4), isTrue);
      // Tekrarsız
      expect(selected.map((q) => q.id).toSet().length, 12);
    });

    test('havuz kücükse tümü döner', () {
      final pool = [_q('a', 1), _q('b', 3), _q('c', 5)];
      final selected = PlacementScoring.selectQuestions(pool, count: 12);
      expect(selected.length, 3);
    });

    test('bir kova zayıfsa kalanlarla tamamlanır', () {
      final pool = [for (var i = 0; i < 20; i++) _q('e$i', 1), _q('m0', 3)];
      final selected = PlacementScoring.selectQuestions(pool, count: 12);
      expect(selected.length, 12);
    });

    test('geçersiz (şıksız) sorular elenir', () {
      final pool = [
        const QuizQuestion(
          id: 'bad',
          category: 'Ziman',
          prompt: 'p',
          answers: ['tek'],
          correctAnswer: 'tek',
          explanation: '',
          difficulty: 1,
        ),
        for (var i = 0; i < 15; i++) _q('ok$i', 2),
      ];
      final selected = PlacementScoring.selectQuestions(pool, count: 12);
      expect(selected.any((q) => q.id == 'bad'), isFalse);
      expect(selected.length, 12);
    });
  });

  group('recommendedStartIndex', () {
    test('Destpêk / null → ilk düğüm', () {
      expect(
        PlacementScoring.recommendedStartIndex(PlacementLevel.destpek, 9),
        0,
      );
      expect(PlacementScoring.recommendedStartIndex(null, 9), 0);
    });

    test('Navîn → yolun ~1/3ü', () {
      expect(
        PlacementScoring.recommendedStartIndex(PlacementLevel.navin, 9),
        (9 * 0.33).floor(),
      );
    });

    test('Pêşketî → yolun ~2/3ü, ama son düğümü aşmaz', () {
      final idx = PlacementScoring.recommendedStartIndex(
        PlacementLevel.pesketi,
        9,
      );
      expect(idx, (9 * 0.66).floor());
      expect(idx, lessThanOrEqualTo(8));
    });

    test('boş yol güvenli 0 döner', () {
      expect(
        PlacementScoring.recommendedStartIndex(PlacementLevel.pesketi, 0),
        0,
      );
    });
  });
}
