/// Manzara şeridinin saat bekçisi (2026-10-21).
///
/// Şerit TEMAYA değil cihaz saatine bakar. Eskiden açık tema = şafak, koyu
/// tema = gece idi; öğlen karanlık temada gece göğü görünüyordu. Bu test
/// düşerse: dört dönem (05–10 şafak, 10–17 gündüz, 17–20 akşam, kalan gece)
/// birbirinden farklı palet vermeli ve aynı saat iki temada aynı gök olmalı.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

void main() {
  tearDown(() => SahneClock.now = () => DateTime(2026, 10, 21, 12));

  test('dört saat dört farklı dönem ve palet verir', () {
    final phases = {
      7: SahneVistaPhase.dawn,
      13: SahneVistaPhase.day,
      18: SahneVistaPhase.dusk,
      23: SahneVistaPhase.night,
    };
    phases.forEach((h, p) => expect(SahneVistaPhase.atHour(h), p));
    for (final (h, p) in [
      (5, SahneVistaPhase.dawn),
      (9, SahneVistaPhase.dawn),
      (10, SahneVistaPhase.day),
      (16, SahneVistaPhase.day),
      (17, SahneVistaPhase.dusk),
      (19, SahneVistaPhase.dusk),
      (20, SahneVistaPhase.night),
      (4, SahneVistaPhase.night),
      (0, SahneVistaPhase.night),
    ]) {
      expect(SahneVistaPhase.atHour(h), p, reason: '$h:00');
    }
    final skies = {
      for (final p in SahneVistaPhase.values)
        SahneVistaPalette.of(p).skyTop.toARGB32(),
    };
    expect(skies.length, 4);
    expect(SahneVistaPalette.of(SahneVistaPhase.night).stars, isTrue);
    expect(SahneVistaPalette.of(SahneVistaPhase.day).stars, isFalse);
  });

  Future<SahneVistaPalette> paletteAt(
    WidgetTester tester,
    int hour,
    bool dark,
  ) async {
    SahneClock.now = () => DateTime(2026, 10, 21, hour, 30);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        themeProvider: ThemeProvider(
          initialMode: dark ? ThemeMode.dark : ThemeMode.light,
        ),
        child: const Scaffold(body: SahneVistaStrip()),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byKey(const ValueKey('sahne-vista-strip')),
        matching: find.byType(CustomPaint),
      ),
    );
    return (paint.painter! as SahneVistaPainter).palette;
  }

  for (final hour in [7, 13, 18, 23]) {
    testWidgets('$hour:30 açık ve koyu temada aynı gök', (tester) async {
      final light = await paletteAt(tester, hour, false);
      final dark = await paletteAt(tester, hour, true);
      expect(light, same(dark));
      expect(light, same(SahneVistaPalette.of(SahneVistaPhase.atHour(hour))));
    });
  }
}
