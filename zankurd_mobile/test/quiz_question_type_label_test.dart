import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

void main() {
  test('typeLabelLocalized Kurmancî etiketleri doğru kelimeleri kullanır', () {
    const visual = QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'test',
      answers: ['a', 'b'],
      correctAnswer: 'a',
      explanation: '',
      difficulty: 1,
      type: QuestionType.visual,
    );
    // 2026-07-21 canlı denetimde bulundu: "Entık" geçersiz bir kelimeydi
    // (bozuk/anlamsız), doğrusu "Wêneyî" (görsel/resimli).
    expect(visual.typeLabelLocalized(true), 'Wêneyî');
    expect(visual.typeLabelLocalized(false), 'Görselli');
  });
}
