// 2026-10-28 kurul K15: seçili segment/sekme/çip turuncu ton değil KOYU
// MÜREKKEP dolgu + açık metindir; turuncu yalnız birincil düğmededir.
//
// Kusur: `selFill/selLine/selTx` turuncu tondu; her ekranda seçili çip,
// birincil düğme ve seri çipi birlikte turuncu yarışıyordu. Eski turuncu ton
// `warmFill/warmTx` olarak seçim OLMAYAN sıcak vurgular için (seri çipi)
// kaldı. Bu bekçi tokenı ve gerçek bir çipi ölçer.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color a, Color b) {
  final x = _lum(a), y = _lum(b);
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

void main() {
  _actionCardTests();
  for (final (name, t) in [
    ('gündüz', SahneTokens.day),
    ('gece', SahneTokens.night),
  ]) {
    test(
      '$name: seçili dolgu nötr mürekkep, turuncu değil, metin >= 4.5:1',
      () {
        expect(t.selFill, t.tx, reason: 'mürekkep dolgu');
        expect(t.selFill, isNot(t.act));
        expect(t.selLine, t.selFill);
        expect(_contrast(t.selTx, t.selFill), greaterThanOrEqualTo(4.5));
        // Seçili çip zeminden ve seçilmemiş çipten ayrışır.
        expect(_contrast(t.selFill, t.bg), greaterThanOrEqualTo(3));
      },
    );
  }

  testWidgets('SahneRailChip seçili: mürekkep dolgu + açık metin', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SahneRailChip(label: 'Ziman', selected: true, onTap: () {}),
        ),
      ),
    );
    final t = SahneTokens.of(tester.element(find.byType(SahneRailChip)));
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byType(SahneRailChip),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, t.selFill);
    expect(tester.widget<Text>(find.text('Ziman')).style?.color, t.selTx);
  });
}

// K3 ortak ikincil eylem kartı: nötr yüzey, rozet rengi rol, ≥ 48 yükseklik.
void _actionCardTests() {
  testWidgets('SahneActionCard nötr yüzey + renkli rozet, ≥ 48', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SahneActionCard(
            icon: Icons.casino,
            title: 'Günün çarkı',
            subtitle: 'Bugün çevir',
            role: SahneRole.gold,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    final t = SahneTokens.of(tester.element(find.byType(SahneActionCard)));
    final surface = tester.widget<SahneTappable>(find.byType(SahneTappable));
    expect(surface.color, t.s1, reason: 'kart dolu renk değil, nötr yüzey');
    expect(
      tester.getSize(find.byType(SahneActionCard)).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byType(SahneActionCard));
    expect(taps, 1);
  });
}
