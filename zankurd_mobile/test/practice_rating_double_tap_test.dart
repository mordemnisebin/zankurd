import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

QuizQuestion _q(int n) => QuizQuestion(
  id: 'rating-tap-$n',
  category: 'Ziman',
  prompt: 'Pirsa hejmar $n?',
  answers: ['rast-$n', 'şaş-a-$n', 'şaş-b-$n', 'şaş-c-$n'],
  correctAnswer: 'rast-$n',
  explanation: '',
);

/// Alıştırma turunda zorluk düğmesine art arda iki dokunuş, kayıt sürerken
/// `_next()`i iki kez çalıştırıp bir soruyu atlatıyordu (2026-10-25).
void main() {
  testWidgets('zorluk puanına çift dokunuş yalnız bir soru ilerletir', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [_q(1), _q(2), _q(3)],
          enableTimer: false,
          practice: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('rast-1'));
    await tester.pumpAndSettle();

    final medium = find.text('Orta');
    expect(medium, findsOneWidget);
    await tester.tap(medium);
    await tester.tap(medium, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Pirsa hejmar 2?'), findsOneWidget);
    expect(find.text('Pirsa hejmar 3?'), findsNothing);
  });

  // 2026-10-25: alıştırmada doğru cevaptan sonra zorluk düğmesine basmadan
  // çıkılırsa cevap günlük geçmişe hiç yazılmıyordu. Artık hemen sayılır;
  // düğme (SM-2) onu ikinci kez saymaz.
  testWidgets('alıştırmada doğru cevap düğmesiz de bir kez sayılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [_q(1), _q(2)],
          enableTimer: false,
          practice: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('rast-1'));
    await tester.pumpAndSettle();
    expect((await MistakeStore.load()).totalCorrect, 1);

    await tester.tap(find.text('Orta'));
    await tester.pumpAndSettle();
    expect(find.text('Pirsa hejmar 2?'), findsOneWidget);
    expect((await MistakeStore.load()).totalCorrect, 1);
  });
}
