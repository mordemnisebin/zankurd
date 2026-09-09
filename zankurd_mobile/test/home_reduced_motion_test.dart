import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';

import 'support/widget_test_helpers.dart';

void main() {
  testWidgets('hareketi azalt açıkken Home giriş scale/fade katmanı çizilmez', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        reducedMotion: true,
        child: HomeScreen(
          repository: repository,
          onOpenCategories: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('home-progress-summary')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('home-progress-summary')),
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
        child: HomeScreen(
          repository: repository,
          onOpenCategories: () async {},
        ),
      ),
    );
    await tester.pump();

    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('home-progress-summary')),
        matching: find.byType(ScaleTransition),
      ),
      findsOneWidget,
    );
  });
}
