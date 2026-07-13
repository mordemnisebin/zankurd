import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';

class _GateAuthProvider extends AuthProvider {
  _GateAuthProvider() : super.test();

  @override
  bool get isAuthenticated => false;

  @override
  bool get isLoading => false;
}

// Koyu-öncelikli tasarım yönü (design-direction-2026-07): uygulama
// varsayılan olarak koyu temayla açılır (kayıtlı tercih yokken). Açık
// tema ikincil ama tam desteklenir.
void main() {
  testWidgets('sıfır kurulumda onboarding koyu temayla açılır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeProvider = await ThemeProvider.load();
    expect(themeProvider.mode, ThemeMode.dark);

    await tester.pumpWidget(
      ZanKurdApp(
        repository: MockZanKurdRepository(),
        authProvider: _GateAuthProvider(),
        languageProvider: LanguageProvider()..setLang('tr'),
        themeProvider: themeProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(
      Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('kayıtlı açık tercih varsa açık temayla açılır', (tester) async {
    SharedPreferences.setMockInitialValues({'zankurd.themeMode': 'light'});
    final themeProvider = await ThemeProvider.load();
    expect(themeProvider.mode, ThemeMode.light);
  });
}
