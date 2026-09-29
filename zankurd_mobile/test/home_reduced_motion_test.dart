import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';

import 'support/widget_test_helpers.dart';

// Çapa `home-daily-task`: ana ekranın her oturumda çizilen tek öğesi.
// Önceki çapa ilerleme özetiydi; o artık ilk oturumda yer almıyor
// (2026-09-30 doğallık: yerine geçen "3 adımda ZanKurd" kartı da kalktı).
void main() {
  testWidgets('hareketi azalt açıkken Home giriş scale/fade katmanı çizilmez', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(reducedMotion: true, child: HomeScreen(repository: repository)),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('home-daily-task')),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
      reason: 'Reduced-motion açıkken ana içerik ilk kareden sabit görünmeli.',
    );
  });

  testWidgets('normal modda Home giriş animasyonu korunur', (tester) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        reducedMotion: false,
        child: HomeScreen(repository: repository),
      ),
    );
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('home-daily-task')),
        matching: find.byType(ScaleTransition),
      ),
      findsOneWidget,
    );
  });
}
