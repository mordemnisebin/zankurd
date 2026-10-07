import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/question_metadata.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('öğrenme quizinde rekabet baskısı elemanları görünmez', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: repository.questions.take(3).toList(),
            experience: QuizExperience.learning,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Puan'), findsNothing);
    expect(find.text('50/50'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);
  });

  testWidgets('öğrenme modu opt-in MC sorusunu yazmalı hatırlamaya çevirir', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    const question = QuizQuestion(
      id: 'productive-opt-in',
      category: 'Ziman',
      prompt: 'Dijwateya peyva "dirêj" çi ye?',
      answers: ['Kurt', 'Fireh', 'Giran', 'Nerm'],
      correctAnswer: 'Kurt',
      explanation: 'Dirêj û kurt dijwate ne.',
      metadata: QuestionMetadata(
        reviewStatus: ReviewStatus.approved,
        productiveRecallEligible: true,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [question],
            experience: QuizExperience.learning,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fill-in-blank-input')), findsOneWidget);
    expect(find.text('Fireh'), findsNothing);
  });

  testWidgets('öğrenme modu ilk normal soruyu ısınma olarak korur', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    const productive = QuizQuestion(
      id: 'productive-first',
      category: 'Ziman',
      prompt: 'Hilberîna nivîskî',
      answers: ['Kurt', 'Fireh', 'Giran', 'Nerm'],
      correctAnswer: 'Kurt',
      explanation: 'Dijwateya dirêj kurt e.',
      metadata: QuestionMetadata(
        reviewStatus: ReviewStatus.approved,
        productiveRecallEligible: true,
      ),
    );
    const warmup = QuizQuestion(
      id: 'warmup-second',
      category: 'Ziman',
      // Sözlükte olmayan sözcükler: öğrenme modunda sözlükteki sözcükler
      // dokunulabilir (WidgetSpan) çizilir ve `find.text` düz metni bulamaz.
      prompt: 'Qiqrop zeqnok',
      answers: ['A', 'B', 'C', 'D'],
      correctAnswer: 'A',
      explanation: 'A bersiva rast e.',
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [productive, warmup],
            experience: QuizExperience.learning,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qiqrop zeqnok'), findsOneWidget);
    expect(find.text('Hilberîna nivîskî'), findsNothing);
    expect(find.byKey(const ValueKey('fill-in-blank-input')), findsNothing);
  });

  testWidgets('yarışma modu aynı opt-in soruyu çoktan seçmeli bırakır', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    const question = QuizQuestion(
      id: 'productive-opt-in-competition',
      category: 'Ziman',
      prompt: 'Dijwateya peyva "dirêj" çi ye?',
      answers: ['Kurt', 'Fireh', 'Giran', 'Nerm'],
      correctAnswer: 'Kurt',
      explanation: 'Dirêj û kurt dijwate ne.',
      metadata: QuestionMetadata(
        reviewStatus: ReviewStatus.approved,
        productiveRecallEligible: true,
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
          ChangeNotifierProvider(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ReducedMotionProvider>(
            create: (_) => ReducedMotionProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [question],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('fill-in-blank-input')), findsNothing);
    expect(find.text('Fireh'), findsOneWidget);
  });
}
