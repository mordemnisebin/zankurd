/// 2026-10-01 tasarım denetimi, küçük düzeltmeler (3/3): ortak bileşenler —
/// seçim çipi, liste ayırıcısı, uygulama çubuğunun sağ kenarı, ana sayfa
/// dil düğmesi.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zk_back_button.dart';

import 'support/widget_test_helpers.dart';

Widget _themed(Widget child, {String lang = 'tr'}) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider()..setLang(lang),
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  // ───────────────────────────────────────────────────────────────────────
  // 5) Seçili çipin boyu
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: sıralama dönemi ve inceleme sekmelerinde seçilen çip "büyüyordu"
  // (ekran görüntüsünde 88 ↔ 82 px). NİÇİN SESSİZ: layout kutusu iki hâlde
  // de 48'ti (ölçen test geçerdi); fark ÇİZİMDEydi: seçili çip Halka 2,
  // seçili olmayan 1 px'lik zemine yakın bir kenar taşıyor, kenar zeminle
  // birleşip beyaz alanı küçültüyordu.
  group('5) Çip ölçüsü', () {
    testWidgets(
      'seçili ve seçili olmayan çip aynı boyda, aynı halka kalınlığında',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Row(
                children: [
                  SahneRailChip(
                    key: const ValueKey('on'),
                    label: 'Hafta',
                    selected: true,
                    onTap: () {},
                  ),
                  SahneRailChip(
                    key: const ValueKey('off'),
                    label: 'Hafta',
                    selected: false,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(
          tester.getSize(find.byKey(const ValueKey('on'))),
          tester.getSize(find.byKey(const ValueKey('off'))),
        );

        double ring(String key) {
          final material = tester.widget<Material>(
            find
                .descendant(
                  of: find.byKey(ValueKey(key)),
                  matching: find.byType(Material),
                )
                .first,
          );
          return (material.shape! as BeveledRectangleBorder).side.width;
        }

        expect(ring('on'), ring('off'));

        // Seçili olmayan halka kendi zemininin rengindedir: açık temada beyaz
        // alan sayfa zeminine karışıp çipi küçük göstermesin.
        final off = tester.widget<Material>(
          find
              .descendant(
                of: find.byKey(const ValueKey('off')),
                matching: find.byType(Material),
              )
              .first,
        );
        expect((off.shape! as BeveledRectangleBorder).side.color, off.color);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────
  // 6) Liste ayırıcısı
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: `SahneListGroup` ayırıcıları kartın sağ kenarına kadar uzanıyor,
  // pahlı köşenin dışına taşıyordu (ayarlar, paywall, görsel kaynakları,
  // alt konu listesi, düello kutusu). NİÇİN SESSİZ: karta kırpma verilmişti
  // ve düz zeminde 1 px'lik açık çizgi, 1-3 px taşsa bile fark edilmez;
  // yalnız büyütülmüş ekran görüntüsünde görünür.
  group('6) Ayırıcı', () {
    testWidgets('ayırıcı kartın sağ kenarından en az 16 içeride biter', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: SahneListGroup(
                key: ValueKey('grup'),
                children: [
                  SizedBox(height: 48, child: Text('bir')),
                  SizedBox(height: 48, child: Text('iki')),
                ],
              ),
            ),
          ),
        ),
      );

      final card = tester.getRect(find.byKey(const ValueKey('grup')));
      final lines = find
          .descendant(
            of: find.byKey(const ValueKey('grup')),
            matching: find.byType(SizedBox),
          )
          .evaluate()
          .map((e) => e.widget as SizedBox)
          .where((s) => s.height == 1)
          .toList();
      expect(lines, hasLength(1));
      final line = tester.getRect(
        find
            .descendant(
              of: find.byKey(const ValueKey('grup')),
              matching: find.byWidgetPredicate(
                (w) => w is SizedBox && w.height == 1,
              ),
            )
            .first,
      );
      expect(card.right - line.right, greaterThanOrEqualTo(16));
      expect(line.left - card.left, greaterThanOrEqualTo(16));
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 7) Uygulama çubuğunun sağ boşluğu
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: mağaza çubuğunda jeton çipi sağ kenara ~8 px yakındı; sol baştaki
  // geri plakası 16 içerideydi (35 ↔ 17 px, ekran görüntüsünde). NİÇİN
  // SESSİZ: `zkAppBar` eylemlerin ardına sabit 8'lik boşluk koyuyordu —
  // 44'lük ikon düğmeleri kendi saydam payıyla bunu 10'a tamamlıyordu,
  // yalnız yatayda payı olmayan çip kenara yapışıyordu.
  group('7) Çubuk sağ kenar', () {
    testWidgets('son eylem çipinin sağ kenarı sayfa kenarından 16 içeride', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          Builder(
            builder: (context) => Scaffold(
              appBar: zkAppBar(
                context,
                title: const Text('Mağaza'),
                actions: const [
                  SahneStatChip(
                    key: ValueKey('chip'),
                    leading: SahneGlyph(SahneGlyphKind.coin),
                    label: '0 jeton',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final chip = tester.getRect(find.byKey(const ValueKey('chip')));
      expect(width - chip.right, SahneSpace.page);
    });

    testWidgets('son eylem ikon düğmesi ise görsel kenarı 16 içeride', (
      tester,
    ) async {
      await tester.pumpWidget(
        _themed(
          Builder(
            builder: (context) => Scaffold(
              appBar: zkAppBar(
                context,
                title: const Text('Başlık'),
                actions: [
                  SahneIconButton(
                    key: const ValueKey('btn'),
                    icon: Icons.add,
                    semanticLabel: 'Ekle',
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      final btn = tester.getRect(find.byKey(const ValueKey('btn')));
      // 48'lik dokunma kutusu, 44'lük görselin her yanında 2 pay taşır.
      expect(width - btn.right, SahneSpace.page - SahneIconButton.inset);
      expect(ZkBackButton.tapTarget, 48);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // 8) Ana sayfa dil düğmesi
  // ───────────────────────────────────────────────────────────────────────
  //
  // KUSUR: "TR"/"KU" düz ikincil metindi; yanındaki seri/jeton çipleri çip
  // olduğundan dil düğmesi düğmeye benzemiyordu. NİÇİN SESSİZ: dokunma
  // kutusu 48 × 48 idi ve ekran okuyucu etiketi vardı — erişilebilirlik
  // testleri geçiyordu; eksik olan GÖRÜNÜR bir düğme biçimiydi.
  group('8) Dil düğmesi', () {
    testWidgets(
      'Şahnê çipidir, 48 × 48 üstü, ekran okuyucuya adıyla duyurulur',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final repo = freshMockRepository();
        tester.view.physicalSize = const Size(390, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(testShell(child: HomeScreen(repository: repo)));
        await tester.pump(const Duration(seconds: 1));

        final toggle = find.byKey(const ValueKey('home-language-toggle'));
        expect(toggle, findsOneWidget);
        expect(tester.widget(toggle), isA<SahneStatChip>());
        final size = tester.getSize(toggle);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(find.bySemanticsLabel('Dil, TR'), findsOneWidget);

        await tester.tap(toggle);
        await tester.pump();
        expect(find.bySemanticsLabel('Ziman, KU'), findsOneWidget);
      },
    );
  });
}
