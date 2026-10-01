// 2026-09-30 maket (A1 + A3): ana ekran konu ızgarası etiket sistemi ve
// konu akışının ortak başlığı.
//
// Kusur sessizdi: ızgarada "Bilim ve Düşünce / Zanist û Raman" dört satıra
// sarıp satırı uzatıyor, "Siyaset" (iki dilde aynı ad) ikinci satırı hiç
// çizmiyor, ilerleme çubuğu yalnız oynanmış konuda çıkıyordu; karolar
// birbirinden farklı boyda, altlarında ~100 pt boş kuyu kalıyordu. Hiçbir
// test boyları KARŞILAŞTIRMIYORDU. Bu dosya sözleşmeyi sabitler: her karoda
// aynı etiket bloğu (ad, öteki ad, sayı, ilerleme çizgisi), hiçbir etiket
// sarmaz ya da "…" ile kesilmez, kısa ad yalnız karoda geçer.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/home/home_rows.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';

const _categories = [
  'Ziman',
  'Çand',
  'Dîrok',
  'Edebiyat',
  'Cografya',
  'Muzîk',
  'Siyaset',
  'Paradigma',
  'Sînema',
  'Teknolojî',
  'Cîhan',
];

Widget _shell(
  Widget child, {
  required double scale,
  required bool ku,
  bool dark = true,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang(ku ? 'ku' : 'tr'),
      ),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: appChild!,
      ),
      home: child,
    ),
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _grid({required bool ku, required double scale, bool dark = true}) =>
    _shell(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(SahneSpace.page),
          child: HomeTopicGrid(
            isKu: ku,
            categories: _categories,
            progress: const {
              'Çand': CategoryProgress(
                category: 'Çand',
                correct: 4,
                threshold: 10,
              ),
            },
            questionCounts: {
              for (final (i, c) in _categories.indexed) c: 82 + i * 37,
            },
            onOpen: (_) {},
          ),
        ),
      ),
      scale: scale,
      ku: ku,
      dark: dark,
    );

