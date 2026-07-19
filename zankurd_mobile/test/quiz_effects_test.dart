import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_effects.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/confetti_overlay.dart';

void main() {
  group('comboTierFor', () {
    test('2 ve altı seri rozet üretmez', () {
      expect(comboTierFor(0), isNull);
      expect(comboTierFor(1), isNull);
      expect(comboTierFor(2), isNull);
    });

    test('3-4 seri turuncu (bronze) kademe', () {
      expect(comboTierFor(3), ComboTier.bronze);
      expect(comboTierFor(4), ComboTier.bronze);
    });

    test('5-9 seri mor (silver) kademe', () {
      expect(comboTierFor(5), ComboTier.silver);
      expect(comboTierFor(9), ComboTier.silver);
    });

    test('10+ seri altın (gold) kademe', () {
      expect(comboTierFor(10), ComboTier.gold);
      expect(comboTierFor(25), ComboTier.gold);
    });
  });

  group('vignetteStrengthFor', () {
    test('kalan süre üçte birden fazlayken vinyet yok', () {
      expect(vignetteStrengthFor(1.0), 0.0);
      expect(vignetteStrengthFor(0.5), 0.0);
      expect(vignetteStrengthFor(0.34), 0.0);
    });

    test('son üçte birde doğrusal olarak güçlenir', () {
      expect(vignetteStrengthFor(1 / 3), closeTo(0.0, 0.001));
      expect(vignetteStrengthFor(1 / 6), closeTo(0.5, 0.01));
      expect(vignetteStrengthFor(0.0), closeTo(1.0, 0.001));
    });

    test('aralık dışı girdiler kırpılır', () {
      expect(vignetteStrengthFor(-0.2), 1.0);
      expect(vignetteStrengthFor(1.7), 0.0);
    });
  });

  group('ConfettiOverlay parametreleri', () {
    testWidgets('özel parçacık sayısı ve süre ile kurulabilir', (tester) async {
      var finished = false;
      await tester.pumpWidget(
        MaterialApp(
          home: ConfettiOverlay(
            particleCount: 24,
            duration: const Duration(milliseconds: 300),
            onFinished: () => finished = true,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 350));
      expect(finished, isTrue);
    });
  });

  group('ComboBadge', () {
    testWidgets('streak 2 iken görünmez, 3 olunca ×3 rozeti çıkar', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ComboBadge(streak: 2, isKu: false)),
      );
      expect(find.textContaining('×'), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(home: ComboBadge(streak: 3, isKu: false)),
      );
      await tester.pumpAndSettle();
      expect(find.text('×3 Seri!'), findsOneWidget);
    });

    testWidgets('KU modunda Rêz metni kullanılır', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: ComboBadge(streak: 5, isKu: true)),
      );
      await tester.pumpAndSettle();
      expect(find.text('×5 Rêz!'), findsOneWidget);
    });
  });

  group('ShakeWrapper', () {
    testWidgets('trigger artınca sarsıntı animasyonu oynar ve durulur', (
      tester,
    ) async {
      Widget build(int trigger) => MaterialApp(
        home: ShakeWrapper(trigger: trigger, child: const Text('hedef')),
      );
      await tester.pumpWidget(build(0));
      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 50));
      final transform = tester.widget<Transform>(
        find
            .ancestor(of: find.text('hedef'), matching: find.byType(Transform))
            .first,
      );
      expect(transform.transform.getTranslation().x, isNot(0.0));
      await tester.pumpAndSettle();
    });
  });

  group('CriticalVignette', () {
    testWidgets('süre boldayken çizmez, son saniyelerde çizer', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(seconds: 15),
        value: 1.0,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(children: [CriticalVignette(animation: controller)]),
        ),
      );
      expect(
        find.descendant(
          of: find.byType(CriticalVignette),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      controller.value = 0.1; // son ~1.5 saniye
      await tester.pump();
      expect(
        find.descendant(
          of: find.byType(CriticalVignette),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });

  group('Quiz efekt entegrasyonu', () {
    testWidgets('süre dolunca görünür ve canlı semantik bildirim gösterir', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      SeenQuestionStore.resetInstance();
      final repo = MockZanKurdRepository();
      final room = repo.createRoom();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider<SoundProvider>(
              create: (_) => SoundProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: QuizScreen(
              repository: repo,
              room: room,
              questions: [repo.questions.first],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();

      final notice = find.byKey(const ValueKey('quiz-timeout-notice'));
      expect(notice, findsOneWidget);
      // Dalga 5: timeout bandı artık süre + doğru cevabı birlikte bildirir.
      final expected =
          'Süre doldu! Doğru cevap: ${repo.questions.first.correctAnswer}';
      expect(find.text(expected), findsOneWidget);
      final semantics = tester.widget<Semantics>(notice);
      expect(semantics.properties.liveRegion, isTrue);
      expect(semantics.properties.label, expected);
    });

    testWidgets('ilk quiz rehberi açıkken timer cevabı otomatik açmaz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      SeenQuestionStore.resetInstance();
      final repo = MockZanKurdRepository();
      final room = repo.createRoom();
      final question = repo.questions.first;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider<SoundProvider>(
              create: (_) => SoundProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: QuizScreen(
              repository: repo,
              room: room,
              questions: [question],
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 16));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(question.getLocalizedExplanation(false)), findsNothing);
    });

    testWidgets('yanlış cevapta seçilen şık ShakeWrapper içinde', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      SeenQuestionStore.resetInstance();
      final repo = MockZanKurdRepository();
      final room = repo.createRoom();
      final question = repo.questions.first;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider<SoundProvider>(
              create: (_) => SoundProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: QuizScreen(
              repository: repo,
              room: room,
              questions: [question],
              enableTimer: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final wrongAnswer = question.displayAnswers.firstWhere(
        (a) => a != question.correctAnswer,
      );
      await tester.tap(
        find
            .ancestor(
              of: find.text(wrongAnswer),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text(wrongAnswer),
          matching: find.byType(ShakeWrapper),
        ),
        findsWidgets,
      );
      // Doğru şık sarsılmaz
      expect(
        find.ancestor(
          of: find.text(question.correctAnswer),
          matching: find.byType(ShakeWrapper),
        ),
        findsNothing,
      );
    });

    testWidgets('doğru cevapta mini konfeti patlaması görünür', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      SeenQuestionStore.resetInstance();
      final repo = MockZanKurdRepository();
      final room = repo.createRoom();
      final question = repo.questions.first;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider<SoundProvider>(
              create: (_) => SoundProvider(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: QuizScreen(
              repository: repo,
              room: room,
              questions: [question],
              enableTimer: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find
            .ancestor(
              of: find.text(question.correctAnswer),
              matching: find.byType(InkWell),
            )
            .first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ConfettiOverlay), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 1));
    });
  });
}
