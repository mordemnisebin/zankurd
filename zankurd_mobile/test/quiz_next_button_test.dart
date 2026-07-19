import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// P0 regression (2026-07-19 canlı denetim): reveal sonrası "Piştre"
/// her koşulda sonraki soruya ilerlemeli; çift cevap ara durumu
/// reveal ile karıştırılmamalı.
void main() {
  const q1 = QuizQuestion(
    id: 'p0-q1',
    category: 'Ziman',
    prompt: 'P0 test sorusu bir: pîr ne demektir?',
    answers: ['Yaşlı', 'Genç', 'Hızlı', 'Yavaş'],
    correctAnswer: 'Yaşlı',
    explanation: 'Pîr yaşlı demektir.',
  );
  const q2 = QuizQuestion(
    id: 'p0-q2',
    category: 'Ziman',
    prompt: 'P0 test sorusu iki: kanî ne demektir?',
    answers: ['Pınar', 'Dağ', 'Deniz', 'Ova'],
    correctAnswer: 'Pınar',
    explanation: 'Kanî pınar demektir.',
  );

  Future<void> pumpQuiz(
    WidgetTester tester, {
    List<QuizQuestion> questions = const [q1, q2],
  }) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: questions,
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  VoidCallback? nextButtonCallback(WidgetTester tester) {
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    return button.onPressed;
  }

  testWidgets('reveal sonrası Piştre sonraki soruya ilerler', (tester) async {
    await pumpQuiz(tester);
    expect(find.text(q1.prompt), findsOneWidget);

    // Cevapla → reveal
    await tester.tap(find.text(q1.correctAnswer).first);
    await tester.pumpAndSettle();

    // Piştre aktif olmalı ve sonraki soruya ilerlemeli
    expect(nextButtonCallback(tester), isNotNull);
    await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
    await tester.pumpAndSettle();

    expect(find.text(q1.prompt), findsNothing);
    expect(find.text(q2.prompt), findsOneWidget);
  });

  testWidgets(
    'çift cevap ilk yanlış denemede kilit görünümü netleşir, ikinci denemede akış ilerler',
    (tester) async {
      await pumpQuiz(tester);

      // Çift Cevap jokerini etkinleştir (testShell varsayılan dili TR)
      // Dalga 5: joker butonu etiketi "ad · fiyat" tek satırında birleşti.
      await tester.tap(find.textContaining('Çift Cevap'));
      await tester.pumpAndSettle();

      // İlk deneme: yanlış şık
      final wrong = q1.answers.firstWhere((a) => a != q1.correctAnswer);
      await tester.tap(find.text(wrong).first);
      await tester.pumpAndSettle();

      // İpucu görünür, Piştre kilitli (answered değil) ama ekran takılı değil:
      // kalan şıklar hâlâ seçilebilir.
      expect(find.text('Çift cevap: bir şık daha seç'), findsOneWidget);
      expect(nextButtonCallback(tester), isNull);

      // İkinci deneme: doğru şık → reveal → Piştre aktif
      await tester.tap(find.text(q1.correctAnswer).first);
      await tester.pumpAndSettle();

      expect(nextButtonCallback(tester), isNotNull);
      await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
      await tester.pumpAndSettle();

      expect(find.text(q2.prompt), findsOneWidget);
    },
  );

  testWidgets('10 ardışık soruda her reveal sonrası Piştre ilerler', (
    tester,
  ) async {
    final questions = [
      for (var i = 0; i < 10; i++)
        QuizQuestion(
          id: 'p0-run-$i',
          category: 'Ziman',
          prompt: 'P0 maraton sorusu $i?',
          answers: ['Doğru $i', 'Yanlış $i a', 'Yanlış $i b', 'Yanlış $i c'],
          correctAnswer: 'Doğru $i',
          explanation: 'Açıklama $i',
        ),
    ];
    await pumpQuiz(tester, questions: questions);

    for (var i = 0; i < 9; i++) {
      // Her soruda doğru/yanlış dönüşümlü cevapla (iki reveal yolu da).
      final answer = i.isEven
          ? 'Doğru $i'
          : questions[i].answers.firstWhere(
              (a) => a != questions[i].correctAnswer,
            );
      await tester.tap(find.text(answer).first);
      await tester.pumpAndSettle();
      expect(
        nextButtonCallback(tester),
        isNotNull,
        reason: 'Soru $i reveal sonrası Piştre kilitli kaldı',
      );
      await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
      await tester.pumpAndSettle();
      expect(find.text('P0 maraton sorusu ${i + 1}?'), findsOneWidget);
    }
  });
}
