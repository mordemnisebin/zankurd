/// Şahnê birleştirme turunun (2026-09-29) bileşen bekçileri.
///
/// ## Neyi korur
///
/// Altı ekran grubu Şahnê'ye taşınırken bileşenlerde eksik buldu ve her
/// grup kendi ekranında geçici bir sarmalayıcı yazdı (`BarIconAction`,
/// `_TextAction`, `_QuizToolButton`, `_BlankBadge`, `_PushedBar` …). Bu
/// sarmalayıcılar kalktı; işi artık bileşen yapıyor. Buradaki testler o
/// işin bileşende kaldığını denetler:
///
/// * Dokunulabilen her bileşen 48'lik dokunma kutusu verir, görsel boyu
///   değişmez (ikon düğmesi 44, metin düğmesi 44, stat çipi 36, ray çipi
///   44). Android kılavuzu (`androidTapTargetGuideline`) 48'in altını
///   reddeder.
/// * Açılan sayfanın ve oyun sahnesinin alt perdesi gövdenin DIŞINDADIR:
///   SnackBar onun üstünde açılır, birincil düğmeyi örtmez.
/// * Başlıklar büyük yazıda sarar, tek bir sözü harf harf bölmez.
/// * Liste satırının serbest öncülü, yıkıcı tonu, avatar yuvası ve çizimsiz
///   kategori geri düşüşü; durum rozetinin nötr "boş" hâli; joker ve ikon
///   düğmesinin seçili hâlleri; sayaç halesinin kategori ışığı.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

Size _visual(WidgetTester tester, Finder of) => tester.getSize(
  find.descendant(of: of, matching: find.byType(SahneTappable)).first,
);

