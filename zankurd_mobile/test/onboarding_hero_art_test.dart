/// Onboarding hero SANATININ bekçisi: sayfa 1 kategori yelpazesi
/// (`_CategoryFan`), sayfa 2 yarışma sahnesi (`StageBackdropPainter`) ve
/// hero/başlık arası boşluk.
///
/// ## Kusur
///
/// Her iki tanıtım sayfasının hero'su aynı jenerik kalıptaydı: forest
/// gradyanı + kilim dokusu + BEYAZ DAİREDE TEK İKON (mezuniyet şapkası ya
/// da şimşek) + köşede Zana. Sahip ekranı "renksiz" buldu: ikon ne
/// kategoriyle ne de "burada ne var" sorusuyla ilgiliydi; sayfa 2 sakin,
/// tek düzeyli bir menü gibi duruyordu — Yarış sekmesindeki yarışma
/// sahnesiyle hiçbir görsel bağı yoktu. Uzun telefonlarda (390×844) hero
/// ile başlık arasında da ~100pt boş alan kalıyordu: metin bandı içeriğe
/// (kısa başlık + iki madde) göre çok büyüktü, `Column` içeriği ortaladığı
/// için bu fazlalık tepede boşluk olarak birikiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// `onboarding_hierarchy_test.dart` yalnız hero YÜKSEKLİĞİNİ (< 300pt)
/// ölçüyordu; hero'nun İÇİNDE ne olduğuna hiç bakmıyordu — tek ikon da,
/// üç görsel de, boş bir kutu da aynı yükseklik testini geçerdi.
/// `auth_onboarding_test.dart` hero'nun Forest gradyanını ve maskotun
/// varlığını sınıyordu ama `_OnboardingIcon`in TEK ikon olduğunu hiç
/// doğrulamıyordu; ikon üç görsele dönüştüğünde de aynı testler sessizce
/// geçmeye devam ederdi. Hero ile başlık arasındaki boşluk hiçbir yerde
/// PİKSEL olarak ölçülmüyordu — yalnız ekran turunda göze çarpıyordu, hiçbir
/// test kırmızıya dönmüyordu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/stage_backdrop.dart';

/// Tek başına `OnboardingScreen`i (yalnız dil sağlayıcısıyla) çizer —
/// `onboarding_hierarchy_test.dart` ile aynı hafif kurulum.
Future<void> _pumpOnboarding(WidgetTester tester, {String lang = 'tr'}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(lang),
      child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
    ),
  );
  await tester.pumpAndSettle();
}

/// `auth_onboarding_test.dart`daki "app logo ... yuksek kalite" testiyle
/// aynı çözme deseni: `cacheWidth` verildiği için `Image.asset` sağlayıcıyı
/// bir `ResizeImage` içine sarar; asıl asset adı bir katman altındadır.
String _assetNameOf(ImageProvider<Object> provider) {
  return provider is ResizeImage
      ? (provider.imageProvider as AssetImage).assetName
      : (provider as AssetImage).assetName;
}

