import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';

void main() {
  Widget wrapTarget(GlobalKey key, {required Widget overlayChild}) {
    return MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned(
              left: 10,
              top: 10,
              child: Container(
                key: key,
                width: 40,
                height: 40,
                color: Colors.red,
              ),
            ),
            overlayChild,
          ],
        ),
      ),
    );
  }

  testWidgets('tutorial bilgi rozeti Forest kimliğini kullanır', (
    tester,
  ) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      wrapTarget(
        key,
        overlayChild: CoachMarkOverlay(
          steps: [
            CoachMarkStep(
              targetKey: key,
              icon: Icons.home_rounded,
              title: 'Ana Sayfa',
              description: 'Açıklama tr',
            ),
          ],
          onFinished: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.home_rounded),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = badge.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, AppTheme.identityHeaderGradient.colors);
  });

  testWidgets('ilk adim baslik ve aciklamayi gosterir', (tester) async {
    final key = GlobalKey();
    var finished = false;

    await tester.pumpWidget(
      wrapTarget(
        key,
        overlayChild: CoachMarkOverlay(
          steps: [
            CoachMarkStep(
              targetKey: key,
              icon: Icons.home_rounded,
              title: 'Ana Sayfa',
              description: 'Açıklama tr',
            ),
          ],
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana Sayfa'), findsOneWidget);
    expect(find.text('Açıklama tr'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(finished, isFalse);
  });

  testWidgets('son adimda ileri butonu onFinished tetikler', (tester) async {
    final key = GlobalKey();
    var finished = false;

    await tester.pumpWidget(
      wrapTarget(
        key,
        overlayChild: CoachMarkOverlay(
          steps: [
            CoachMarkStep(
              targetKey: key,
              icon: Icons.home_rounded,
              title: 'Sereke',
              description: 'a',
            ),
          ],
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  testWidgets('atla butonu hemen onFinished tetikler', (tester) async {
    final key = GlobalKey();
    var finished = false;

    await tester.pumpWidget(
      wrapTarget(
        key,
        overlayChild: CoachMarkOverlay(
          steps: [
            CoachMarkStep(
              targetKey: key,
              icon: Icons.home_rounded,
              title: 'a',
              description: 'c',
            ),
            CoachMarkStep(
              targetKey: key,
              icon: Icons.star,
              title: 'e',
              description: 'g',
            ),
          ],
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });

  testWidgets('ileri butonu bir sonraki adima gecer', (tester) async {
    final key = GlobalKey();

    await tester.pumpWidget(
      wrapTarget(
        key,
        overlayChild: CoachMarkOverlay(
          steps: [
            CoachMarkStep(
              targetKey: key,
              icon: Icons.home_rounded,
              title: 'Birinci',
              description: 'c',
            ),
            CoachMarkStep(
              targetKey: key,
              icon: Icons.star,
              title: 'İkinci',
              description: 'g',
            ),
          ],
          onFinished: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Birinci'), findsOneWidget);
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(find.text('İkinci'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });
}
