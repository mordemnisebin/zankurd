import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/screens/home/today_task_card.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/app_state.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/zan_mascot.dart';

import 'sahne_widgets/sahne_harness.dart';

/// "Vay" katmanı bekçisi (VAY_KATMANI A1, A2, A3, A4, A5, B1, B5, B10;
/// 2026-10-29).
///
/// ## Kusur
///
/// Altı tasarım turu uygulamayı temiz ama CANSIZ bıraktı: düğme düz bir
/// turuncu dikdörtgen, kartlar yassı, boş ekranlar tek bir gri ikon, sonuç
/// ekranı yıldız satırı. Rakipte (Duolingo, TRT) aynı yüzeylerin hacmi,
/// bir karakteri ve bir kutlama anı var.
///
/// ## Neden sessiz kalırdı
///
/// Hacim ve maskot saf görseldir; hiçbir hesap, hiçbir kontrast testi
/// değişmez. Birisi "sadeleştirme" diye koyu tabanı, kartın ışığını ya da
/// maskotu söker ve bütün testler yeşil kalır — tam olarak 2026-10-21'de
/// sadeleştirmenin rengi öldürdüğü gibi. Bu bekçi, her reçetenin VAR
/// olduğunu ve KURALINI (hareketi azaltta hareket yok, konfeti yalnız ≥ 2
/// yıldızda, maskot dekoratif) sabitler.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ZanMascot.preloadForTest();
  });

  Finder shadowBase() => find.byWidgetPredicate((w) {
    if (w is! DecoratedBox) return false;
    final d = w.decoration;
    return d is ShapeDecoration &&
        (d.shadows ?? const []).any((s) => s.color == SahneVolume.baseColor);
  });

  double baseOffset(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(shadowBase().first);
    final d = box.decoration as ShapeDecoration;
    return d.shadows!
        .firstWhere((s) => s.color == SahneVolume.baseColor)
        .offset
        .dy;
  }

  double faceDy(WidgetTester tester) {
    final t = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(SahnePressSink),
            matching: find.byType(Transform),
          )
          .first,
    );
    return t.transform.getTranslation().y;
  }

  group('A1 birincil düğme hacmi', () {
    for (final dark in [false, true]) {
      testWidgets('${dark ? 'gece' : 'gündüz'}: ≥ 56, 4 px koyu taban, '
          'basınca yüz 2 px iner taban 2 px olur', (tester) async {
        await pumpSahne(
          tester,
          const SahneButton.primary(
            label: 'Başla',
            onPressed: noop,
            expand: true,
          ),
          dark: dark,
          textScale: 1,
        );
        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(FilledButton)).height,
          greaterThanOrEqualTo(SahneVolume.buttonHeight),
        );
        expect(baseOffset(tester), SahneVolume.base);
        expect(faceDy(tester), 0);

        final g = await tester.startGesture(
          tester.getCenter(find.byType(FilledButton)),
        );
        await tester.pump();
        await tester.pump(
          SahneVolume.pressDown + const Duration(milliseconds: 20),
        );
        expect(faceDy(tester), SahneVolume.press);
        expect(baseOffset(tester), SahneVolume.base - SahneVolume.press);
        await g.up();
        await tester.pump();
        await tester.pump(
          SahneVolume.pressUp + const Duration(milliseconds: 20),
        );
        expect(faceDy(tester), 0);
        expect(baseOffset(tester), SahneVolume.base);
      });
    }

    testWidgets('hareketi azalt: taban sabit 4 px, basınca yüz oynamaz', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const SahneButton.primary(
          label: 'Başla',
          onPressed: noop,
          expand: true,
        ),
        dark: false,
        textScale: 1,
        reduceMotion: true,
      );
      final g = await tester.startGesture(
        tester.getCenter(find.byType(FilledButton)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(faceDy(tester), 0);
      expect(baseOffset(tester), SahneVolume.base);
      await g.up();
    });

    testWidgets('pasif düğmede taban ve gradyan yok', (tester) async {
      await pumpSahne(
        tester,
        const SahneButton.primary(label: 'Başla', onPressed: null),
        dark: false,
        textScale: 1,
      );
      expect(shadowBase(), findsNothing);
    });

    testWidgets('320 pt ve yazı ×2: taşma yok', (tester) async {
      await pumpSahne(
        tester,
        const SahneButton.primary(
          label: 'Dest bi pêşbirkê bike',
          onPressed: noop,
          expand: true,
        ),
        dark: false,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('A2 kabartma kartı (mod, konu, görev)', () {
    Finder embossed() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is SahneEmbossPainter,
    );

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'gece' : 'gündüz'}: üç mod kartı + görev kartı '
          'ışık katmanı taşır', (tester) async {
        await pumpSahne(
          tester,
          const Column(
            children: [
              SahneModeTile(
                lobby: true,
                icon: AppIcons.gamepad,
                role: SahneRole.race,
                title: 'Yarış',
                subtitle: 'Düello, oda',
                onTap: noop,
              ),
              SahneModeTile(
                calm: true,
                icon: AppIcons.graduationCap,
                role: SahneRole.learn,
                title: 'Öğren',
                onTap: noop,
              ),
              SahneModeTile(
                icon: AppIcons.gamepad,
                role: SahneRole.social,
                title: 'Oda',
                onTap: noop,
              ),
              TodayTaskCard(isKu: false, loading: false, onStart: noop),
            ],
          ),
          dark: dark,
          textScale: 1,
          size: const Size(390, 1400),
        );
        expect(tester.takeException(), isNull);
        expect(embossed(), findsNWidgets(4));
        for (final e in embossed().evaluate()) {
          final p = (e.widget as CustomPaint).painter! as SahneEmbossPainter;
          expect(p.style.night, dark);
        }
        // Dış gölge kabuğu (y=8, blur=14, %14).
        // 2026-10-29 vay 2A: y=8 blur=14 kartın altında gri ikinci plaka
        // gibiydi (Astra); gölge 2 px'e indi (ayrıntı: `vay_2a_test`).
        expect(SahneEmbossStyle.outerShadow.offset, const Offset(0, 2));
        expect(SahneEmbossStyle.outerShadow.blurRadius, 8);
      });
    }

    test('ışık reçetesi: gündüz %60, gece %12, doygun %16', () {
      expect(const SahneEmbossStyle(night: false).lightAlpha, 0.60);
      expect(const SahneEmbossStyle(night: true).lightAlpha, 0.12);
      expect(
        const SahneEmbossStyle(night: false, saturated: true).lightAlpha,
        0.16,
      );
    });
  });

  group('A3 kilim kenar boyacısı', () {
    testWidgets('şerit çizilir, ekran okuyucuya görünmez', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpSahne(
        tester,
        const SahneKilimBorder(color: SahneKilimBorderPainter.lightOn),
        dark: false,
        textScale: 1,
      );
      expect(find.byKey(const ValueKey('sahne-kilim-border')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel(RegExp('.+')), findsNothing);
      handle.dispose();
    });

    test('renkler: açıkta #245C69 %7, koyuda beyaz %9', () {
      expect(SahneKilimBorderPainter.lightOn.a, closeTo(0.07, 0.01));
      expect(SahneKilimBorderPainter.darkOn.a, closeTo(0.09, 0.01));
      expect(SahneKilimBorderPainter.unit, 24);
    });

    testWidgets('görev kartında TEK kilim bölgesi (ekran başına ≤ 2)', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const TodayTaskCard(isKu: false, loading: false, onStart: noop),
        dark: false,
        textScale: 1,
        size: const Size(390, 800),
      );
      expect(find.byKey(const ValueKey('sahne-kilim-border')), findsOneWidget);
    });
  });

  group('A4 maskot bileşeni', () {
    testWidgets('altı poz yüklenir ve dekoratiftir (anlam metinde)', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      for (final pose in ZanPose.values) {
        await pumpSahne(
          tester,
          Row(children: [ZanMascot(pose: pose, size: 96)]),
          dark: false,
          textScale: 1,
        );
        await tester.pump();
        expect(
          find.byKey(ValueKey('zan-mascot-${pose.asset}')),
          findsOneWidget,
          reason: '$pose',
        );
        // SVG gerçekten çözüldü: yer tutucu değil, çizilen resim var.
        expect(
          find.byWidgetPredicate(
            (w) => w.runtimeType.toString().contains('RawPicture'),
          ),
          findsOneWidget,
          reason: '$pose çizilmedi (SVG özelliği desteklenmiyor olabilir)',
        );
        expect(tester.takeException(), isNull);
        expect(
          find.ancestor(
            of: find.byKey(ValueKey('zan-mascot-${pose.asset}')),
            matching: find.byType(ExcludeSemantics),
          ),
          findsWidgets,
        );
      }
      handle.dispose();
    });

    testWidgets('boyut genişliktir, yükseklik pozun oranından gelir', (
      tester,
    ) async {
      await pumpSahne(
        tester,
        const Row(
          children: [
            ZanMascot(pose: ZanPose.welcome, size: 112),
            ZanMascot(pose: ZanPose.correct, size: 48),
          ],
        ),
        dark: true,
        textScale: 1,
      );
      final big = tester.getSize(
        find.byKey(const ValueKey('zan-mascot-selam')),
      );
      expect(big.width, 112);
      expect(big.height, closeTo(112 / ZanPose.welcome.aspect, 0.01));
      final mini = tester.getSize(
        find.byKey(const ValueKey('zan-mascot-mini_dogru')),
      );
      expect(mini.width, 48);
    });

    testWidgets('giriş hareketi: tek 360 ms zıplama; hareketi azaltta sabit', (
      tester,
    ) async {
      double top() =>
          tester.getTopLeft(find.byKey(const ValueKey('zan-mascot-selam'))).dy;
      const row = Row(children: [ZanMascot(pose: ZanPose.welcome, size: 96)]);

      // Hareketli: pumpSahne 300 ms ilerletir (zıplamanın ortası-sonu), taban
      // çizgisinden yukarıdadır; 360 ms dolunca taban çizgisine oturur.
      await pumpSahne(tester, row, dark: false, textScale: 1);
      final hopping = top();
      await tester.pump(const Duration(milliseconds: 200));
      final settled = top();
      expect(hopping, lessThan(settled));

      // Hareketi azalt: ilk karede de, sonra da aynı yerde.
      await pumpSahne(
        tester,
        row,
        dark: false,
        textScale: 1,
        reduceMotion: true,
      );
      expect(top(), settled);
    });
  });

  group('A5 / B5 sonuç ödül kompozisyonu', () {
    Finder confetti() => find.byKey(const ValueKey('sahne-confetti-burst'));

    for (final stars in [1, 2, 3]) {
      testWidgets('$stars yıldız: madalya + maskot var; konfeti ve ışın '
          'yalnız ≥ 2 yıldızda', (tester) async {
        await pumpSahne(
          tester,
          SahneMedalScene(stars: stars),
          dark: true,
          textScale: 1,
          size: const Size(390, 600),
        );
        expect(find.byKey(const ValueKey('result-medal')), findsOneWidget);
        final pose = stars >= 2 ? 'mutlu' : 'uzgun';
        expect(find.byKey(ValueKey('zan-mascot-$pose')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('result-ray-disc')),
          stars >= 2 ? findsOneWidget : findsNothing,
        );
        expect(confetti(), stars >= 2 ? findsOneWidget : findsNothing);
        await tester.pump(SahneConfettiBurst.duration);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('hareketi azalt: konfeti hiç çizilmez', (tester) async {
      await pumpSahne(
        tester,
        const SahneMedalScene(stars: 3),
        dark: true,
        textScale: 1,
        reduceMotion: true,
        size: const Size(390, 600),
      );
      expect(confetti(), findsNothing);
      expect(find.byKey(const ValueKey('result-medal')), findsOneWidget);
    });

    testWidgets('320 pt ve yazı ×2: taşma yok', (tester) async {
      await pumpSahne(tester, const SahneMedalScene(stars: 3), dark: false);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byKey(const ValueKey('result-medal'))).width,
        SahneMedalScene.medalSize,
      );
    });

    // 2026-10-29 vay 2A: maskot 120 → 84 ve madalyaya biner (tek odak).
    test('ölçüler: madalya 104, ışın diski 164, maskot 84', () {
      expect(SahneMedalScene.medalSize, 104);
      // 2026-10-29 son kurul tur 3: 184 → 164 (kutlama hafifledi).
      expect(SahneMedalScene.discSize, 164);
      expect(SahneMedalScene.mascotSize, 84);
      expect(SahneConfettiBurst.duration, const Duration(milliseconds: 650));
    });
  });

  group('B10 boş durumlar maskotla', () {
    testWidgets('AppEmptyState karşılama maskotunu çizer; hata/çevrimdışı '
        'ikonla kalır', (tester) async {
      await pumpSahne(
        tester,
        const Column(
          children: [
            AppEmptyState(
              icon: AppIcons.peopleGroup,
              title: 'Boş',
              message: 'Henüz bir şey yok.',
            ),
          ],
        ),
        dark: false,
        textScale: 1,
        size: const Size(390, 800),
      );
      expect(find.byKey(const ValueKey('empty-state-mascot')), findsOneWidget);
      expect(find.byIcon(AppIcons.peopleGroup), findsNothing);
      expect(tester.takeException(), isNull);

      await pumpSahne(
        tester,
        const AppErrorState(
          title: 'Hata',
          message: 'x',
          retryLabel: 'Yeniden',
          onRetry: noop,
        ),
        dark: false,
        textScale: 1,
        size: const Size(390, 800),
      );
      expect(find.byKey(const ValueKey('empty-state-mascot')), findsNothing);
    });

    for (final dark in [false, true]) {
      testWidgets('${dark ? 'gece' : 'gündüz'} 320 pt ×2: boş durum taşmaz', (
        tester,
      ) async {
        await pumpSahne(
          tester,
          const AppEmptyState(
            icon: AppIcons.peopleGroup,
            title: 'Hîn ne dostan',
            message: 'Dostên xwe zêde bike û bi hev re pêşbirkê bike.',
            actionLabel: 'Dostan lê zêde bike',
          ),
          dark: dark,
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
