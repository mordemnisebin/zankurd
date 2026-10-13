import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';

import 'support/widget_test_helpers.dart';

const _runtimeQuestion = QuizQuestion(
  id: 'online-uuid-not-in-local-bank',
  category: 'Ziman',
  prompt: 'Kîjan bersiv rast e?',
  answers: ['Rast', 'Şaş'],
  correctAnswer: 'Rast',
  explanation: 'Rast bersiv Rast e.',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets(
    'turda kullanılan repo-dışı soru sonuçtan Review practice yoluna taşınır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      expect(
        repository.playableQuestions.any(
          (question) => question.id == _runtimeQuestion.id,
        ),
        isFalse,
        reason:
            'Test, yerel bankada bulunmayan sunucu/oda soru ID’sini taklit eder.',
      );

      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [_runtimeQuestion],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Şaş').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
      await tester.pumpAndSettle();

      final review = find.byKey(const ValueKey('learning-outcome-review'));
      expect(review, findsOneWidget);
      await tester.ensureVisible(review);
      await tester.pumpAndSettle();
      await tester.tap(review);
      await tester.pumpAndSettle();

      expect(find.byType(ReviewScreen), findsOneWidget);
      expect(
        find.byKey(const ValueKey('review-practice-cta')),
        findsOneWidget,
        reason:
            'Sonuç ekranı yalnız repository.playableQuestions’a bakarsa '
            'online UUID yanlışları tekrar edilemez.',
      );
    },
  );
}
