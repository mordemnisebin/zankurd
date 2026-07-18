import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => ChildSafetyProvider()),
  ],
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
  testWidgets('light solo vitrin okunaklı marka gradyanı taşır', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('result-score-header')),
    );
    final decoration = header.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors, hasLength(2));
    expect(
      gradient.colors.first.computeLuminance(),
      lessThan(AppTheme.brandGreen.computeLuminance()),
    );
    expect(
      gradient.colors.last.computeLuminance(),
      lessThan(AppTheme.brandGreenDeep.computeLuminance()),
    );
  });

  testWidgets('primary CTA ve ikincil butonları taşır', (tester) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Primary: play again
    expect(find.text('Tekrar oyna'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-play-again-button')),
      findsOneWidget,
    );

    // Secondary: review
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('result-review-button')),
      200,
    );
    expect(find.text('İncele'), findsOneWidget);

    // Secondary: home
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('result-home-button')),
      200,
    );
    final homeBtn = tester.widget<TextButton>(
      find.byKey(const ValueKey('result-home-button')),
    );
    expect(homeBtn.onPressed, isNotNull);
    expect(find.text('Ana Sayfa'), findsOneWidget);

    // Subtle links
    expect(find.text('Sadece yanlışlar'), findsOneWidget);
    expect(find.text('Liderlik tablosu'), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('sonuç ${size.width.toInt()}x${size.height.toInt()} taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
