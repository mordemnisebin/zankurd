import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';

import 'support/widget_test_helpers.dart';

void main() {
  Future<void> pumpTour(WidgetTester tester) async {
    await tester.pumpWidget(
      testShell(child: AppShell(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('nav turu iki adımı gösterir, tamamlanır ve tekrar açılmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
    });
    await pumpTour(tester);
    final overlay = find.byType(CoachMarkOverlay);
    expect(overlay, findsOneWidget);
    expect(
      find.descendant(of: overlay, matching: find.text('Ana Sayfa')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('1/2')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: overlay, matching: find.text('İleri')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: overlay, matching: find.text('Yarış')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('2/2')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: overlay, matching: find.text('Profil')),
      findsNothing,
    );

    await tester.tap(
      find.descendant(of: overlay, matching: find.text('Anladım')),
    );
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('zankurd.navTour.seen'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpTour(tester);
    expect(find.byType(CoachMarkOverlay), findsNothing);
  });
}
