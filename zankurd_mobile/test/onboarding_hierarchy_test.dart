import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

void main() {
  testWidgets('tanıtım öğrenme ve yarış değerini iki kısa adımda anlatır', (
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

    expect(find.text('Öğren'), findsOneWidget);
    expect(find.text('Sonraki'), findsOneWidget);
    expect(find.text('Başla'), findsNothing);
    expect(find.text('Yarış ve kazan'), findsNothing);

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(find.text('Yarış ve kazan'), findsOneWidget);
    expect(find.text('Başla'), findsOneWidget);
    expect(find.text('Sonraki'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
    await tester.pump();
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

  testWidgets('onboarding ilk paneli metin hiyerarşisine alan bırakır', (
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

    final hero = tester.getSize(
      find.byKey(const ValueKey('onboarding-hero-panel')),
    );
    expect(hero.height, lessThan(300));
  });

  testWidgets('onboarding her adımda ortak Forest hero kimliğini kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    LinearGradient heroGradient() {
      final hero = tester.widget<Container>(
        find.byKey(const ValueKey('onboarding-hero-panel')),
      );
      return (hero.decoration! as BoxDecoration).gradient! as LinearGradient;
    }

    expect(heroGradient().colors, AppTheme.identityHeaderGradient.colors);

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(heroGradient().colors, AppTheme.identityHeaderGradient.colors);
  });

  testWidgets('onboarding seçili adım göstergesi Forest kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang('tr'),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();

    final indicator = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('onboarding-page-indicator-0')),
    );
    final decoration = indicator.decoration! as BoxDecoration;
    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, AppTheme.identityHeaderGradient.colors);
    expect(
      decoration.boxShadow!.single.color,
      AppTheme.culturalBrandBg.withValues(alpha: 0.25),
    );
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
        expect(chip.width, lessThanOrEqualTo(72));
        expect(chip.height, lessThanOrEqualTo(64));
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

      expect(tester.widget<AppLogo>(find.byType(AppLogo)).width, 96);
      // 2026-09-10: hero artık Zana'yı köşede karşılar (eski kural
      // "onboarding'de maskot görünmez" görsel denetimle değişti).
      expect(find.byType(RojMascot), findsOneWidget);

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

    expect(find.text('Kurmancî hîn bibe, pêş bikeve.'), findsOneWidget);
  });
}
