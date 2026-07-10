import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/utils/category_distractor_pool.dart';

QuizQuestion _q({
  required String id,
  required String category,
  required List<String> answers,
  required String correct,
}) => QuizQuestion(
  id: id,
  category: category,
  prompt: 'p-$id',
  answers: answers,
  correctAnswer: correct,
  explanation: 'e',
);

void main() {
  test('havuz aynı kategorinin doğru cevaplarını toplar', () {
    final pool = CategoryDistractorPool([
      _q(id: '1', category: 'Ziman', answers: ['su', 'x'], correct: 'su'),
      _q(id: '2', category: 'Ziman', answers: ['ev', 'y'], correct: 'ev'),
      _q(id: '3', category: 'Dîrok', answers: ['Lozan', 'z'], correct: 'Lozan'),
    ]);
    final pools = pool.buildPools();
    expect(pools['Ziman'], containsAll(['su', 'ev']));
    expect(pools['Dîrok'], ['Lozan']);
  });

  test('yeniden üretim doğru cevabı korur ve kategori dışı çöpü eler', () {
    final questions = [
      _q(
        id: 'a',
        category: 'Ziman',
        answers: ['arkadaş', 'Yumurta', 'Kırmızı', 'sayılar'],
        correct: 'arkadaş',
      ),
      _q(
        id: 'b',
        category: 'Ziman',
        answers: ['su', 'x', 'y', 'z'],
        correct: 'su',
      ),
      _q(
        id: 'c',
        category: 'Ziman',
        answers: ['ev', 'x', 'y', 'z'],
        correct: 'ev',
      ),
      _q(
        id: 'd',
        category: 'Ziman',
        answers: ['kitap', 'x', 'y', 'z'],
        correct: 'kitap',
      ),
    ];
    final engine = CategoryDistractorPool(questions, seed: 7);
    final pools = engine.buildPools();
    final rebuilt = engine.rebuildAnswers(questions.first, pools);

    expect(rebuilt, contains('arkadaş'));
    expect(rebuilt.length, 4);
    // Case-unique
    final norms = rebuilt.map((e) => e.trim().toLowerCase()).toSet();
    expect(norms.length, rebuilt.length);
    // Mümkün olduğunca kategori havuzundan
    final score = engine.categoryCohesionScore(
      QuizQuestion(
        id: 'a',
        category: 'Ziman',
        prompt: 'p',
        answers: rebuilt,
        correctAnswer: 'arkadaş',
        explanation: 'e',
      ),
      pools,
    );
    expect(score, greaterThanOrEqualTo(0.66));
  });

  test('true/false sorulara dokunulmaz', () {
    final q = QuizQuestion(
      id: 'tf',
      category: 'Ziman',
      prompt: 'p',
      answers: const ['Rast', 'Şaş'],
      correctAnswer: 'Şaş',
      explanation: 'e',
      type: QuestionType.trueFalse,
    );
    final engine = CategoryDistractorPool([q]);
    final rebuilt = engine.rebuildAnswers(q, engine.buildPools());
    expect(rebuilt, ['Rast', 'Şaş']);
  });

  test('rebuildAll doğru cevapları korur', () {
    final qs = [
      _q(
        id: '1',
        category: 'Ziman',
        answers: ['a', 'b', 'c', 'd'],
        correct: 'a',
      ),
      _q(
        id: '2',
        category: 'Ziman',
        answers: ['e', 'f', 'g', 'h'],
        correct: 'e',
      ),
      _q(
        id: '3',
        category: 'Ziman',
        answers: ['i', 'j', 'k', 'l'],
        correct: 'i',
      ),
      _q(
        id: '4',
        category: 'Ziman',
        answers: ['m', 'n', 'o', 'p'],
        correct: 'm',
      ),
    ];
    final out = CategoryDistractorPool(qs).rebuildAll();
    for (var i = 0; i < qs.length; i++) {
      expect(out[i].correctAnswer, qs[i].correctAnswer);
      expect(out[i].answers, contains(qs[i].correctAnswer));
    }
  });
}