void main() {
  final hero = find.byKey(const ValueKey('onboarding-hero-panel'));

  group('1) Sayfa 1: kategori yelpazesi (_CategoryFan)', () {
    testWidgets(
      'hero tam olarak üç kategori görseli gösterir (Ziman/Çand/Muzîk)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpOnboarding(tester);

        final images = find.descendant(of: hero, matching: find.byType(Image));
        expect(images, findsNWidgets(3));

        final assetNames = images
            .evaluate()
            .map((e) => _assetNameOf((e.widget as Image).image))
            .toSet();
        expect(
          assetNames,
          {
            CategoryVisuals.imagePath('Ziman'),
            CategoryVisuals.imagePath('Çand'),
            CategoryVisuals.imagePath('Muzîk'),
          },
          reason:
              'yelpazedeki üç kart tam olarak Ziman/Çand/Muzîk kategori '
              'görsellerini kullanmalı — CategoryVisuals.imagePath ile aynı '
              'kaynaktan (alt kategori ekranlarıyla aynı görsel).',
        );
      },
    );

    testWidgets('yelpazedeki hiçbir görsel ayrı semantik eklemez', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final semantics = tester.ensureSemantics();

      await _pumpOnboarding(tester);

      final images = find.descendant(of: hero, matching: find.byType(Image));
      expect(images, findsNWidgets(3));

      // Her kart kendi `excludeFromSemantics: true` bayrağını taşımalı —
      // dekoratiftir, başlık/gövde zaten aynı bilgiyi (öğrenme + kategori
      // sayısı) metinle veriyor.
      for (final element in images.evaluate()) {
        expect(
          (element.widget as Image).excludeFromSemantics,
          isTrue,
          reason: 'her yelpaze kartı excludeFromSemantics: true taşımalı',
        );
      }

      // Yapısal olarak da bir `ExcludeSemantics` atası olmalı — tek tek
      // widget bayrağına güvenmek yerine, sarmalayıcının kendisi de
      // yerinde olsun diye ayrıca sınanır.
      expect(
        find.ancestor(
          of: images.first,
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );

      semantics.dispose();
    });
  });

  group('2) Sayfa 2: yarışma sahnesi (StageBackdropPainter)', () {
    testWidgets(
      'hero StageBackdropPainter çizer; konfeti merkez ikonla ve Zana ile kesişmez',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpOnboarding(tester);
        await tester.tap(find.text('Sonraki'));
        await tester.pumpAndSettle();

        final stage = find.descendant(
          of: hero,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint && widget.painter is StageBackdropPainter,
          ),
        );
        expect(
          stage,
          findsOneWidget,
          reason:
              'Yarış sekmesindeki aynı sahne fonu 2. onboarding sayfasında '
              'da çizilmeli (bkz. StageBackdropPainter).',
        );

        final stageBox = tester.getRect(stage);
        final confetti = StageBackdropPainter.confettiRects(
          stageBox.size,
        ).map((rect) => rect.shift(stageBox.topLeft)).toList();

        final icon = find.descendant(of: hero, matching: find.byType(Icon));
        expect(icon, findsOneWidget);
        final iconRect = tester.getRect(icon);

        final mascot = find.descendant(
          of: hero,
          matching: find.byType(RojMascot),
        );
        expect(mascot, findsOneWidget);
        final mascotRect = tester.getRect(mascot);

        for (final piece in confetti) {
          expect(
            piece.overlaps(iconRect),
            isFalse,
            reason: 'konfeti $piece merkez ikonla ($iconRect) kesişiyor',
          );
          expect(
            piece.overlaps(mascotRect),
            isFalse,
            reason: 'konfeti $piece Zana ($mascotRect) ile kesişiyor',
          );
        }
      },
    );
  });

  group('3) Hero ile başlık arasındaki boşluk', () {
    testWidgets(
      '390×844: hero altı ile başlık üstü arasında ≤ 64pt (eskiden ~100pt)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await _pumpOnboarding(tester);

        final heroBottom = tester.getBottomLeft(hero).dy;
        final titleTop = tester.getTopLeft(find.text('Öğren')).dy;

        expect(
          titleTop - heroBottom,
          lessThanOrEqualTo(64),
          reason:
              'heroFlex normal ekranda 38→44 büyüdü ki metin bandı '
              'daralsın ve başlık hero\'ya daha yakın otursun.',
        );
      },
    );
  });

  group('4) Küçük ekran ve büyük yazıda taşma yok', () {
    testWidgets('375×667 (iPhone SE, normal yazı): sayfa 1 ve 2 taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(375, 667));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.takeException();

      await _pumpOnboarding(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('%200 yazı: sayfa 1 ve 2 taşmaz', (tester) async {
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.takeException();

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(2),
              ),
              child: OnboardingScreen(onComplete: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Sonraki'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
