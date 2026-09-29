// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
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

  // 2026-09-29 Şahnê: rozet eskiden Forest kimlik gradyanını taşıyordu;
  // Şahnê'de gradyanlı karo yok. Rozet Zêr rolünün ton karosudur (M pah),
  // ikon rolün metin rengi — bekçi artık bunu sabitler.
  testWidgets('tutorial bilgi rozeti Zêr rolünün ton karosunu kullanır', (
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
              title: 'Ana sayfa',
              description: 'Açıklama tr',
            ),
          ],
          onFinished: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<DecoratedBox>(
      find
          .ancestor(
            of: find.byIcon(Icons.home_rounded),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final t = SahneTokens.of(tester.element(find.byIcon(Icons.home_rounded)));
    final decoration = badge.decoration as ShapeDecoration;
    expect(decoration.gradient, isNull);
    expect(decoration.color, t.goldTint);
    expect(decoration.shape, SahneShape.m);
    final icon = tester.widget<Icon>(find.byIcon(Icons.home_rounded));
    expect(icon.color, t.goldTx);
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
              title: 'Ana sayfa',
              description: 'Açıklama tr',
            ),
          ],
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ana sayfa'), findsOneWidget);
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
              title: 'Rûpela sereke',
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
