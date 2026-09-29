/// Şahnê kartlarının bekçisi: sahne kartı, yüzey kartı, liste grubu,
/// mücevher karo.
///
/// ## Neyi korur
///
/// * Sahne kartı gündüz temasında da GECE çizilir. Eski uygulamada bu
///   kural 72 ayrı `isDark` dalıyla taklit ediliyordu ve her yeni kartta
///   unutuluyordu; burada kart kendi içini `AppTheme.stage` ile sarar ve
///   test, gündüzde içerideki metnin gece renginde olduğunu ölçer.
/// * Çizimsiz kategori (Sinema) görsel yokken de — ya da görsel
///   yüklenemezse — boş kutu değil kobalt + kilim çerçeve çizer.
/// * Liste grubunun ayırıcısı ikon hizasından başlar (satır türüne göre).
/// * 320 px @2.0'da hiçbiri taşmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../support/realistic_device.dart';
import 'sahne_harness.dart';

void main() {
  setUpAll(loadAppFonts);

  Widget stageCards() => const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SahneStageCard.lesson(
        eyebrow: 'Dersê rojane',
        title: 'Silavdayîn û nasîn',
        meta: '5 pirs • nêzîkî 3 deqe',
        done: 2,
        total: 5,
        actionLabel: 'Bidomîne',
        onAction: noop,
      ),
      SizedBox(height: 12),
      SahneStageCard.lesson(
        tag: SahneBadge(label: 'Sana önerilen'),
        title: 'Selamlaşma',
        done: 0,
        total: 5,
        actionLabel: 'Başla',
        onAction: noop,
      ),
      SizedBox(height: 12),
      SahneStageCard.duel(
        eyebrow: 'Hızlı düello',
        title: 'Seviyene yakın rakip',
        meta: '~2 dakika',
        emblem: SahneVsEmblem(),
        actionLabel: 'Rakip bul',
        onAction: noop,
      ),
      SizedBox(height: 12),
      SahneStageCard.mini(
        eyebrow: 'Sahne kartı',
        title: 'Günün dersi',
        meta: 'Kahraman içerik; gündüzde de gece kalır.',
      ),
      SizedBox(height: 12),
      SahneStageCard(role: SahneRole.gold, child: Text('Serbest içerik')),
    ],
  );

  for (final MapEntry(key: name, value: dark) in kThemes.entries) {
    testWidgets('$name: sahne kartları 320 @2.0 taşmaz, içleri gece', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(tester, stageCards(), dark: dark);
      expect(tester.takeException(), isNull);

      // Gündüzde de başlık gece birincil metin renginde.
      final title = tester.widget<Text>(find.text('Selamlaşma'));
      expect(title.style?.color, SahneTokens.night.tx);
      final ctx = tester.element(find.text('Selamlaşma'));
      expect(SahneTokens.of(ctx), SahneTokens.night);

      // Kilim şeridi her kartta; dekoratif, ekran okuyucuya görünmez.
      expect(find.byType(SahneKilimStrip), findsNWidgets(5));
      expect(find.bySemanticsLabel('2/5'), findsOneWidget);
      // Üst etiket yerele duyarlı büyür (Türkçe i → İ).
      expect(find.text('HIZLI DÜELLO'), findsOneWidget);
      expect(find.text('SANA ÖNERİLEN'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('$name: yüzey kartı ve liste grubu taşmaz', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const Column(
          children: [
            SahneSurfaceCard(
              onTap: noop,
              semanticLabel: 'Ödül kartı',
              child: Text('Seviye 1 · 200 / 1000 XP'),
            ),
            SizedBox(height: 12),
            SahneListGroup(
              children: [
                SahneListRow.icon(
                  icon: AppIcons.peopleGroup,
                  role: SahneRole.race,
                  title: 'Odeyekê ava bike',
                  subtitle: 'Hevalên xwe bi kodê vexwîne',
                  chevron: true,
                  onTap: noop,
                ),
                SahneListRow.icon(
                  icon: AppIcons.hashtag,
                  role: SahneRole.race,
                  title: 'Bi kodê tevlî bibe',
                  chevron: true,
                  onTap: noop,
                ),
              ],
            ),
          ],
        ),
        dark: dark,
      );
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('Ödül kartı')), findsOneWidget);
      final surface = tester.getSize(find.byType(SahneSurfaceCard));
      expect(surface.height, greaterThanOrEqualTo(44));
      semantics.dispose();
    });

    testWidgets('$name: mücevher karolar — çizimli, ustalık, çizimsiz', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SahneJewelTile(name: 'Sinema', otherName: 'Sînema', onTap: noop),
            SahneJewelTile(
              name: 'Kültür',
              otherName: 'Çand',
              image: AssetImage('assets/question_images/yok_boyle_bir.webp'),
              mastered: true,
              masteredLabel: 'Ustalık',
              onTap: noop,
            ),
          ],
        ),
        dark: dark,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Görsel yok → çizimsiz ressam; yüklenemeyen görsel de ona düşer.
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SahneNoArtPainter,
        ),
        findsAtLeastNWidgets(1),
      );
      for (final e in find.byType(SahneJewelTile).evaluate()) {
        final size = tester.getSize(find.byWidget(e.widget));
        expect(size.width, 128);
        expect(size.height, greaterThanOrEqualTo(128));
      }
      expect(find.bySemanticsLabel('Sinema, Sînema'), findsOneWidget);
      expect(find.bySemanticsLabel('Kültür, Çand, Ustalık'), findsOneWidget);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      semantics.dispose();
    });
  }

  testWidgets('çizimsiz karo: görsel hiç verilmese de çizilir', (tester) async {
    await pumpSahne(
      tester,
      const SahneJewelTile(name: 'Teknoloji', icon: AppIcons.robot),
      dark: true,
      textScale: 1,
    );
    expect(tester.takeException(), isNull);
    expect(find.byIcon(AppIcons.robot), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SahneNoArtPainter,
      ),
      findsOneWidget,
    );
  });

  testWidgets('liste grubu ayırıcısı satır türünün öncül hizasından başlar', (
    tester,
  ) async {
    await pumpSahne(
      tester,
      const SahneListGroup(
        children: [
          SahneListRow.icon(icon: AppIcons.user, title: 'A'),
          SahneListRow.icon(icon: AppIcons.user, title: 'B'),
          SahneListRow.rank(rank: 4, initial: 'C', title: 'C'),
        ],
      ),
      dark: false,
      textScale: 1,
    );
    final groupLeft = tester.getTopLeft(find.byType(SahneListGroup)).dx;
    final dividers = find.byWidgetPredicate(
      (w) => w is SizedBox && w.height == 1,
    );
    expect(dividers, findsNWidgets(2));
    final lefts = [
      for (final e in dividers.evaluate())
        tester.getTopLeft(find.byWidget(e.widget)).dx - groupLeft,
    ];
    // Standart satır: 12 + 44 + 12; sıra satırı: 12 + 24 + 12.
    expect(lefts, [68, 48]);
  });
}
