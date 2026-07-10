import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => ChangeNotifierProvider(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

QuizResultScreen buildScreen(MockZanKurdRepository repository) {
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 1840,
    correctCount: 8,
    wrongCount: 2,
    totalQuestions: 10,
    bestStreak: 5,
    coinsAwarded: 120,
    answerRecords: const [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Ev gotin çi wateyê dide?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: 'Rast bersiv A ye.',
      ),
    ],
  );
}

void main() {
  testWidgets('solo vitrin brandOrange kutlama gradyanı taşır', (tester) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('result-score-header')),
    );
    final decoration = header.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors, [AppTheme.brandOrange, AppTheme.brandOrangeWarm]);
  });

  testWidgets('ana CTA brandOrange dolgu taşır', (tester) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const ValueKey('result-home-button')),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('result-home-button')),
    );
    expect(button.style?.backgroundColor?.resolve({}), AppTheme.brandOrange);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
