import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/guest_account_email_form.dart';
import 'package:zankurd_mobile/src/widgets/whole_scroll_row.dart';

import 'support/okunur_boyut.dart';
import 'support/t15_capture.dart';
import 'support/widget_test_helpers.dart';

void main() {
  setUp(freshMockRepository);
  setUpAll(loadT15Fonts);

  for (final ku in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('T17 form ipucu 320pt x$scale ku=$ku okunur ve kayar', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 568);
        addTearDown(tester.view.reset);
        final controller = GuestAccountEmailController();
        await tester.pumpWidget(
          testShell(
            languageProvider: ku ? kurmanciLang() : turkishLang(),
            child: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        GuestAccountEmailForm(controller: controller),
                        GuestAccountSaveButton(
                          controller: controller,
                          onPressed: () => fail('boş form gönderilemez'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final hint = find.text(
          ku
              ? 'E-name û şîfreyeke herî kêm 6 karakterî binivîse'
              : 'E-posta ve en az 6 karakterlik parola gir',
        );
        await tester.ensureVisible(hint);
        await tester.pumpAndSettle();
        expect(hint.hitTestable(), findsOneWidget);
        expect(
          renderedFontSize(tester, hint),
          greaterThanOrEqualTo(14 * scale),
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
    }
  }

  testWidgets('T17 tam satır kırpması boyut değişiminde güncellenir', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 200);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: const [
              SizedBox(height: 150),
              WholeScrollRow(
                child: SizedBox(
                  height: 80,
                  child: Center(child: Text('Son satır')),
                ),
              ),
              SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Son satır').hitTestable(), findsNothing);
    tester.view.physicalSize = const Size(320, 300);
    await tester.pumpAndSettle();
    expect(find.text('Son satır').hitTestable(), findsOneWidget);
    tester.view.physicalSize = const Size(320, 200);
    await tester.pumpAndSettle();
    expect(find.text('Son satır').hitTestable(), findsNothing);
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();
    expect(find.text('Son satır').hitTestable(), findsOneWidget);
  });
}
