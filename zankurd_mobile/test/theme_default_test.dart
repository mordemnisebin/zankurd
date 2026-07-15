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

// Uygulama ilk açılışta aydınlık ve okunabilir temayı kullanır; kullanıcı
// ana ekrandaki sabit tema düğmesinden koyuya geçebilir.
void main() {
  testWidgets('sıfır kurulumda onboarding açık temayla açılır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final themeProvider = await ThemeProvider.load();
    expect(themeProvider.mode, ThemeMode.light);

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
      Brightness.light,
    );
  });

  testWidgets('kayıtlı açık tercih varsa açık temayla açılır', (tester) async {
    SharedPreferences.setMockInitialValues({'zankurd.themeMode': 'light'});
    final themeProvider = await ThemeProvider.load();
    expect(themeProvider.mode, ThemeMode.light);
  });
}
