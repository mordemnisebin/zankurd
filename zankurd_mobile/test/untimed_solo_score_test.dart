import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

const _question = QuizQuestion(
  id: 'untimed-score-1',
  category: 'Ziman',
  prompt: 'Pirsa bê dem?',
  answers: ['rast', 'şaş-a', 'şaş-b', 'şaş-c'],
  correctAnswer: 'rast',
  explanation: '',
);

/// Süresiz tek kişilik turda düşünerek verilen doğru cevap hız sınırını
/// aşınca 0 puan alıyordu (2026-10-25). Süre yoksa hız yarışı da yok:
/// doğru cevap taban puanı alır, hızlı ya da yavaş fark etmez.
void main() {
  testWidgets('süresiz solo turda doğru cevap taban puanı alır', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('rast'));
    await tester.pumpAndSettle();

    expect(find.text('100'), findsWidgets);
    expect(find.text('0'), findsNothing);
  });
}
