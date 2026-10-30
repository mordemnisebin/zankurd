import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// T3: eski bekçi yalnız kimliğe sabit kaydırmayı sınadığı için aynı
/// sorunun farklı maçlarda ezberlenebildiğini görmüyordu. Artık bütün
/// oynanabilir çoktan seçmeli bankayı çok maçta ölçer; %25±3 korunur.
void main() {
  final questions = [
    for (final q in MockZanKurdRepository().playableQuestions)
      if (q.type == QuestionType.multipleChoice &&
          q.answers.length == 4 &&
          q.answers.contains(q.correctAnswer))
        q,
  ];

  test('bekçi kör değil', () {
    expect(questions.length, greaterThan(1000));
  });

  test('Türkçe ve Kurmancî doğru cevabı aynı görünen konumda gösterir', () {
    final offenders = <String>[];
    for (final source in questions) {
      final q = source.forRound('contract-match');
      final ku = q.displayAnswers.indexOf(q.correctAnswer);
      final tr = q.localized(isKu: false);
      final trIndex = tr.displayAnswers.indexOf(tr.correctAnswer);
      if (ku != trIndex) offenders.add('${q.id}: ku=$ku tr=$trIndex');
    }
    expect(offenders, isEmpty, reason: offenders.take(20).join('\n'));
  });

  test('görünen şıkkın sunucu anahtarı depolanan indekstir', () {
    const keys = ['A', 'B', 'C', 'D'];
    for (final source in questions) {
      final q = source.forRound('contract-match');
      for (final shown in q.displayAnswers) {
        final stored = q.answers.indexOf(shown);
        expect(q.optionKeyForAnswer(shown), keys[stored], reason: q.id);
        expect(q.answerForOptionKey(keys[stored]), shown, reason: q.id);
      }
    }
  });

  test('görünen sıra kararlı (yeniden açma / iki istemci)', () {
    for (final source in questions) {
      final q = source.forRound('contract-match');
      final again = QuizQuestion.fromJson(
        q.toJson(),
      ).forRound('contract-match');
      expect(again.displayAnswers, q.displayAnswers, reason: q.id);
    }
  });

  test('maçlar arası ezber sessizdi; görünen konum çok maçta %25±3', () {
    final shown = List<int>.filled(4, 0);
    for (var match = 0; match < 30; match++) {
      for (final source in questions) {
        final q = source.forRound('contract-$match');
        shown[q.displayAnswers.indexOf(q.correctAnswer)]++;
      }
    }
    final total = shown.reduce((a, b) => a + b);
    for (final count in shown) {
      expect(
        (100 * count / total - 25).abs(),
        lessThan(3),
        reason: 'görünen dağılım $shown',
      );
    }
  });
}