void main() {
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LevelProgressStore.resetInstance();
  });

  group('A1: konu karosu etiket sistemi', () {
    for (final size in [const Size(320, 640), const Size(390, 844)]) {
      for (final scale in [1.0, 1.5, 2.35]) {
        for (final ku in [false, true]) {
          testWidgets(
            'her karo aynı boyda; hiçbir etiket sarmaz ya da kesilmez '
            '(${size.width.toInt()} px, x$scale, ${ku ? 'ku' : 'tr'})',
            (tester) async {
              _size(tester, size);
              await tester.pumpWidget(_grid(ku: ku, scale: scale));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);

              // 1) Bütün karolar aynı yükseklikte (oynanmış ve oynanmamış,
              // iki dilde aynı adlı Siyaset, uzun adlı Bilim dahil).
              final heights = {
                for (final c in _categories)
                  c: tester
                      .getSize(find.byKey(ValueKey('home-topic-$c')))
                      .height,
              };
              expect(
                heights.values.toSet().length,
                1,
                reason: 'karo boyları eşit değil: $heights',
              );

              for (final c in _categories) {
                final tile = find.byKey(ValueKey('home-topic-$c'));
                // 2) Etiket satırlarının hiçbiri sarmaz ya da kesilmez: her
                // metin tek satırdır (yüksekliği tek satır yüksekliğinde).
                for (final element
                    in find
                        .descendant(of: tile, matching: find.byType(RichText))
                        .evaluate()) {
                  final p = element.renderObject! as RenderParagraph;
                  final text = p.text.toPlainText();
                  expect(
                    p.didExceedMaxLines,
                    isFalse,
                    reason: '$c: "$text" kesildi',
                  );
                  expect(
                    p.getFullHeightForCaret(const TextPosition(offset: 0)) *
                            1.5 >
                        p.size.height,
                    isTrue,
                    reason: '$c: "$text" birden çok satıra sardı',
                  );
                }
                // 3) İlerleme çizgisi HER karoda var (oynanmamışta boş iz).
                final bar = tester.widget<LinearProgressIndicator>(
                  find.descendant(
                    of: tile,
                    matching: find.byType(LinearProgressIndicator),
                  ),
                );
                expect(bar.value, c == 'Çand' ? greaterThan(0) : 0, reason: c);
              }
            },
          );
        }
      }
    }

    testWidgets('Bilim ve Düşünce karoda kısa adla yazılır, tam ad ekran '
        'okuyucuda kalır', (tester) async {
      final semantics = tester.ensureSemantics();
      _size(tester, const Size(390, 844));
      for (final ku in [false, true]) {
        await tester.pumpWidget(_grid(ku: ku, scale: 1.0));
        await tester.pumpAndSettle();
        final tile = find.byKey(const ValueKey('home-topic-Paradigma'));
        final full = CategoryNames.localized('Paradigma', ku);
        final fullOther = CategoryNames.localized('Paradigma', !ku);
        // Karoda kısa ad ve kısa öteki ad.
        expect(
          find.descendant(
            of: tile,
            matching: find.text(CategoryNames.tile('Paradigma', ku)),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: tile, matching: find.text(full)),
          findsNothing,
          reason: 'tam ad karoya sığmaz; karoda kısa ad yazılır',
        );
        // Ekran okuyucu tam adı okur.
        expect(
          find.bySemanticsLabel(RegExp('^$full, $fullOther')),
          findsOneWidget,
        );
      }
      semantics.dispose();
    });

    test('kısa adlar yalnız gerekli konuda; tam ad olduğu gibi kalır', () {
      expect(CategoryNames.tile('Paradigma', false), 'Bilim');
      expect(CategoryNames.tile('Paradigma', true), 'Zanist');
      expect(CategoryNames.localized('Paradigma', false), 'Bilim ve Düşünce');
      expect(CategoryNames.localized('Paradigma', true), 'Zanist û Raman');
      for (final c in _categories.where((c) => c != 'Paradigma')) {
        expect(
          CategoryNames.tile(c, false),
          CategoryNames.localized(c, false),
          reason: c,
        );
        expect(
          CategoryNames.tile(c, true),
          CategoryNames.localized(c, true),
          reason: c,
        );
      }
    });

    for (final dark in [false, true]) {
      testWidgets('boş (%0) ilerleme izi ${dark ? 'gecede' : 'gündüzde'} '
          'görünür kenarlıdır', (tester) async {
        _size(tester, const Size(390, 844));
        await tester.pumpWidget(_grid(ku: false, scale: 1.0, dark: dark));
        await tester.pumpAndSettle();
        final edge = sahneTrackEdge(dark ? SahneTokens.night : SahneTokens.day);
        if (dark) {
          expect(edge.a, 0);
        } else {
          // Gündüz izi (#D0D7EC) beyaz yüzeyde ~1,4:1'di; kenar ≥ 3:1 verir.
          final over = Color.alphaBlend(edge, SahneTokens.day.bg);
          final ratio =
              (SahneTokens.day.s1.computeLuminance() + 0.05) /
              (over.computeLuminance() + 0.05);
          expect(ratio, greaterThanOrEqualTo(3.0));
        }
      });
    }
  });

  group('A3: seviye ekranı', () {
    testWidgets('kilitli seviye açılma koşulunu söyler; açık seviye söylemez', (
      tester,
    ) async {
      _size(tester, const Size(390, 844));
      for (final ku in [false, true]) {
        // Dil sağlayıcısı `create` ile bir kez kurulur: ikinci turda yeniden
        // kurulsun diye önce ağaç boşaltılır.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(
          _shell(
            LevelScreen(
              repository: MockZanKurdRepository(),
              category: 'Ziman',
              subCategory: 'reziman',
            ),
            scale: 1.0,
            ku: ku,
            dark: false,
          ),
        );
        await tester.pumpAndSettle();
        // 2. seviyeden itibaren kilitli: koşul bir önceki seviyeyi söyler.
        for (var n = 2; n <= 5; n++) {
          final hint = find.byKey(ValueKey('level-lock-hint-$n'));
          expect(hint, findsOneWidget, reason: 'seviye $n');
          expect(
            tester.widget<Text>(hint).data,
            Tr.forKu(K.oncePSeviyeyiTamamla, ku, {'p0': '${n - 1}.'}),
          );
          final p = tester.renderObject<RenderParagraph>(hint);
          expect(p.didExceedMaxLines, isFalse);
        }
        expect(find.byKey(const ValueKey('level-lock-hint-1')), findsNothing);
      }
    });
  });
}