void main() {
  setUpAll(loadAppFonts);

  group('48 dokunma kutusu, görsel boy aynı', () {
    for (final MapEntry(key: name, value: dark) in kThemes.entries) {
      testWidgets('$name: ikon, metin, stat ve ray çipi', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSahne(
          tester,
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SahneIconButton(
                key: Key('icon'),
                icon: AppIcons.bookmark,
                semanticLabel: 'Tomar bike',
                onPressed: noop,
              ),
              SahneButton.text(
                key: Key('text'),
                label: 'Hemû',
                onPressed: noop,
              ),
              SahneStatChip(
                key: Key('chip'),
                leading: SahneGlyph(SahneGlyphKind.coin),
                label: '120',
                onTap: noop,
              ),
              SahneRailChip(
                key: Key('rail'),
                label: 'A',
                selected: false,
                onTap: noop,
              ),
            ],
          ),
          dark: dark,
          textScale: 1,
        );
        final icon = find.byKey(const Key('icon'));
        expect(tester.getSize(icon), const Size(48, 48));
        expect(_visual(tester, icon), const Size(44, 44));

        final text = find.byKey(const Key('text'));
        expect(tester.getSize(text).height, greaterThanOrEqualTo(48));
        final textVisual = find.descendant(
          of: text,
          matching: find.byType(Material),
        );
        expect(tester.getSize(textVisual.first).height, 44);

        final chip = find.byKey(const Key('chip'));
        expect(tester.getSize(chip).height, 48);

        final rail = find.byKey(const Key('rail'));
        expect(tester.getSize(rail), const Size(48, 48));
        expect(_visual(tester, rail), const Size(44, 44));

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('ikon düğmesinin 2 px dokunma payına basmak da sayılır', (
      tester,
    ) async {
      var taps = 0;
      await pumpSahne(
        tester,
        Align(
          alignment: Alignment.topLeft,
          child: SahneIconButton(
            key: const Key('icon'),
            icon: AppIcons.xmark,
            semanticLabel: 'Bigire',
            onPressed: () => taps++,
          ),
        ),
        dark: true,
        textScale: 1,
      );
      final box = tester.getRect(find.byKey(const Key('icon')));
      await tester.tapAt(box.topLeft + const Offset(1, 1));
      expect(taps, 1);
    });
  });

  testWidgets(
    'ikon düğmesi: seçili (kaydedildi) hâli Zêr ve seçili duyurulur',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const SahneIconButton(
          key: Key('save'),
          icon: AppIcons.bookmark,
          semanticLabel: 'Rake',
          selected: true,
          onPressed: noop,
        ),
        dark: true,
        textScale: 1,
      );
      const t = SahneTokens.night;
      final material = tester.widget<Material>(
        find.descendant(
          of: find.byKey(const Key('save')),
          matching: find.byType(Material),
        ),
      );
      expect(material.color, t.goldTint);
      final icon = tester.widget<Icon>(find.byIcon(AppIcons.bookmark));
      expect(icon.color, t.goldTx);
      expect(
        tester
            .getSemantics(find.byKey(const Key('save')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    },
  );

  group('SahneButton', () {
    testWidgets('buttonKey içteki Material düğmesine gider', (tester) async {
      await pumpSahne(
        tester,
        const Column(
          children: [
            SahneButton.primary(
              buttonKey: Key('p'),
              label: 'Dest pê bike',
              onPressed: noop,
            ),
            SahneButton.text(
              buttonKey: Key('t'),
              label: 'Hemû',
              onPressed: noop,
            ),
          ],
        ),
        dark: true,
        textScale: 1,
      );
      expect(tester.widget(find.byKey(const Key('p'))), isA<FilledButton>());
      expect(tester.widget(find.byKey(const Key('t'))), isA<TextButton>());
    });

    testWidgets('yükleniyor: gösterge çizer, dokunuşu yok sayar, pasifleşmez', (
      tester,
    ) async {
      var taps = 0;
      await pumpSahne(
        tester,
        SahneButton.primary(
          key: const Key('b'),
          label: 'Hevrik bibîne',
          loading: true,
          expand: true,
          onPressed: () => taps++,
        ),
        dark: true,
        textScale: 1,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Hevrik bibîne'), findsNothing);
      await tester.tap(find.byKey(const Key('b')));
      expect(taps, 0);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('b')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.color, SahneTokens.night.act, reason: 'pasifleşmez');
    });

    testWidgets('öncül olarak jeton glifi alır; ikincil gölgesizdir', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneButton.secondary(
          key: Key('buy'),
          label: '120j',
          leading: SahneGlyph(SahneGlyphKind.coin),
          onPressed: noop,
        ),
        dark: false,
        textScale: 1,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('buy')),
          matching: find.byType(SahneGlyph),
        ),
        findsOneWidget,
      );
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byKey(const Key('buy')),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(material.elevation, 0);
    });
  });

  group('alt perde gövdenin dışında', () {
    Future<void> showSnack(WidgetTester tester) async {
      final context = tester.element(find.text('Bidomîne'));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Peyam')));
      await tester.pumpAndSettle();
    }

    testWidgets('B: SnackBar birincil düğmenin üstünde açılır', (tester) async {
      await pumpSahne(
        tester,
        const SahnePushedPage(
          title: 'Mağaza',
          bottom: SahneButton.primary(
            label: 'Bidomîne',
            onPressed: noop,
            expand: true,
          ),
        ),
        dark: true,
        textScale: 1,
        page: true,
      );
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.bottomNavigationBar, isA<SahneBottomDock>());
      await showSnack(tester);
      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Bidomîne')).top),
      );
    });

    testWidgets('C: SnackBar alt perdenin üstünde, içerik perdede biter', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneStageScaffold(
          closeKey: Key('close'),
          body: SizedBox.expand(key: Key('body')),
          dock: SahneButton.primary(
            label: 'Bidomîne',
            onPressed: noop,
            expand: true,
          ),
        ),
        dark: false,
        textScale: 1,
        page: true,
      );
      expect(find.byKey(const Key('close')), findsOneWidget);
      final body = tester.getRect(find.byKey(const Key('body')));
      final dockTop = tester.getRect(find.byType(SahneBottomDock)).top;
      expect(body.bottom, lessThanOrEqualTo(dockTop + 0.5));
      await showSnack(tester);
      expect(
        tester.getRect(find.byType(SnackBar)).bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Bidomîne')).top),
      );
    });
  });

  group('başlık sözü harf harf bölünmez', () {
    for (final title in ['Arkadaşlarım', 'Destkeftiyên min']) {
      testWidgets('B çubuğu 320 @2.0: "$title"', (tester) async {
        await pumpSahne(
          tester,
          SahnePushedPage(
            title: title,
            actions: const [
              SahneIconButton(
                icon: AppIcons.arrowsRotate,
                semanticLabel: 'Nû bike',
                onPressed: noop,
              ),
            ],
          ),
          dark: true,
          page: true,
        );
        expect(tester.takeException(), isNull);
        final paragraph = tester.renderObject<RenderParagraph>(
          find.text(title),
        );
        final words = title.split(' ').length;
        final lines = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: title.length),
            )
            .map((b) => b.top)
            .toSet()
            .length;
        expect(
          lines,
          lessThanOrEqualTo(words),
          reason: 'her satır en az bir bütün söz taşır',
        );
      });
    }

    testWidgets('bölüm başlığı uzun Kurmancî söz 320 @2.0', (tester) async {
      await pumpSahne(
        tester,
        const SahneSectionHeader(
          title: 'Destkeftiyên',
          actionLabel: 'Hemû',
          onAction: noop,
        ),
        dark: true,
      );
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('Destkeftiyên'),
      );
      expect(paragraph.didExceedMaxLines, isFalse);
      final boxes = paragraph.getBoxesForSelection(
        const TextSelection(baseOffset: 0, extentOffset: 12),
      );
      expect(boxes.map((b) => b.top).toSet(), hasLength(1));
    });
  });

  testWidgets('A: stat çipleri alt satıra inince de SAĞA yaslı', (
    tester,
  ) async {
    await pumpSahne(
      tester,
      const SahneTabPage(
        title: 'Hîn bibe',
        stats: [
          SahneStatChip(
            key: Key('streak'),
            leading: SahneGlyph(SahneGlyphKind.flame),
            label: '12 roj',
          ),
          SahneStatChip(
            key: Key('coin'),
            leading: SahneGlyph(SahneGlyphKind.coin),
            label: '1240',
          ),
        ],
      ),
      dark: true,
      page: true,
    );
    expect(tester.takeException(), isNull);
    final brand = tester.getRect(find.bySemanticsLabel('ZanKurd'));
    final coin = tester.getRect(find.byKey(const Key('coin')));
    expect(coin.top, greaterThanOrEqualTo(brand.bottom), reason: 'alt satır');
    expect(coin.right, closeTo(kNarrow.width - SahneSpace.page, 0.5));
  });

  testWidgets('sığan ray büyük yazıda iki sütuna geçer', (tester) async {
    await pumpSahne(
      tester,
      const SahneRail.fit(
        children: [
          SahneRailChip(label: 'Roj', selected: true, onTap: noop),
          SahneRailChip(label: 'Hefte', selected: false, onTap: noop),
          SahneRailChip(label: 'Meh', selected: false, onTap: noop),
          SahneRailChip(label: 'Heval', selected: false, onTap: noop),
        ],
      ),
      dark: true,
    );
    expect(tester.takeException(), isNull);
    final roj = tester.getRect(find.bySemanticsLabel('Roj'));
    final meh = tester.getRect(find.bySemanticsLabel('Meh'));
    expect(meh.top, greaterThan(roj.bottom - 1), reason: 'ikinci satır');
    // İki sütunda çip, dört sütundakinin kabaca iki katı genişlikte.
    expect(roj.width, greaterThan((kNarrow.width - 32) / 2 - 8));
  });

  testWidgets('ray çipi Perde kartın içinde Kulis tonuna yükselir', (
    tester,
  ) async {
    await pumpSahne(
      tester,
      const Column(
        children: [
          SahneRailChip(
            key: Key('out'),
            label: 'A',
            selected: false,
            onTap: noop,
          ),
          SahneSurfaceCard(
            child: SahneRailChip(
              key: Key('in'),
              label: 'B',
              selected: false,
              onTap: noop,
            ),
          ),
        ],
      ),
      dark: true,
      textScale: 1,
    );
    Color fill(String key) => tester
        .widget<Material>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Material),
          ),
        )
        .color!;
    expect(fill('out'), SahneTokens.night.s1);
    expect(fill('in'), SahneTokens.night.s2);
  });

  group('liste satırı', () {
    testWidgets('serbest öncül, yıkıcı ton, avatar yuvası, çizimsiz küçük', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneListGroup(
          children: [
            SahneListRow.leading(
              key: Key('lead'),
              leading: SizedBox.square(key: Key('avatar'), dimension: 40),
              leadingWidth: 40,
              title: 'Bawer',
            ),
            SahneListRow.icon(
              key: Key('danger'),
              icon: AppIcons.trashCan,
              title: 'Hesabê jê bibe',
              destructive: true,
              onTap: noop,
            ),
            SahneListRow.rank(
              key: Key('rank'),
              rank: 2,
              title: 'Zana',
              avatar: SizedBox.square(key: Key('own'), dimension: 30),
            ),
            SahneListRow.thumb(
              key: Key('thumb'),
              image: null,
              icon: AppIcons.clapperboard,
              title: 'Sînema',
            ),
          ],
        ),
        dark: true,
        textScale: 1,
      );
      expect(find.byKey(const Key('avatar')), findsOneWidget);
      expect(
        (find.byKey(const Key('lead')).evaluate().single.widget as SahneListRow)
            .dividerIndent,
        SahneSpace.x3 + 40 + SahneSpace.x3,
      );
      final danger = tester.widget<Text>(find.text('Hesabê jê bibe'));
      expect(danger.style?.color, SahneTokens.night.errTx);
      expect(find.byKey(const Key('own')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('rank')),
          matching: find.byType(SahneDiamondAvatar),
        ),
        findsNothing,
      );
      final noArt = find.descendant(
        of: find.byKey(const Key('thumb')),
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SahneNoArtPainter,
        ),
      );
      expect(noArt, findsOneWidget);
      expect(tester.getSize(noArt), const Size(36, 36));
    });

    testWidgets('durum rozeti: nötr "boş" hâli ✓/✗ değil kum saati', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneStatusBadge.blank(label: 'Vala ma'),
        dark: false,
        textScale: 1,
      );
      expect(find.byIcon(AppIcons.hourglass), findsOneWidget);
      expect(find.byIcon(AppIcons.check), findsNothing);
      expect(find.byIcon(AppIcons.xmark), findsNothing);
      expect(
        tester.widget<Text>(find.text('Vala ma')).style?.color,
        SahneTokens.day.tx2,
      );
    });
  });

  testWidgets('mücevher karo: ada basmak da açar; meta yuvası okunur', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpSahne(
      tester,
      SahneJewelTile(
        name: 'Sînema',
        otherName: 'Sinema',
        onTap: () => taps++,
        meta: const Text('245 pirs', key: Key('meta')),
        metaLabel: '245 pirs',
      ),
      dark: true,
      textScale: 1,
    );
    await tester.tap(find.text('Sînema'));
    await tester.tap(find.byKey(const Key('meta')));
    expect(taps, 2);
    expect(find.bySemanticsLabel('Sînema, Sinema, 245 pirs'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('sahne kartı: düğme anahtarı, tek ekran okuyucu düğümü', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpSahne(
      tester,
      SahneStageCard.duel(
        title: 'Hevrikekî di asta te de',
        meta: '~2 deqe',
        actionLabel: 'Hevrik bibîne',
        actionKey: const Key('cta'),
        semanticLabel: 'Pêşbirka bilez',
        emblem: const SahneVsEmblem(),
        onAction: () => taps++,
      ),
      dark: false,
    );
    expect(tester.takeException(), isNull);
    expect(tester.widget(find.byKey(const Key('cta'))), isA<FilledButton>());
    expect(
      find.bySemanticsLabel('Pêşbirka bilez. Hevrik bibîne'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('cta')));
    expect(taps, 1);
    semantics.dispose();
  });

  group('joker', () {
    testWidgets('seçili: Zêr halka + ✓, fiyat yok', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const SahneJokerButton(
          key: Key('j'),
          icon: AppIcons.clone,
          label: 'Du bersiv',
          price: 30,
          selected: true,
          onPressed: noop,
        ),
        dark: true,
        textScale: 1,
      );
      expect(find.byIcon(AppIcons.check), findsOneWidget);
      expect(find.text('30'), findsNothing);
      expect(
        tester
            .getSemantics(find.byKey(const Key('j')))
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
      semantics.dispose();
    });

    testWidgets('jeton yetmiyor: pasif ama fiyat görünür', (tester) async {
      var taps = 0;
      await pumpSahne(
        tester,
        SahneJokerButton(
          key: const Key('j'),
          icon: AppIcons.clone,
          label: 'Du bersiv',
          price: 30,
          unaffordable: true,
          onPressed: () => taps++,
        ),
        dark: true,
        textScale: 1,
      );
      expect(find.text('30'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('30')).style?.color,
        SahneTokens.night.tx3,
      );
      await tester.tap(find.byKey(const Key('j')));
      expect(taps, 0);
    });
  });

  test('sayaç halesi kategori ışığını altın yoğunluğunda taşır', () {
    final halo = SahneTimerDiamond.haloColor(
      hot: false,
      light: SahneCategoryLight.ziman,
    );
    expect(halo.a, closeTo(SahneStageColors.haloGold.a, 0.001));
    expect(halo.withValues(alpha: 1), SahneCategoryLight.ziman);
    expect(
      SahneTimerDiamond.haloColor(hot: true, light: SahneCategoryLight.ziman),
      SahneStageColors.haloRace,
      reason: 'gerilimde hale her zaman Boyax',
    );
    expect(SahneTimerDiamond.haloColor(hot: false), SahneStageColors.haloGold);
  });

  test('sonuç sırtı soru sahnesinin sırtıyla aynı siluet', () {
    const box = Rect.fromLTWH(0, 0, 100, 64);
    final ridge = SahneRidgePainter.ridgePath(box);
    final floored = SahneRidgePainter.ridgePath(box, floor: 12);
    // Tepe (0.50, 0.00) iki yolda da aynı yerde; taban 12 aşağıda.
    expect(ridge.getBounds().top, 0);
    expect(floored.getBounds().top, 0);
    expect(floored.getBounds().bottom, ridge.getBounds().bottom + 12);
  });
}
