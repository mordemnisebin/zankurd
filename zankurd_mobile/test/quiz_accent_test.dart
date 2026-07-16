import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(create: (_) => SoundProvider()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  testWidgets('Sonraki CTA brandOrange dolgu taşır', (tester) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [repository.questions.first],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('quiz-next-button')),
    );
    expect(button.style?.backgroundColor?.resolve({}), AppTheme.brandOrange);
  });

  testWidgets('aktif soru segmenti brandOrange bekler', (tester) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: repository.questions.take(3).toList(),
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final segments = tester
        .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
        .where((c) {
          final deco = c.decoration;
          return deco is BoxDecoration && deco.color == AppTheme.brandOrange;
        });
    expect(segments, isNotEmpty);
  });

  testWidgets('şık kartı katı 3D gölge taşımaz', (tester) async {
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstAnswer = question.displayAnswers.first;
    final option = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(firstAnswer).first,
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    final deco = option.decoration as BoxDecoration;
    expect(deco.boxShadow, isNotNull);
    for (final shadow in deco.boxShadow!) {
      expect(shadow.blurRadius, greaterThan(0));
    }
  });

  testWidgets('cevap sonrası açıklama Zana sesiyle sunulur', (tester) async {
    final repository = MockZanKurdRepository();
    final question = repository.questions.first;
    await tester.pumpWidget(
      wrap(
        QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
          // Tur içi açıklama artık yalnız Öğrenme Bölgesi'nde gösterilir.
          experience: QuizExperience.learning,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(question.correctAnswer));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    expect(find.text('Açıklama · Zana'), findsOneWidget);
  });
}
