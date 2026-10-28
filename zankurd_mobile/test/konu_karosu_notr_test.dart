// 2026-10-28 kurul K1: konu karosu nötr yüzey + renkli rozet.
//
// Kusur: on bir doygun dolu karo yan yana ekranı bağırtıyordu ve büyük silik
// filigran adın üstüne biniyordu. Karar: karo standart kart (açık temada
// beyaz, koyu temada grafit `s1`); konu rengi YALNIZ 40 px'lik ikon
// rozetinde ve 4 px'lik başlangıç şeridinde; ad normal metin rengi; ikinci
// dil yalnız "iki dilli etiketler" açıksa küçük soluk satır. Konu→renk
// eşlemesi [SahneCategoryTone]'dan gelir ve eşleşme listesindeki satırla
// ([CategoryIconTile]) aynıdır. Bu bekçi karoyu ölçer; yoksa biri karoyu
// yeniden doldurabilirdi ve hiçbir test fark etmezdi (eski "DOLU karo"
// bekçisi tersini şart koşuyordu; güncellendi).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/bilingual_labels_provider.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/category_band.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

const _cats = ['Ziman', 'Çand', 'Dîrok', 'Edebiyat', 'Cografya', 'Cîhan'];

Widget _grid({required bool dark, required bool bilingual}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider(
      create: (_) => BilingualLabelsProvider(initialEnabled: bilingual),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: HomeTopicGrid(
          isKu: false,
          categories: _cats,
          progress: const {},
          onOpen: (_) {},
        ),
      ),
    ),
  ),
);

void main() {
  for (final dark in [false, true]) {
    testWidgets('karo nötr yüzey; renk yalnız rozet ve şeritte '
        '(${dark ? "gece" : "gündüz"})', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_grid(dark: dark, bilingual: false));
      await tester.pumpAndSettle();
      final t = SahneTokens.of(tester.element(find.byType(HomeTopicGrid)));
      for (final c in _cats) {
        final tile = find.byKey(ValueKey('home-topic-$c'));
        final surface = tester.widget<SahneTappable>(
          find.descendant(of: tile, matching: find.byType(SahneTappable)),
        );
        expect(surface.color, t.s1, reason: '$c: karo nötr yüzey olmalı');
        final fill = CategoryVisuals.tone(c).fill(night: dark);
        final strip = tester.widget<ColoredBox>(
          find.byKey(ValueKey('home-topic-strip-$c')),
        );
        expect(strip.color, fill, reason: '$c şerit rengi');
        expect(
          tester.getSize(find.byKey(ValueKey('home-topic-strip-$c'))).width,
          4,
        );
        final badge = tester.widget<CategoryIconTile>(
          find.byKey(ValueKey('home-topic-badge-$c')),
        );
        expect(badge.size, 40);
        expect(badge.category, c);
        // Ad normal metin renginde.
        final name = tester.widget<Text>(
          find
              .descendant(
                of: tile,
                matching: find.text(CategoryNames.tile(c, false)),
              )
              .first,
        );
        expect(name.style?.color, t.tx, reason: '$c adı');
        // Silik büyük filigran yok.
        expect(
          find.descendant(
            of: tile,
            matching: find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is SahneCategoryGlyphPainter,
            ),
          ),
          findsNothing,
          reason: '$c: filigran çizimi kalkmalı',
        );
      }
    });
  }

  testWidgets('ikinci dil satırı yalnız ayar açıkken çizilir', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_grid(dark: false, bilingual: false));
    await tester.pumpAndSettle();
    expect(find.byKey(SahneBilingualLabel.valueKey), findsNothing);
    await tester.pumpWidget(_grid(dark: false, bilingual: true));
    await tester.pumpAndSettle();
    // Test yazı tipi geniştir: satır sığmayınca hiç çizilmez (bileşenin
    // sözleşmesi). Burada yalnız ayar AÇIKKEN yerleşimin bozulmadığı ve
    // çizilen satırın tek satır olduğu sabitlenir.
    expect(tester.takeException(), isNull);
    for (final e in find.byKey(SahneBilingualLabel.valueKey).evaluate()) {
      expect((e.widget as Text).maxLines, 1);
    }
  });

  test('K14: iki dilli etiketler varsayılan KAPALI', () {
    expect(BilingualLabelsProvider().enabled, isFalse);
  });
}
