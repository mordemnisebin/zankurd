import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

QuizQuestion _q(int n, String asset) => QuizQuestion(
  id: 'precache-$n',
  category: 'Çand',
  prompt: 'Pirsa wêneyê $n?',
  answers: ['rast-$n', 'şaş-a-$n', 'şaş-b-$n', 'şaş-c-$n'],
  correctAnswer: 'rast-$n',
  explanation: '',
  type: QuestionType.visual,
  imageUrl: 'asset://$asset',
);

/// Görsel yükleme kapısı yalnız ilk soruyu bekletiyor; sonraki görselli
/// sorularda sayaç görsel gelmeden başlıyordu (2026-10-25). Bir soru
/// gösterilirken SIRADAKİ sorunun görseli önceden yüklenir.
void main() {
  testWidgets('ilk soru gösterilirken ikinci sorunun görseli önbelleğe girer', (
    tester,
  ) async {
    const second = 'assets/question_images/arkeoloji.webp';
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [
            _q(1, 'assets/question_images/anlatici.webp'),
            _q(2, second),
          ],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Pirsa wêneyê 1?'), findsOneWidget);
    final config = createLocalImageConfiguration(
      tester.element(find.byType(QuizScreen)),
    );
    final key = await tester.runAsync(
      () => const AssetImage(second).obtainKey(config),
    );
    expect(
      imageCache.statusForKey(key!).tracked,
      isTrue,
      reason: 'ikinci sorunun görseli önceden yüklenmedi',
    );
    await tester.pumpAndSettle();
  });
}
