// Kurul incelemesi 2026-10-19 (7 görsel model): seçili çip/segment/sekme
// uygulama genelinde TEK stildir (turuncu ton dolgu + turuncu çizgi + koyu
// turuncu metin); dolu turuncu yalnız ana eylem düğmesindedir. Seçili çip
// magenta/yeşil dolguyla doldurulunca ana düğmeyle yarışıyordu (4 model).
// Kurul 4. tur 2026-10-20: seçili hâl yalnız ince çerçeveyle okunuyordu
// (oda kurma sheet'i); dolgu koyulaştı (gündüz #FFE1CC, gece opak #4A321F)
// ve SahnePickChip seçiliyken ✓ taşır.
// Bu bekçi, ton üstündeki metnin iki temada WCAG AA (4.5:1) geçtiğini ve
// bileşenin ortak belirteci kullandığını ölçer.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  railChipIdleGuard();
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

  // 2026-10-28 kurul K15: turuncu ton dolgu (4. tur) KOYU MÜREKKEP dolguya
  // çevrildi; eski ton `warmFill` olarak seçim dışı vurgularda kaldı.
  // Ayrıntılı bekçi: `secili_murekkep_test.dart`.
  test('seçili dolgu mürekkep; eski turuncu ton warmFill', () {
    expect(SahneTokens.day.selFill, SahneTokens.day.tx);
    expect(SahneTokens.night.selFill, SahneTokens.night.tx);
    expect(SahneTokens.day.warmFill, const Color(0xFFFFE1CC));
    expect(SahneTokens.night.warmFill, const Color(0xFF4A321F));
  });

  testWidgets('SahnePickChip seçiliyken ✓ taşır, seçili değilken taşımaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            SahnePickChip(label: '8', selected: true, onTap: () {}),
            SahnePickChip(label: '16', selected: false, onTap: () {}),
          ],
        ),
      ),
    );
    expect(find.byIcon(AppIcons.check), findsOneWidget);
  });
}

// Tur 10b kusuru: seçilmemiş ray çipi sayfa/kart beyazıyla aynı dolguda,
// düz metin gibi duruyordu; seçili çip de ders çerçevesi ve Başla ile aynı
// güçlü 2 px turuncuyu taşıyordu. Sessizdi: ikisi de "çalışıyor" ve AA geçiyor.
// Bekçi: seçilmemiş çip sayfa zemininden (s1 değil s2) ayrışır; seçili çipin
// çerçevesi 1 px'tir ve iki hâl AYNI halka kalınlığında (boyut oynamaz).
void railChipIdleGuard() {
  testWidgets('ray çipi: seçilmemiş nötr dolgulu, seçili ince çerçeveli', (
    tester,
  ) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: const Scaffold(
            body: Row(
              children: [
                SahneRailChip(
                  key: Key('idle'),
                  label: 'A',
                  selected: false,
                  onTap: _noop,
                ),
                SahneRailChip(
                  key: Key('sel'),
                  label: 'B',
                  selected: true,
                  onTap: _noop,
                ),
              ],
            ),
          ),
        ),
      );
      final t = SahneTokens.of(tester.element(find.byKey(const Key('idle'))));
      Material mat(String k) => tester.widget<Material>(
        find
            .descendant(of: find.byKey(Key(k)), matching: find.byType(Material))
            .first,
      );
      expect(mat('idle').color, t.s2);
      expect(mat('idle').color, isNot(t.s1));
      final side = (mat('sel').shape! as OutlinedBorder).side;
      expect(side.width, SahneRailChip.railChipRing);
      expect(side.width, lessThanOrEqualTo(1));
    }
  });
}

void _noop() {}
