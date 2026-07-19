import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  test('language provider persists selected language', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = await LanguageProvider.load();
    expect(provider.lang, 'ku');

    provider.setLang('tr');

    final restored = await LanguageProvider.load();
    expect(restored.lang, 'tr');
  });

  testWidgets('shows auth screen before guest sign in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: GateAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'auth alternative buttons stay readable on their own backgrounds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        // KeyedSubtree: provider create'leri her temada yeniden çalışsın.
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey(mode),
            child: testShell(
              child: const SignInScreen(),
              authProvider: GateAuthProvider(),
              themeProvider: ThemeProvider(initialMode: mode),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Google butonu: iki temada da beyaz dolgu -> koyu metin.
        final googleLabel = tester.widget<Text>(
          find.text('Google ile giriş yap'),
        );
        expect(googleLabel.style?.color?.computeLuminance(), lessThan(0.3));

        // Misafir butonu context yüzeyi kullanır: light'ta koyu metin,
        // dark'ta beyaz metin.
        final guestLabel = tester.widget<Text>(
          find.text('Misafir olarak devam et'),
        );
        final guestLuminance = guestLabel.style?.color?.computeLuminance() ?? 0;
        if (mode == ThemeMode.light) {
          expect(guestLuminance, lessThan(0.4));
        } else {
          expect(guestLabel.style?.color, equals(Colors.white));
        }
      }
    },
  );

  testWidgets('auth alternative buttons ignore taps while loading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authProvider = GateAuthProvider();
    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: authProvider),
    );
    await tester.pumpAndSettle();

    authProvider.isLoadingForTest = true;
    await tester.pump();

    // isLoading true iken onPressed null'a düşer; IgnorePointer bu durumda
    // butonu tamamen hit-test dışı bırakmalı (yalnızca InkWell'in örtük
    // null-onTap davranışına güvenmemeli). Bulunamaması bunun kanıtıdır.
    expect(find.text('Misafir olarak devam et').hitTestable(), findsNothing);

    authProvider.isLoadingForTest = false;
    await tester.pump();

    // Yükleme bitince buton tekrar normal çalışmalı (regresyon önlemi).
    await tester.tap(find.text('Misafir olarak devam et').hitTestable());
    await tester.pumpAndSettle();

    expect(authProvider.isAuthenticated, isTrue);
  });

  testWidgets('auth form text stays readable in light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      // KeyedSubtree: provider create'leri her temada yeniden çalışsın.
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey(mode),
          child: testShell(
            child: const SignInScreen(),
            authProvider: GateAuthProvider(),
            themeProvider: ThemeProvider(initialMode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // E-posta formu artık genişleyen bölümde; önce aç (tasarım: tek
      // birincil CTA = Google, form varsayılan kapalı).
      await tester.tap(find.text('Veya e-posta ile'));
      await tester.pumpAndSettle();

      // Renkli welcome banner başlığı iki temada da beyaz kalır.
      final title = tester.widget<Text>(find.text('ZanKurd\'a Hoş Geldin'));
      expect(title.style?.color?.computeLuminance(), greaterThan(0.75));

      // Form etiketi temayla birlikte renk değiştirir; sabit beyaz olmamalı.
      final emailLabel = tester.widget<Text>(find.text('E-posta adresi'));
      final labelLuminance = emailLabel.style?.color?.computeLuminance() ?? 0;
      if (mode == ThemeMode.light) {
        expect(labelLuminance, lessThan(0.3));
      } else {
        expect(labelLuminance, greaterThan(0.6));
      }

      expect(find.text('Misafir olarak devam et'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sign up and name gate stay readable in light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      // KeyedSubtree: provider create'leri her temada yeniden çalışsın.
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('signup-$mode'),
          child: testShell(
            child: const SignUpScreen(),
            authProvider: GateAuthProvider(),
            themeProvider: ThemeProvider(initialMode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hesabını oluştur'), findsOneWidget);
      expect(find.text('İleri'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('name-gate-$mode'),
          child: testShell(
            child: ProfileNameGateScreen(
              repository: repository,
              onCompleted: () {},
            ),
            themeProvider: ThemeProvider(initialMode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('player-name-field')), findsOneWidget);
      expect(find.text('Oyuna Başla'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('guest sign in is reachable in the first mobile auth viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: GateAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    final guestButton = find.text('Misafir olarak devam et');
    expect(guestButton, findsOneWidget);
    expect(tester.getBottomRight(guestButton).dy, lessThan(844));
  });

  testWidgets('default mock auth starts signed out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(repository: repository, languageProvider: turkishLang()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsNothing);
  });

  testWidgets('first launch shows onboarding before auth screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: GateAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    // Marka artık metin yerine logo görseliyle gösteriliyor.
    expect(find.byType(AppLogo), findsOneWidget);
    final logoCenter = tester.getCenter(find.byType(AppLogo));
    expect(logoCenter.dx, closeTo(195, 4));
    expect(find.text('Atla'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('zankurd.onboarding.seen'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('onboarding fits a landscape phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonraki'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Sonraki')).dy,
      lessThanOrEqualTo(390),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding fits a portrait phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonraki'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Sonraki')).dy,
      lessThanOrEqualTo(844),
    );
    expect(tester.takeException(), isNull);

    // Koyu tema varsayılan sözleşmesi (2026-07-17 mockup sistemi).
    expect(
      Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
      Brightness.dark,
    );
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('onboarding-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.bg);
  });

  testWidgets('onboarding fits a tablet and web viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Sonraki'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Sonraki')).dy,
      lessThanOrEqualTo(800),
    );
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('app logo uses high quality image filtering', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo(width: 160))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.filterQuality, FilterQuality.high);
  });

  testWidgets('auth screen asks for language before sign in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: GateAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KU'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);

    await tester.tap(find.text('KU'));
    await tester.pumpAndSettle();

    expect(find.text('Bi xêr hatî ZanKurdê'), findsOneWidget);
  });

  testWidgets('guest sign in opens the app shell', (tester) async {
    final authProvider = GateAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: authProvider,
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Misafir olarak devam et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Misafir olarak devam et'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Günün Dersi'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('home-play-teaser')));
    await tester.pumpAndSettle();
    expect(find.text('Hemen oyna'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-play-teaser')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubScreen), findsOneWidget);
  });

  testWidgets('home header exposes language and theme quick controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    // Selamda yalnız adın ilk kelimesi kullanılır (uzun ad kırpılmasın).
    expect(find.text('Hoş geldin, ZanKurd!'), findsOneWidget);
    expect(find.text('Seviye 5'), findsNothing);
    expect(find.byIcon(Icons.diamond), findsNothing);

    // Pirs/mockup-3 sözleşmesi: ince karşılama satırı; kalın gradyan banner yok.
    expect(find.byKey(const ValueKey('home-profile-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-lesson')), findsOneWidget);
    expect(find.text('Yarış'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    final navTheme = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );
    expect(navTheme.data.height, 68);
    expect(navTheme.data.backgroundColor, AppTheme.surface);
    expect(
      navTheme.data.indicatorColor,
      AppTheme.brandGreen.withValues(alpha: 0.22),
    );

    await tester.tap(find.text('Yarış'));
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubScreen), findsOneWidget);

    // Bottom nav seçili rengi sekmeyle değişmez; sabit brandGreen kalır.
    final navThemeAfter = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );
    expect(
      navThemeAfter.data.indicatorColor,
      AppTheme.brandGreen.withValues(alpha: 0.22),
    );
  });

  testWidgets('theme toggle changes visible home surface colors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = ThemeProvider();
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
        themeProvider: theme,
      ),
    );
    await tester.pumpAndSettle();

    // Koyu tema varsayılan sözleşmesi (2026-07-17 mockup sistemi).
    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.dark,
    );
    final home = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = home.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors.first, AppTheme.bg);

    theme.toggleDarkLight();
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.light,
    );
  });

  testWidgets('auth requires player name before home', (tester) async {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
    final repository = NeedsNameRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oyundaki adın ne olsun?'), findsOneWidget);
    expect(find.text('Günün Dersi'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('player-name-field')),
      'Rojda Test',
    );
    await tester.tap(find.text('Oyuna Başla'));
    await tester.pumpAndSettle();

    expect(repository.savedName, 'Rojda Test');
    expect(find.text('Günün Dersi'), findsOneWidget);
  });

  test('unsupported provider auth error is user friendly', () {
    final provider = AuthProvider.test();

    final message = provider.debugTranslateAuthError(
      const AuthException(
        'validation_failed: Unsupported provider is not enabled',
        statusCode: '400',
      ),
    );

    expect(
      message,
      'Google girişi şu anda etkin değil. Supabase panelinde Google sağlayıcısını aç.',
    );
  });

  test('network auth error points to connection or DNS', () {
    final provider = AuthProvider.test();

    final message = provider.debugTranslateUnexpectedAuthError(
      Exception('ClientException: Failed host lookup'),
    );

    expect(message, 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.');
  });

  test('network auth exception points to connection or DNS', () {
    final provider = AuthProvider.test();

    final message = provider.debugTranslateAuthError(
      const AuthException('net::ERR_NAME_NOT_RESOLVED'),
    );

    expect(message, 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.');
  });

  testWidgets('landscape auth actions can be scrolled into view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();

    final guestButton = find.text('Misafir olarak devam et');
    expect(guestButton, findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(tester.getBottomRight(guestButton).dy, lessThan(390));
  });

  testWidgets('landscape auth keeps guest action in the first viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();

    final guestButton = find.text('Misafir olarak devam et');
    expect(guestButton, findsOneWidget);
    expect(tester.getBottomRight(guestButton).dy, lessThan(390));
  });

  testWidgets('language toggle works on the auth screen', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: GateAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('KU'));
    await tester.pumpAndSettle();

    expect(find.text('Bi xêr hatî ZanKurdê'), findsOneWidget);
    expect(find.text('Wek mêvan bidomîne'), findsOneWidget);
  });
}
