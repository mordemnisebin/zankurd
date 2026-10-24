// Tasarım kurulu tur 8 (Opus): seviye listesinde başlığın altındaki tam
// genişlik koyu çizgi, 0/5 seviyede "tamamlanmış ilerleme" gibi okunuyordu.
//
// Niçin sessiz kaldı: çizgi kategori kimliğini taşıyan SÜS çizgisiydi;
// testler yalnız varlığına ve yüksekliğine bakıyordu, ilerleme anlamı
// taşımadığını kimse sormadı. Şimdi seviye ekranında çizgi gerçek bir
// ilerleme çubuğu: dolu kısım tamamlanan/toplam oranında, 0'da görünmez.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/widgets/category_band.dart';

import 'support/widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pump(WidgetTester tester, double? progress) => tester.pumpWidget(
    testShell(
      child: CategoryBandScaffold(
        category: 'Ziman',
        title: 'Dil',
        subtitle: 'Alt',
        progress: progress,
        body: const SizedBox(),
      ),
    ),
  );

  testWidgets('0 ilerlemede dolu kısım çizilmez', (tester) async {
    await pump(tester, 0);
    final track = find.byKey(CategoryBandScaffold.accentKey);
    expect(
      find.descendant(of: track, matching: find.byType(FractionallySizedBox)),
      findsNothing,
    );
  });

  testWidgets('dolu kısım oran kadar genişler', (tester) async {
    await pump(tester, 0.4);
    final track = find.byKey(CategoryBandScaffold.accentKey);
    final fill = find.descendant(
      of: track,
      matching: find.byType(FractionallySizedBox),
    );
    expect(
      tester.getSize(fill).width / tester.getSize(track).width,
      closeTo(0.4, 0.01),
    );
    expect(tester.getSize(track).height, 4);
  });
}
