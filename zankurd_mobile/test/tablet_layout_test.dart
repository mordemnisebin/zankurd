import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/widgets/responsive_wrapper.dart';

/// iPad'de içerik sınırı HİÇ bağlamıyordu (2026-08-01, P1-002).
///
/// `maxContentWidth` 1200 pt'ydi; iPad Pro 13" dikey mantıksal genişliği ise
/// ~1032 pt, yani sınırın altında. `ResponsiveWrapper` devreye giriyor ama
/// `ConstrainedBox` hiçbir şeyi kısıtlamıyordu ve telefon düzeni tablete
/// gerilmiş hâlde çiziliyordu — gerçek iPad Pro 13" simülatöründe görüldü:
/// hero kartı ~1400 pt boş bir dikdörtgen, içerik sol %30'a sıkışmış, altta
/// yüzlerce pt boşluk.
///
/// `TARGETED_DEVICE_FAMILY = "1,2"` olduğu için Apple uygulamayı iPad'de
/// inceler ve iPad ekran görüntüsü ister; kusuru görmezden gelme seçeneği
/// yoktu.
///
/// Bu bekçi sınırı gerçek cihaz genişlikleriyle sınar. Sabit sayıyı
/// doğrulamak yetmez — asıl soru "bu genişlikte içerik gerçekten
/// sınırlanıyor mu".
void main() {
  /// Gerçek cihazların mantıksal genişlikleri (pt).
  const deviceWidths = <String, double>{
    'iPhone 17': 402,
    'iPhone 17 Pro Max': 440,
    'iPad mini (dikey)': 744,
    'iPad Air 11" (dikey)': 820,
    'iPad Pro 13" (dikey)': 1032,
    'iPad Pro 13" (yatay)': 1376,
    'masaüstü web': 1680,
  };

  Future<double> renderedWidth(WidgetTester tester, double screenWidth) async {
    tester.view.physicalSize = Size(screenWidth, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: ResponsiveWrapper(
          child: Container(key: const ValueKey('content')),
        ),
      ),
    );
    await tester.pump();
    return tester.getSize(find.byKey(const ValueKey('content'))).width;
  }

  testWidgets('telefon genişliklerinde tam ekran korunur', (tester) async {
    for (final entry in deviceWidths.entries.where((e) => e.value <= 600)) {
      final width = await renderedWidth(tester, entry.value);
      expect(
        width,
        entry.value,
        reason:
            '${entry.key}: telefonda içerik daraltılmamalı, tam ekran '
            'kalmalı',
      );
    }
  });

  testWidgets('tablet ve masaüstünde içerik okunur ölçüye sınırlanır', (
    tester,
  ) async {
    for (final entry in deviceWidths.entries.where((e) => e.value > 600)) {
      final width = await renderedWidth(tester, entry.value);
      expect(
        width,
        lessThanOrEqualTo(ResponsiveWrapper.maxContentWidth),
        reason:
            '${entry.key} (${entry.value} pt): içerik sınırlanmıyor — telefon '
            'düzeni tablete geriliyor',
      );
    }
  });

  testWidgets('iPad Pro 13" dikeyde sınır GERÇEKTEN bağlıyor', (tester) async {
    // Kusurun tam olarak yaşandığı genişlik. 1200 pt'lik eski sınır burada
    // hiç devreye girmiyordu; regresyon bu tek satırla yakalanır.
    const iPadPortrait = 1032.0;
    final width = await renderedWidth(tester, iPadPortrait);
    expect(
      width,
      lessThan(iPadPortrait),
      reason:
          'iPad Pro 13" dikeyde içerik hâlâ tam genişliğe yayılıyor — '
          'maxContentWidth bu cihazda bağlamıyor',
    );
  });

  test('sınır, kabuğun masaüstü gezinme eşiğinin üstünde kalır', () {
    // `AppShell` 768 px'de NavigationRail'e geçiyor. Sınır bunun altına
    // düşerse o breakpoint hiç erişilemez hâle gelir ve masaüstü gezinmesi
    // ölü kod olur.
    expect(
      ResponsiveWrapper.maxContentWidth,
      greaterThan(AppShell.desktopNavBreakpoint),
      reason:
          'içerik sınırı masaüstü gezinme eşiğinin altına indi; '
          'NavigationRail erişilemez oldu',
    );
  });
}
