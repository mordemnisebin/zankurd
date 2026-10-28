// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
//
// 2026-10-28 kurul K10 (geçersiz kılınan eski kararlar): karşılama 2 değil 3
// adımdır (1. adım dil: iki büyük kart); alt düğme "Sonraki" değil "Devam";
// kahraman sahne kartı (`onboarding-hero-panel`, kilim, koyu kutu) kalktı —
// görsel düz zeminde rol tonlu rozettir; logo 40 değil 96 (dil adımında,
// kutusuz). Hiyerarşi kuralı sürer: adım başına 1 başlık + ≤ 2 satır.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  testWidgets('tanıtım dil, öğrenme ve yarış değerini üç kısa adımda anlatır', (
    tester,
  ) async {
    var completed = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(
          home: OnboardingScreen(onComplete: () => completed++),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Uygulama dili · Zimanê sepanê'), findsOneWidget);
    expect(find.text('Devam'), findsOneWidget);
    expect(find.text('Başla'), findsNothing);
    expect(find.text('Öğren'), findsNothing);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(find.text('Öğren'), findsOneWidget);
    expect(find.text('Devam'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();

    expect(find.text('Arkadaşlarınla yarış'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);
    expect(find.text('Devam'), findsNothing);

    await tester.tap(find.text('Başla'));
    expect(completed, 1);
  });

  testWidgets('onboarding atlama eylemi ekran okuyucuda adlandırılır', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Atla'), findsOneWidget);
    semantics.dispose();
  });

  // 2026-09-29 Şahnê: bu iki bekçi Forest degradesini (hero ve seçili adım
  // göstergesi) sabitliyordu. Slaytlar artık sahne kartıdır ve rolünü
  // taşır; gösterge elmaslardan oluşur. Korunan şey: her adım ortak bir
  // sahne kimliği taşır (renk kararsızca sayfadan sayfaya değişmez, rol
  // değişir) ve etkin adım göstergede şekille (büyük elmas) ayrışır.
  // 2026-09-29 doğallık: gösterge elmas değil çubuk (K5: elmas yalnız soru
  // ilerlemesi ve ders sayacı). Korunan kural aynı: etkin adım renkten
  // bağımsız olarak şekille — uzun çubukla — ayrışır.
  testWidgets('onboarding her adımda sahne kartı kimliğini kullanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    Color artColor() => tester
        .widget<Icon>(
          find
              .descendant(
                of: find.byKey(const ValueKey('onboarding-scene-art')),
                matching: find.byType(Icon),
              )
              .first,
        )
        .color!;
    const t = SahneTokens.day;

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(artColor(), t.learnTx);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(artColor(), t.raceTx);
  });

  // 2026-10-01 giriş iskeleti: sayfa göstergesi iki ayrı çubuk değil, kayıt
  // ve seviye sınavıyla aynı tek ilerleme çubuğudur (`SahneProgressBar`) ve
  // yanında "1/2" yazar. Korunan kural eskisinin aynısı: durum renkten
  // bağımsız — dolgu oranı ve sayı — söylenir.
  testWidgets('onboarding ilerleme çubuğu sayfa oranını ve sayısını söyler', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final bar = find.byKey(const ValueKey('onboarding-progress'));
    expect(tester.widget<SahneProgressBar>(bar).value, closeTo(1 / 3, 1e-9));
    expect(tester.widget<SahneProgressBar>(bar).trailing, '1/3');
    expect(find.text('1/3'), findsOneWidget);

    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(tester.widget<SahneProgressBar>(bar).value, closeTo(2 / 3, 1e-9));
    await tester.tap(find.text('Devam'));
    await tester.pumpAndSettle();
    expect(tester.widget<SahneProgressBar>(bar).value, 1.0);
    expect(tester.widget<SahneProgressBar>(bar).trailing, '3/3');
  });

  testWidgets('onboarding dil düğmesi başlık alanına yayılmaz', (tester) async {
    // 518784fe (48dp a11y) Container'a hem min kısıt hem `alignment`
    // ekledi; Stack altında gevşek ama sınırlı kısıtta hizalama, kabı
    // başlık alanının tamamına yayıyor ve düğme 346x180'lik boş bir
    // panele dönüşüyordu. Ekran turu bunu görüntüledi ama hiçbir test
    // boyut ölçmediği için sessiz kaldı (2026-09-10).
    //
    // 2026-09-27: tek "KU"/"TR" hapı (`onboarding-language-toggle`), giriş
    // ekranındakiyle aynı iki-parçalı KU|TR seçiciye (`LanguageToggle`)
    // taşındı — karşı dile nasıl geçileceği artık görünür. Anahtar da her
    // çip için ayrı (`onboarding-language-ku`/`-tr`); bu test artık HER
    // çipin küçük ve dokunulabilir kaldığını, eski tek-hap kadar sıkı
    // sınar.
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in [const Size(390, 844), const Size(1200, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
        ),
      );
      await tester.pumpAndSettle();

      for (final key in const [
        ValueKey('onboarding-language-ku'),
        ValueKey('onboarding-language-tr'),
      ]) {
        final chip = tester.getSize(find.byKey(key));
        // Dil seçici büyük hedeflidir (56 yüksek, sütunun yarısı) ama başlık
        // alanının tamamına yayılmaz.
        expect(
          chip.width,
          lessThanOrEqualTo(SahneEntryScaffold.columnWidth / 2),
        );
        // K10: iki BÜYÜK kart (≥ 96 yüksek).
        expect(chip.height, greaterThanOrEqualTo(96));
        expect(
          tester
              .getSemantics(find.byKey(key))
              .getSemanticsData()
              .hasAction(ui.SemanticsAction.tap),
          isTrue,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('normal yükseklikte onboarding logosu belirgindir', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in [const Size(390, 844), const Size(1200, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
        ),
      );
      await tester.pumpAndSettle();

      // 2026-09-30 logo: işaret plakasız (`onBrandSurface` kalktı, bkz.
      // splash_screen_test); maskot yok ("maskot: Yok", spec_sahne.json).
      //
      // 2026-10-01: logo üst yığından kahraman kartın İÇİNE taşındı (giriş,
      // kayıt ve ad ekranındaki kartlar da logo taşır) ve 40 genişliğinde.
      final logo = tester.widget<AppLogo>(find.byType(AppLogo));
      expect(logo.width, 96);
      expect(
        find.ancestor(
          of: find.byType(AppLogo),
          matching: find.byType(SahneStageCard),
        ),
        findsNothing,
        reason: 'K10: koyu kutu kalktı, logo düz zeminde',
      );
      expect(find.byType(RojMascot), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });

  testWidgets('Kurmancî onboarding sloganı doğru ve doğal görünür', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('ku'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    // 2026-09-29 doğallık: slogan satırı kaldırıldı.
    expect(find.text('Kurmancî hîn bibe, pêş bikeve.'), findsNothing);
  });
}
