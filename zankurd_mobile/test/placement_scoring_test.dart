import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';

QuizQuestion _q(String id, int difficulty) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'p$id',
  answers: const ['a', 'b', 'c', 'd'],
  correctAnswer: 'a',
  explanation: '',
  difficulty: difficulty,
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
      PlacementItem(difficulty: 1, correct: true),
      PlacementItem(difficulty: 2, correct: true),
      PlacementItem(difficulty: 1, correct: true),
    ];
    final result = PlacementScoring.evaluate(answered, totalQuestions: 12);
    expect(result.totalCount, 12);
    expect(result.correctCount, 3);
    expect(result.level, PlacementLevel.destpek);
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
        QuizQuestion(
          id: 'bad',
          category: 'Ziman',
          prompt: 'p',
          answers: const ['tek'],
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
