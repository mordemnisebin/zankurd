import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _shell(Widget child, {bool auth = false}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      if (auth) ChangeNotifierProvider(create: (_) => AuthProvider.test()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  testWidgets('onboarding açık Ronahî yüzeyi ve ana CTA taşır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(OnboardingScreen(onComplete: () {})));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('onboarding-primary-action')),
      findsOneWidget,
    );
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('onboarding-surface')),
    );
    expect((surface.decoration as BoxDecoration).gradient, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('giriş ekranı aynı açık yüzey ailesini kullanır', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_shell(const SignInScreen(), auth: true));
    await tester.pump();

    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('sign-in-surface')),
    );
    expect((surface.decoration as BoxDecoration).gradient, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
