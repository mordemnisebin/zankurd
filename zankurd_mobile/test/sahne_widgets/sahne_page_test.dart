/// Şahnê sayfa iskeletlerinin bekçisi: A sekme, B açılan, C oyun sahnesi.
///
/// ## Neyi korur
///
/// * Üç iskelet, üç başlık: 2026-09-28 ölçümünde sekiz ekranda altı ayrı
///   başlık biçimi vardı. Başlık metni başlık olarak duyurulur.
/// * A: marka satırı büyük yazıda sığmazsa çipler alt satıra iner;
///   320 px @2.0'da taşma yok. 2026-09-29: başlık satır sınırı olmadan
///   sarar (eskiden 2 satırda "…" ile kesiliyordu) ve sözü harf harf
///   bölünmez.
/// * B: geri düğmesi görselde 44 × 44, dokunmada 48 × 48 (2026-09-29:
///   Android kılavuzu), sözü var.
/// * C: gündüz temasında da GECE; orta yuva (sayaç) yan öğeler farklı
///   genişlikte olsa da tam ortada durur.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

const _stats = [
  SahneStatChip(
    leading: SahneGlyph(SahneGlyphKind.flame),
    label: '3 roj',
    semanticLabel: '3 roj',
  ),
  SahneStatChip(
    leading: SahneGlyph(SahneGlyphKind.coin),
    label: '120',
    semanticLabel: '120 zêr',
    onTap: noop,
  ),
];

