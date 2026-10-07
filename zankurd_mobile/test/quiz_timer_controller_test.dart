import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_timer_controller.dart';

void main() {
  testWidgets('QuizTimerController starts and counts down', (tester) async {
    final controller = QuizTimerController(
      vsync: tester,
      duration: const Duration(seconds: 10),
      onTimeout: () {},
    );

    expect(controller.value, 1.0);
    expect(controller.isAnimating, isFalse);

    controller.start();
    await tester.pump();
    expect(controller.isAnimating, isTrue);

    controller.pause();
    expect(controller.isAnimating, isFalse);

    controller.resume();
    expect(controller.isAnimating, isTrue);

    controller.dispose();
  });

  testWidgets(
    'QuizTimerController triggers onTimeout when duration completes',
    (tester) async {
      var timeoutCalled = false;
      final controller = QuizTimerController(
        vsync: tester,
        duration: const Duration(seconds: 2),
        onTimeout: () => timeoutCalled = true,
      );

      controller.start();
      await tester.pump();
      expect(timeoutCalled, isFalse);

      // Süreyi tamamla
      await tester.pump(const Duration(seconds: 2, milliseconds: 100));

      expect(timeoutCalled, isTrue);
      expect(controller.value, 0.0);

      controller.dispose();
    },
  );

  testWidgets(
    'QuizTimerController handles lifecycle pause and resume correctly',
    (tester) async {
      final controller = QuizTimerController(
        vsync: tester,
        duration: const Duration(seconds: 10),
        onTimeout: () {},
      );

      // Animasyon başlamadan arka plana giderse, dönüşte başlatılmamalı
      controller.handleLifecyclePause();
      expect(controller.isPausedByLifecycle, isFalse);
      expect(controller.handleLifecycleResume(), isFalse);

      // Animasyon başladıktan sonra arka plana giderse
      controller.start();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(controller.isAnimating, isTrue);

      controller.handleLifecyclePause();
      expect(controller.isPausedByLifecycle, isTrue);
      expect(controller.isAnimating, isFalse);

      final resumed = controller.handleLifecycleResume();
      expect(resumed, isTrue);
      expect(controller.isAnimating, isTrue);

      controller.dispose();
    },
  );

  testWidgets(
    'QuizTimerController in untimed mode does not countdown or timeout',
    (tester) async {
      var timeoutCalled = false;
      final controller = QuizTimerController(
        vsync: tester,
        duration: const Duration(seconds: 1),
        onTimeout: () => timeoutCalled = true,
        isUntimed: true,
      );

      controller.start();
      await tester.pump();
      expect(controller.isAnimating, isFalse);

      await tester.pump(const Duration(seconds: 2));
      expect(timeoutCalled, isFalse);

      controller.dispose();
    },
  );

  testWidgets('QuizTimerController sync updates fraction properly', (
    tester,
  ) async {
    final controller = QuizTimerController(
      vsync: tester,
      duration: const Duration(seconds: 10),
      onTimeout: () {},
    );

    controller.sync(0.5);
    await tester.pump();
    expect(controller.value, 0.5);
    expect(controller.isAnimating, isTrue);

    controller.dispose();
  });
}
