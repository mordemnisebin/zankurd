// 2026-10-19 sadeleşme: joker kapsül çip (görsel 40, dokunma kutusu 48); boy
// bekçisi 52 yerine 48 bekler. Düğme boyları ve etiketleri aynı.
/// Şahnê düğmelerinin bekçisi (birincil, ikincil, metin, pasif, joker).
///
/// ## Neyi korur
///
/// * Tek boy 52 (metin düğmesi 44): büyük yazıda düğme uzar, kesilmez ve
///   320 px'te taşmaz. Eski düğmeler sabit yükseklikle çizildiği için 2.0
///   ölçekte etiket kırpılıyordu; burada yükseklik en az değerdir.
/// * Birincil düğme tek bulanık gölgeyi taşır; pasifte gölge yoktur.
///   2026-10-29 vay katmanı A1: gölgenin YANINDA 4 px koyu taban vardır
///   ([SahneVolume.baseColor]); boy 56 (eski 52). Ayrıntı:
///   `vay_katmani_test.dart`.
/// * Basınca 2 px çökme (80 ms'de); "hareketi azalt" açıkken çökme yok.
/// * Joker adı ekranda yazmaz ama ekran okuyucu "ad, fiyat"ı duyar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Widget all() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SahneButton.primary(
        label: 'Devam et ve bugünün dersini bitir',
        onPressed: noop,
        expand: true,
      ),
      SizedBox(height: 8),
      SahneButton.primary(label: 'Sonraki', onPressed: null, expand: true),
      SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: SahneButton.secondary(
              label: 'Soru çöz',
              icon: AppIcons.circleQuestion,
              onPressed: noop,
              expand: true,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: SahneButton.secondary(
              label: 'Qertên peyvan',
              icon: AppIcons.layerGroup,
              onPressed: noop,
              expand: true,
            ),
          ),
        ],
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: SahneButton.text(label: 'Hemû', onPressed: noop),
      ),
      SahneJokerBar(
        jokers: [
          SahneJokerButton(
            icon: AppIcons.circle,
            label: 'Nîv bi Nîv',
            price: 20,
            onPressed: noop,
          ),
          SahneJokerButton(
            icon: AppIcons.lightbulb,
            label: 'Alîkariya Bersivê',
            price: 30,
            onPressed: noop,
          ),
          SahneJokerButton(
            icon: AppIcons.listCheck,
            label: 'Du Bersiv',
            price: 50,
            onPressed: noop,
          ),
          SahneJokerButton(
            icon: AppIcons.arrowsRotate,
            label: 'Pirsê Biguhere',
            price: 40,
            onPressed: null,
          ),
        ],
      ),
    ],
  );

  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: 320 px @2.0 taşmaz, boylar ve etiketler doğru', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(tester, all(), dark: dark);
      expect(tester.takeException(), isNull);

      for (final b in tester.widgetList(find.byType(SahneButton))) {
        final size = tester.getSize(find.byWidget(b));
        expect(size.height, greaterThanOrEqualTo(44), reason: '$b');
      }
      for (final f in [find.byType(FilledButton)]) {
        for (final e in f.evaluate()) {
          expect(
            tester.getSize(find.byWidget(e.widget)).height,
            greaterThanOrEqualTo(52) /* birincil 56 */,
          );
        }
      }
      for (final e in find.byType(SahneJokerButton).evaluate()) {
        final size = tester.getSize(find.byWidget(e.widget));
        // 2026-10-19 sadeleşme: joker kapsül çip (görsel 40); dokunma kutusu 48.
        expect(size.height, greaterThanOrEqualTo(48));
        expect(size.width, greaterThanOrEqualTo(44));
      }
      expect(find.bySemanticsLabel('Nîv bi Nîv, 20'), findsOneWidget);
      expect(find.bySemanticsLabel('Hemû'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('birincil düğme eylem gölgesini taşır; pasifte gölge yok', (
    tester,
  ) async {
    await pumpSahne(
      tester,
      const Column(
        children: [
          SahneButton.primary(label: 'A', onPressed: noop),
          SahneButton.primary(label: 'B', onPressed: null),
        ],
      ),
      dark: true,
      textScale: 1,
    );
    List<BoxShadow> shadowsOf(String label) {
      final boxes = tester.widgetList<DecoratedBox>(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(DecoratedBox),
        ),
      );
      return [
        for (final b in boxes)
          if (b.decoration case ShapeDecoration(:final shadows?)) ...shadows,
      ];
    }

    final active = shadowsOf('A');
    // Vay A1: koyu taban + eylem gölgesi.
    expect(active, hasLength(2));
    expect(active.first.color, SahneVolume.baseColor);
    final glow = active.last;
    expect(glow.color, SahneTokens.night.actShadow);
    expect(glow.offset, const Offset(0, 8));
    expect(glow.spreadRadius, -8);
    expect(shadowsOf('B'), isEmpty);
  });

  for (final reduce in [false, true]) {
    testWidgets('basınca 2 px çöker (hareketi azalt: $reduce)', (tester) async {
      await pumpSahne(
        tester,
        const SahneButton.primary(label: 'Bas', onPressed: noop),
        dark: true,
        textScale: 1,
        reduceMotion: reduce,
      );
      final before = tester.getTopLeft(find.text('Bas'));
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Bas')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final during = tester.getTopLeft(find.text('Bas'));
      expect(during.dy - before.dy, reduce ? 0 : 2);
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(find.text('Bas')), before);
    });
  }

  testWidgets('pasif joker fiyatı göstermez ve dokunulamaz', (tester) async {
    var taps = 0;
    await pumpSahne(
      tester,
      Row(
        children: [
          Expanded(
            child: SahneJokerButton(
              icon: AppIcons.circle,
              label: 'Nîv bi Nîv',
              price: 20,
              onPressed: () => taps++,
            ),
          ),
          const Expanded(
            child: SahneJokerButton(
              icon: AppIcons.lightbulb,
              label: 'Alîkarî',
              price: 30,
              onPressed: null,
            ),
          ),
        ],
      ),
      dark: false,
      textScale: 1,
    );
    expect(find.text('20'), findsOneWidget);
    expect(find.text('30'), findsNothing);
    await tester.tap(find.text('20'));
    expect(taps, 1);
  });

  // Kurul 3. tur 2026-10-20: ikincil ve pasif düğme aynı soluk gri-mavi
  // dolguyu taşıyordu, ayırt edilemiyordu. İkincil = şeffaf + 1,5 px görünür
  // kenar + güçlü etiket; pasif = düz soluk dolgu, KENARSIZ, soluk etiket.
  for (final entry in kThemes.entries) {
    testWidgets('ikincil ve pasif düğme ayrı okunur (${entry.key})', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const Column(
          children: [
            SahneButton.secondary(label: 'Kur', onPressed: noop),
            SahneButton.secondary(label: 'Pasif', onPressed: null),
          ],
        ),
        dark: entry.value,
        textScale: 1,
      );
      final t = SahneTokens.of(tester.element(find.text('Kur')));
      final buttons = tester
          .widgetList<FilledButton>(find.byType(FilledButton))
          .toList();
      final on = buttons[0].style!;
      final off = buttons[1].style!;
      expect(on.backgroundColor!.resolve({}), Colors.transparent);
      final edge = on.side!.resolve({})!;
      expect(edge.width, 1.5);
      expect(edge.color, t.secondaryEdge);
      expect(on.foregroundColor!.resolve({}), t.tx);
      expect(
        off.backgroundColor!.resolve({WidgetState.disabled}),
        t.disabledFill,
      );
      expect(off.side!.resolve({WidgetState.disabled}), BorderSide.none);
      expect(
        off.foregroundColor!.resolve({WidgetState.disabled}),
        t.disabledFg,
      );
    });
  }
}
