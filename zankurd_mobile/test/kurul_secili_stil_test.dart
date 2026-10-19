// Kurul incelemesi 2026-10-19 (7 görsel model): seçili çip/segment/sekme
// uygulama genelinde TEK stildir (turuncu ton dolgu + turuncu çizgi + koyu
// turuncu metin); dolu turuncu yalnız ana eylem düğmesindedir. Seçili çip
// magenta/yeşil dolguyla doldurulunca ana düğmeyle yarışıyordu (4 model).
// Bu bekçi, ton üstündeki metnin iki temada WCAG AA (4.5:1) geçtiğini ve
// bileşenin ortak belirteci kullandığını ölçer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  for (final t in [SahneTokens.day, SahneTokens.night]) {
    test('seçili metin ton dolgu üstünde ≥ 4.5:1', () {
      expect(_contrast(t.selTx, t.selFill), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('SahneRailChip ve SahnePickChip aynı seçili dolguyu kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SahneRailChip(label: 'A', selected: true, onTap: () {}),
            SahnePickChip(label: 'B', selected: true, onTap: () {}),
          ],
        ),
      ),
    );
    final fills = tester
        .widgetList<Material>(find.byType(Material))
        .map((m) => m.color)
        .whereType<Color>();
    expect(fills.where((c) => c == SahneTokens.day.selFill).length, 2);
  });
}
