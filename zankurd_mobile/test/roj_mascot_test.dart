import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

// 2026-09-29 Şahnê: güneş maskotu kaldırıldı ("maskot: Yok … boş durumda
// logo işareti"). Işın rengi bekçisi eski maskotun görünüşünü sabitliyordu;
// yerine plakanın logo işaretini çizdiği ve dekoratif kaldığı korunur.
void main() {
  testWidgets('maskot yerine logo işareti plakası çizilir, dekoratiftir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: RojMascot())),
    );
    // İşaret bir `Image` değil, süs katmanıdır (`DecorationImage`).
    expect(find.byType(Image), findsNothing);
    final plate = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(RojMascot),
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).image != null,
        ),
      ),
    );
    final image = (plate.decoration as BoxDecoration).image!.image;
    expect((image as AssetImage).assetName, 'assets/zankurd_icon.webp');
    expect(
      find.byType(CustomPaint).evaluate().where((e) {
        final w = e.widget as CustomPaint;
        return w.painter != null &&
            w.painter.runtimeType.toString().contains('Roj');
      }),
      isEmpty,
    );
    expect(
      find.descendant(
        of: find.byType(RojMascot),
        matching: find.byType(ExcludeSemantics),
      ),
      findsWidgets,
    );
    semantics.dispose();
  });

  testWidgets('RojMascot tüm ruh hâllerinde hatasız çizilir', (tester) async {
    for (final mood in RojMood.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: RojMascot(mood: mood)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(RojMascot), findsOneWidget);
    }
  });

  testWidgets('farklı boyutlarda overflow/exception oluşmaz', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: RojMascot(size: 40))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(home: Center(child: RojMascot(size: 160))),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
