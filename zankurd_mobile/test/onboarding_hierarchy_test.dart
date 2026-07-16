import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';

void main() {
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

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