void main() {
  setUpAll(loadAppFonts);

  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: A sekme sayfası 320 @2.0 taşmaz', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const SahneTabPage(
          title: 'Bi xêr hatî, Lîstikvan!',
          subtitle: 'Her roj çend pirs. Ziman xurt dibe.',
          stats: _stats,
          children: [
            SahneSectionHeader(
              title: 'Mijar',
              actionLabel: 'Hemû',
              onAction: noop,
            ),
          ],
        ),
        dark: dark,
        page: true,
      );
      expect(tester.takeException(), isNull);
      final title = tester.widget<Text>(find.text('Bi xêr hatî, Lîstikvan!'));
      expect(title.maxLines, isNull, reason: 'başlık kesilmez, sarar');
      expect(title.overflow, isNot(TextOverflow.ellipsis));
      expect(
        tester
            .getSemantics(find.text('Bi xêr hatî, Lîstikvan!'))
            .flagsCollection
            .isHeader,
        isTrue,
      );
      expect(find.bySemanticsLabel('ZanKurd'), findsOneWidget);
      expect(find.bySemanticsLabel('120 zêr'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('$name: B açılan sayfa 320 @2.0 taşmaz, geri 44', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      var back = 0;
      await pumpSahne(
        tester,
        SahnePushedPage(
          title: 'Kurmancî hîn bibe',
          subtitle: 'Ders bi ders, mijar bi mijar',
          onBack: () => back++,
          backLabel: 'Vegere',
          bottom: const SahneButton.primary(
            label: 'Bidomîne',
            onPressed: noop,
            expand: true,
          ),
          children: const [
            SahneListGroup(
              children: [
                SahneListRow.icon(
                  icon: AppIcons.book,
                  title: 'Silavdayîn',
                  chevron: true,
                  onTap: noop,
                ),
              ],
            ),
          ],
        ),
        dark: dark,
        page: true,
      );
      expect(tester.takeException(), isNull);
      final button = find.byType(SahneIconButton);
      expect(tester.getSize(button), const Size(48, 48));
      expect(
        tester.getSize(
          find.descendant(of: button, matching: find.byType(SahneTappable)),
        ),
        const Size(44, 44),
      );
      expect(find.bySemanticsLabel('Vegere'), findsOneWidget);
      await tester.tap(button);
      expect(back, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    testWidgets('$name: C oyun sahnesi hep gece, sayaç ortada, taşmaz', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const SahneStageScaffold(
          onClose: noop,
          closeLabel: 'Bigire',
          backdrop: AssetImage('assets/question_images/cat_ziman.webp'),
          center: SahneTimerDiamond(
            key: Key('timer'),
            secondsLeft: 4,
            fraction: 0.2,
            semanticLabel: '4 çirke mane',
          ),
          score: SahneStatChip(
            leading: SahneGlyph(SahneGlyphKind.star),
            label: '1240',
            semanticLabel: '1240 xal',
          ),
          progress: SahneDiamondRow(
            states: [SahneDiamondState.correct, SahneDiamondState.pending],
            currentIndex: 1,
            semanticLabel: '2/10',
          ),
          body: SahneStageBody(
            children: [
              Text(
                'Kîjan hevok qaîdeya ergatîfê ya di navbera lêkerên '
                'gerguhêz û negerguhêz de bi awayekî rast nîşan dide?',
              ),
            ],
          ),
          dock: SahneJokerBar(
            jokers: [
              SahneJokerButton(
                icon: AppIcons.circle,
                label: 'Nîv bi Nîv',
                price: 20,
                onPressed: noop,
              ),
              SahneJokerButton(
                icon: AppIcons.lightbulb,
                label: 'Alîkarî',
                price: 30,
                onPressed: noop,
              ),
            ],
          ),
        ),
        dark: dark,
        page: true,
      );
      expect(tester.takeException(), isNull);

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, SahneTokens.night.bg);

      final timer = tester.getCenter(find.byKey(const Key('timer')));
      expect(timer.dx, closeTo(kNarrow.width / 2, 0.5));

      expect(find.bySemanticsLabel('Bigire'), findsOneWidget);
      expect(find.bySemanticsLabel('4 çirke mane'), findsOneWidget);
      final close = find.byType(SahneIconButton);
      expect(tester.getSize(close), const Size(48, 48));
      expect(
        tester.getSize(
          find.descendant(of: close, matching: find.byType(SahneTappable)),
        ),
        const Size(44, 44),
      );
      // Kapat plakasının görsel kenarı sayfa kenarına (16) oturur.
      expect(
        tester
            .getTopLeft(
              find.descendant(of: close, matching: find.byType(SahneTappable)),
            )
            .dx,
        16,
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });

    // 2026-09-29 Şahnê (soru grubu aşısı): kategori ışığı ve dağ sırtı.
    // Işık yalnız huzmeyi boyar (yoğunluk varsayılanla aynı, %12); sırt
    // gövdenin dibinde (alt perdenin üstünde), Perde'nin %40'ı. İkisi de
    // istenmezse sahne eskisi gibi çizilir — öteki C ekranları etkilenmez.
    testWidgets('$name: C kategori ışığı huzmeyi boyar, sırt ufukta durur', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneStageScaffold(
          onClose: noop,
          light: SahneCategoryLight.ziman,
          ridge: true,
          body: SahneStageBody(children: [Text('Pirs')]),
        ),
        dark: dark,
        page: true,
      );
      expect(tester.takeException(), isNull);

      final beam = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('sahne-stage-beam')),
      );
      final painter = beam.painter! as SahneBeamPainter;
      expect(painter.light, SahneCategoryLight.ziman);
      expect(painter.color.a, closeTo(SahneStageColors.beam.a, 0.001));
      expect(painter.color.r, closeTo(SahneCategoryLight.ziman.r, 0.001));

      final ridge = find.byKey(const ValueKey('sahne-stage-ridge'));
      expect(ridge, findsOneWidget);
      final rect = tester.getRect(ridge);
      // Alt perde yokken gövde ekranın dibine iner; sırt da oradadır.
      expect(rect.bottom, kNarrow.height);
      expect(rect.height, SahneStageScaffold.ridgeHeight);
      expect(rect.width, kNarrow.width);
      final ridgePainter =
          tester.widget<CustomPaint>(ridge).painter! as SahneRidgePainter;
      expect(ridgePainter.color, SahneTokens.night.s1.withValues(alpha: 0.4));
    });

    testWidgets('$name: C ışık ve sırt istenmezse varsayılan sahne', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneStageScaffold(
          onClose: noop,
          body: SahneStageBody(children: [Text('Pirs')]),
        ),
        dark: dark,
        page: true,
      );
      final beam = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('sahne-stage-beam')),
      );
      expect((beam.painter! as SahneBeamPainter).color, SahneStageColors.beam);
      expect(find.byKey(const ValueKey('sahne-stage-ridge')), findsNothing);
    });
  }

  test('kategori ışığı bilinmeyen kategoride varsayılan huzmeye düşer', () {
    expect(SahneCategoryLight.of('Ziman'), SahneCategoryLight.ziman);
    expect(SahneCategoryLight.of('Sînema'), SahneCategoryLight.sinema);
    expect(SahneCategoryLight.of('Siyaset'), isNull);
    expect(SahneCategoryLight.beamOf(null), SahneStageColors.beam);
  });
}
