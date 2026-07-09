import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
              titleKu: 'Sereke',
              titleTr: 'Ana Sayfa',
              descriptionKu: 'Açıklama ku',
              descriptionTr: 'Açıklama tr',
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
              titleKu: 'Sereke',
              titleTr: 'Ana Sayfa',
              descriptionKu: 'a',
              descriptionTr: 'b',
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
              titleKu: 'a',
              titleTr: 'b',
              descriptionKu: 'c',
              descriptionTr: 'd',
            ),
            CoachMarkStep(
              targetKey: key,
              icon: Icons.star,
              titleKu: 'e',
              titleTr: 'f',
              descriptionKu: 'g',
              descriptionTr: 'h',
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
              titleKu: 'a',
              titleTr: 'Birinci',
              descriptionKu: 'c',
              descriptionTr: 'd',
            ),
            CoachMarkStep(
              targetKey: key,
              icon: Icons.star,
              titleKu: 'e',
              titleTr: 'İkinci',
              descriptionKu: 'g',
              descriptionTr: 'h',
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
