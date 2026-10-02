/// Şahnê çip, ray, rozet ve bölüm başlığının bekçisi.
///
/// ## Neyi korur
///
/// * Stat çipi GÖRSEL olarak 36'dır ama dokunulabilirse 48'lik alan alır
///   (spec `touchTargets`). Eski çipler 32'lik görseli dokunma alanı
///   sanıyordu; parmak kenara düşünce mağazaya gidilmiyordu.
/// * Seçim rayı çipi görselde 44, dokunmada 48; seçili durumu ekran
///   okuyucuya söylenir.
/// * Rozet büyük harfi yerele duyarlıdır (Türkçe "i" → "İ"); dolu kırmızı
///   rozet yok, ton + rol metni.
/// * Durum rozeti sözü de okur: durum hiçbir zaman yalnız renkle verilmez.
/// * Bölüm başlığı TEK stildir ve başlık olarak duyurulur.
/// * 320 px @2.0'da hiçbiri taşmaz.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Widget all() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SahneSectionHeader(
        title: 'Arkadaşlarınla',
        actionLabel: 'Tümü',
        onAction: noop,
        actionSemanticLabel: 'Arkadaş etkinliklerinin tümü',
      ),
      const SahneSectionHeader(title: 'Bu turdan öğrendiklerin'),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SahneStatChip(
            key: Key('coin'),
            leading: SahneGlyph(SahneGlyphKind.coin),
            label: '120',
            semanticLabel: '120 jeton',
            onTap: noop,
          ),
          SahneStatChip(
            key: Key('streak'),
            leading: SahneGlyph(SahneGlyphKind.flame),
            label: '3 roj',
            semanticLabel: '3 rojên li pey hev',
          ),
          SahneStatChip(
            leading: SahneGlyph(SahneGlyphKind.bolt),
            label: '+200 XP',
            gold: true,
          ),
        ],
      ),
      const SizedBox(height: 12),
      SahneRail(
        children: [
          for (final (i, l) in const ['Rojane', 'Rêziman', 'Çand'].indexed)
            SahneRailChip(label: l, selected: i == 0, onTap: noop),
        ],
      ),
      const SizedBox(height: 12),
      SahneRail.fit(
        children: [
          for (final (i, l) in const ['Roj', 'Hefte', 'Meh', 'Heval'].indexed)
            SahneRailChip(
              label: l,
              selected: i == 1,
              role: SahneRole.gold,
              onTap: noop,
            ),
        ],
      ),
      const SizedBox(height: 12),
      const Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SahneBadge(label: 'Bugün', tone: SahneBadgeTone.race),
          SahneBadge(label: 'Sana önerilen'),
          SahneBadge(label: 'En iyi', tone: SahneBadgeTone.gold),
          SahneBadge(label: 'Yakında', tone: SahneBadgeTone.soon),
          SahneStatusBadge(correct: true, label: 'Rast'),
          SahneStatusBadge(correct: false, label: 'Şaş'),
          SahneStatusBadge.square(correct: true, label: 'Doğru'),
          SahneStatusBadge.square(correct: false, label: 'Yanlış'),
        ],
      ),
    ],
  );

  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: 320 px @2.0 taşmaz; etiket ve dokunma alanları', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(tester, all(), dark: dark);
      expect(tester.takeException(), isNull);

      expect(find.bySemanticsLabel('120 jeton'), findsOneWidget);
      expect(find.bySemanticsLabel('Rast'), findsOneWidget);
      expect(find.bySemanticsLabel('Şaş'), findsOneWidget);
      expect(find.bySemanticsLabel('Yanlış'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Arkadaş etkinliklerinin tümü'),
        findsOneWidget,
      );
      final header = tester.getSemantics(find.text('Arkadaşlarınla'));
      expect(header.flagsCollection.isHeader, isTrue);

      final selected = tester.getSemantics(find.text('Rojane'));
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      for (final e in find.byType(SahneRailChip).evaluate()) {
        expect(
          tester.getSize(find.byWidget(e.widget)).height,
          greaterThanOrEqualTo(44),
        );
      }
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('stat çipi: görsel 36, dokunulabilirse alan 48', (tester) async {
    var taps = 0;
    await pumpSahne(
      tester,
      Row(
        children: [
          SahneStatChip(
            key: const Key('coin'),
            leading: const SahneGlyph(SahneGlyphKind.coin),
            label: '120',
            onTap: () => taps++,
          ),
          const SahneStatChip(
            key: Key('streak'),
            leading: SahneGlyph(SahneGlyphKind.flame),
            label: '3 gün',
          ),
        ],
      ),
      dark: true,
      textScale: 1,
    );
    expect(tester.getSize(find.byKey(const Key('coin'))).height, 48);
    expect(tester.getSize(find.byKey(const Key('streak'))).height, 36);
    final visual = find.descendant(
      of: find.byKey(const Key('coin')),
      matching: find.byType(Material),
    );
    expect(tester.getSize(visual.first).height, 36);
    // Görselin 4 px dışına (alanın kenarına) dokunmak da sayılır.
    final box = tester.getRect(find.byKey(const Key('coin')));
    await tester.tapAt(Offset(box.center.dx, box.top + 2));
    expect(taps, 1);
  });

  // 2026-09-29 doğallık: bu bekçi eskiden rozetin büyük harfe (Türkçe
  // i → İ) çevrildiğini ölçüyordu. K8: rozet açıklama kalını, cümle düzeni;
  // büyük harf + harf aralığı yalnız soru ekranının künyesinde. Yerele
  // duyarlı büyütme `SahneType.upperFor` bekçisinde korunur.
  testWidgets('rozet metni verildiği gibi, açıklama kalını', (tester) async {
    await pumpSahne(
      tester,
      const SahneBadge(label: 'En iyi'),
      dark: false,
      textScale: 1,
    );
    final text = tester.widget<Text>(find.text('En iyi'));
    expect(text.style?.fontSize, SahneType.captionStrong.fontSize);
    expect(text.style?.fontWeight, FontWeight.w700);
    expect(text.style?.letterSpacing ?? 0, 0);
    expect(find.text('EN İYİ'), findsNothing);
  });

  test('yerele duyarlı büyük harf: Türkçede i → İ', () {
    expect(SahneType.upperFor('En iyi', isKu: false), 'EN İYİ');
    expect(SahneType.upperFor('Pirs', isKu: true), 'PIRS');
  });

  testWidgets('bölüm başlığı: üstü 24, altı 12 görünür boşluk', (tester) async {
    await pumpSahne(
      tester,
      const Column(
        children: [
          SizedBox(key: Key('above'), height: 10),
          SahneSectionHeader(title: 'Konular'),
          SizedBox(key: Key('below'), height: 10),
        ],
      ),
      dark: true,
      textScale: 1,
    );
    final above = tester.getBottomLeft(find.byKey(const Key('above'))).dy;
    final below = tester.getTopLeft(find.byKey(const Key('below'))).dy;
    final title = tester.getRect(find.text('Konular'));
    expect(title.top - above, SahneSpace.sectionTop);
    expect(below - title.bottom, SahneSpace.sectionBottom);
  });
}
