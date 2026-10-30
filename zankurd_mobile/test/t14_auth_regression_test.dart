import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';
import 'support/realistic_device.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => freshMockRepository());

  Future<void> open(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(testShell(child: screen));
    await tester.pumpAndSettle();
  }

  testWidgets('T14 misafir yolu açıkça adlandırılır ve üç giriş görünür', (
    tester,
  ) async {
    await open(tester, const SignInScreen());
    for (final label in [
      'Misafir olarak devam et',
      'Apple ile devam et',
      'Google ile devam et',
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    final primary = tester
        .widgetList<SahneButton>(find.byType(SahneButton))
        .where((button) => button.isPrimary);
    expect(primary, hasLength(1));
    expect(primary.single.label, 'Misafir olarak devam et');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('T14 kayıt ilk geri sayfayı, sonraki geri yalnız adımı açar', (
    tester,
  ) async {
    await open(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
            ),
            child: const Text('Önceki sayfa'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Önceki sayfa'));
    await tester.pumpAndSettle();
    final exit = find.byKey(const ValueKey('signup-exit-button'));
    expect(exit.hitTestable(), findsOneWidget);
    await tester.enterText(
      find.byType(EditableText).at(0),
      'rojda@example.com',
    );
    await tester.enterText(find.byType(EditableText).at(1), 'sifre123');
    await tester.enterText(find.byType(EditableText).at(2), 'sifre123');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('signup-next')));
    await tester.pumpAndSettle();
    expect(find.text('Kullanıcı adını seç'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('signup-back-button')));
    await tester.pumpAndSettle();
    expect(find.text('1/3'), findsOneWidget);
    expect(find.byType(SignUpScreen), findsOneWidget);
    await tester.tap(exit);
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsNothing);
    expect(find.text('Önceki sayfa'), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('T14 kayıt kartının sonu perde üstünde tamamen görünür', (
    tester,
  ) async {
    await open(tester, const SignUpScreen());
    final indicator = tester.widget<Scrollbar>(find.byType(Scrollbar).first);
    expect(indicator.thumbVisibility, isTrue);
    final scrollable = find.byType(SingleChildScrollView).first;
    await tester.drag(scrollable, const Offset(0, -1800));
    await tester.pumpAndSettle();
    final card = tester.getRect(find.byKey(const ValueKey('signup-form-card')));
    final dock = tester.getRect(find.byKey(const ValueKey('entry-dock')));
    expect(card.bottom, lessThan(dock.top));
    expect(find.text('Parolayı onayla').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('entry-scroll-fade')), findsNothing);
    expect(
      find.byKey(const ValueKey('sign-up-guest')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
