import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_effects.dart';
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
}
