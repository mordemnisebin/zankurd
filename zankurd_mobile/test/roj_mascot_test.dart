import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/brand_mark.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

// 2026-09-29 Şahnê: güneş maskotu kaldırıldı ("maskot: Yok … boş durumda
// logo işareti"). Işın rengi bekçisi eski maskotun görünüşünü sabitliyordu;
// yerine plakanın logo işaretini çizdiği ve dekoratif kaldığı korunur.
// 2026-09-30 logo: işaret artık `zankurd_icon.webp` süs katmanı değil, yol
// olarak çizilen [BrandMark]tır (L4 soru balonu) ve plaka yoktur; bekçi
// bunu sabitler: işaret bir `Image`/`DecorationImage` değil `BrandMarkPainter`,
// etrafında kutu (DecoratedBox) yok, ekran okuyucudan gizli.
void main() {
  testWidgets('maskot yerine plakasız logo işareti çizilir, dekoratiftir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: RojMascot())),
    );
    expect(find.byType(Image), findsNothing);
    expect(
      find.descendant(
        of: find.byType(RojMascot),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
      reason: 'işaret plakasız durur',
    );
    final painted = find.descendant(
      of: find.byType(RojMascot),
      matching: find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is BrandMarkPainter,
      ),
    );
    expect(painted, findsOneWidget);
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
