import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

// Zana'nın 12 ışını altın + indigo dönüşümüyle çizilir — sakin, ritmik
// iki renkli bir şerit (4 rengin kaotik dönüşümü küçük boyutta gürültü
// gibi okunduğu için sadeleştirildi). Geometri/ifade değişmez.
void main() {
  test('ışın rengi deseni sakin iki renkli dönüşüm (altın/indigo)', () {
    expect(RojMascot.rayColors, [AppTheme.gold, AppTheme.brandGreen]);
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
