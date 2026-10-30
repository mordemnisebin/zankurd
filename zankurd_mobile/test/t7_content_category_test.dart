import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/curated_question_bank.dart';

void main() {
  test('T7: cümlede berxwedan anlamı Bilim değil Ziman ölçer', () {
    final question = curatedQuestionBank.singleWhere(
      (q) => q.id == 'curated_movement_0006',
    );
    expect(question.category, 'Ziman');
    expect(
      question.prompt,
      'Di vê hevokê de peyva "berxwedan" çi dide zanîn? '
      '"Berxwedana wan dom kir."',
    );
    expect(question.correctAnswer, 'Ragirtina li hember zordariyê');
    expect(question.correctAnswerTr, 'Baskıya karşı direnmek');
    expect(question.answers, hasLength(4));
    expect(question.answers.toSet(), hasLength(4));
  });
}
