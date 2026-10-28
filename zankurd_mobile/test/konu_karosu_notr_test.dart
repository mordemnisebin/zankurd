// 2026-10-28 kurul turu 2 R1: konu karosu TONLU yüzey (K1'in nötr karosunun
// yerine; dosya adı tarihçe için kaldı).
//
// Kusur: tur 1'de karo nötr yüzey + renkli rozetti; dört model "aşırı
// sterilize, bankacılık uygulaması" dedi (canlılık 4-7). Doygun dolu karo
// da geri dönmemeli (on bir karo yan yana bağırıyordu). Karar: yüzey konu
// renginin HAFİF karışımı ([SahneTopicTint.topicSurface]: gündüz %12, gece
// %20), kenar konu renginin soluğu, 4 px başlangıç şeridi, 44 px rozet,
// sağ üst köşede ≤ %8 konu ikonu filigranı. Ad normal metin renginde;
// ikinci dil yalnız "iki dilli etiketler" açıksa küçük soluk satır.
// Kontrast (metin ≥ 4,5:1 tonlu yüzeyde, on bir konu × iki tema) ayrı
// bekçide: `konu_tonu_kontrast_test.dart`. Eski bekçi karonun `s1` olmasını
// şart koşuyordu; tersine çevrildi (tonlu olmalı, nötr s1 ya da doygun dolgu
// OLMAMALI).
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
    testWidgets('karo tonlu yüzey, 44 rozet, 4 şerit, ≤%8 filigran '
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
        final fill = CategoryVisuals.tone(c).fill(night: dark);
        expect(
          surface.color,
          t.topicSurface(fill, night: dark),
          reason: '$c: karo konu renginin hafif tonu olmalı',
        );
        expect(surface.color, isNot(t.s1), reason: '$c: nötr s1 olmamalı');
        expect(surface.color, isNot(fill), reason: '$c: doygun dolu olmamalı');
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
        expect(badge.size, 44);
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
        // Köşe filigranı çok hafif (≤ %8) ve konunun kendi ikonu.
        final mark = tester.widget<Icon>(
          find.byKey(ValueKey('home-topic-mark-$c')),
        );
        expect(mark.color!.a, lessThanOrEqualTo(0.08), reason: '$c filigran');
        expect(mark.icon, CategoryVisuals.icon(c));
        // Eski silik büyük çizim (painter) yok.
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
