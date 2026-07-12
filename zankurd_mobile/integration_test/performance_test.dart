// Performans ölçüm senaryosu (integration_test + flutter drive, profile mode).
//
// GERÇEK CİHAZDA çalıştırma (profile mode zorunlu — debug ölçümü yanıltır):
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/performance_test.dart \
//     --profile -d <device_id>
//
// Çıktı: build/ altına timeline + özet yazılır; perf_driver.dart bunu
// output/performance/ altına taşır (aşağıdaki README'ye bakın).
//
// NOT: Bu dosya geliştirme makinesine bağlı milisaniye assertion'ları İÇERMEZ.
// Frame süreleri cihazdan cihaza değişir; eşik yerine timeline raporu üretilir
// ve gözden geçirilir. Yalnız kaba bir üst sınır (çok gevşek) korunur.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Kaydırma performansı: uzun liste', (tester) async {
    // Ana ekran / öğrenme yolu / civak gibi uzun listeleri temsil eden
    // sentetik bir liste. Gerçek ekranlar auth gerektirdiğinden, cihazdan
    // bağımsız ve tekrarlanabilir bir kaydırma profili ölçülür.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 400,
            itemBuilder: (_, i) => ListTile(
              leading: const Icon(Icons.local_fire_department_rounded),
              title: Text('Rêz $i'),
              subtitle: Text('Naveroka nimûne — $i'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final listFinder = find.byType(Scrollable);

    await binding.traceAction(() async {
      for (var i = 0; i < 5; i++) {
        await tester.fling(listFinder, const Offset(0, -400), 4000);
        await tester.pumpAndSettle();
        await tester.fling(listFinder, const Offset(0, 400), 4000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'scroll_timeline');

    // Çok gevşek güvenlik sınırı: derleme/donma değil, tümüyle çökme yakalar.
    expect(tester.takeException(), isNull);
  });
}
