import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

void main() {
  testWidgets('tanıtımdan tek ana eylemle devam edilir', (tester) async {
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
    expect(find.text('Başla'), findsOneWidget);
    expect(find.text('İleri'), findsNothing);
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

  testWidgets('onboarding dil düğmesi başlık alanına yayılmaz', (tester) async {
    // 518784fe (48dp a11y) Container'a hem min kısıt hem `alignment`
    // ekledi; Stack altında gevşek ama sınırlı kısıtta hizalama, kabı
    // başlık alanının tamamına yayıyor ve düğme 346x180'lik boş bir
    // panele dönüşüyordu. Ekran turu bunu görüntüledi ama hiçbir test
    // boyut ölçmediği için sessiz kaldı (2026-09-10).
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

      final toggle = tester.getSize(
        find.byKey(const ValueKey('onboarding-language-toggle')),
      );
      expect(toggle.width, lessThanOrEqualTo(72));
      expect(toggle.height, lessThanOrEqualTo(64));

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

    expect(find.text('Kurmancî hîn bibe, pêş bikeve.'), findsOneWidget);
  });
}
