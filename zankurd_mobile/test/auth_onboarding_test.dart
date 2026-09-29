import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
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
import 'package:zankurd_mobile/src/services/analytics_service.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

class _AppleAuthProvider extends AuthProvider {
  _AppleAuthProvider() : super.test();

  bool appleSignInCalled = false;

  @override
  Future<bool> signInWithApple() async {
    appleSignInCalled = true;
    return true;
  }
}

class _GoogleAuthProvider extends AuthProvider {
  _GoogleAuthProvider() : super.test();

  bool googleSignInCalled = false;

  @override
  Future<bool> signInWithGoogle() async {
    googleSignInCalled = true;
    return true;
  }
}

/// 2026-09-29 Şahnê: giriş, kayıt ve oyuncu adı kahramanları ortak kimliği
/// eski Forest gradyanıyla değil Şahnê sahne zeminiyle taşır: gece
/// degradesi + Zimrût (öğrenme) köşe radyali ([SahneStagePainter]). Korunan
/// kural aynı: üç giriş yüzeyi AYNI kimliği paylaşır.
void _expectLearnStageIdentity(WidgetTester tester, Finder hero) {
  expect(hero, findsOneWidget);
  final painters = tester
      .widgetList<CustomPaint>(
        find.descendant(
          of: hero,
          matching: find.byType(CustomPaint),
          matchRoot: true,
        ),
      )
      .map((p) => p.painter)
      .whereType<SahneStagePainter>()
      .toList();
  expect(painters, isNotEmpty, reason: 'kahraman sahne zemini taşımalı');
  expect(painters.first.race, isFalse);
  expect(painters.first.glow, SahneTokens.night.roleGlow(SahneRole.learn));
}

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

  testWidgets('giriş ekranı resmî ZanKurd sloganını kullanır', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: const SignInScreen(),
        authProvider: GateAuthProvider(),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kurmancî hîn bibe, pêş bikeve.'), findsOneWidget);
    expect(find.textContaining('pêşbirkê bike'), findsNothing);
  });

  testWidgets('giriş hero alanı ortak Forest kimlik gradientini kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();

    _expectLearnStageIdentity(
      tester,
      find.byKey(const ValueKey('sign-in-hero-banner')),
    );
  });

  // 2026-09-29 Şahnê: dil seçici seçim rayının sığan çeşididir; seçili çip
  // eskiden Forest gradyanı + gölge taşıyordu. Korunan şey: etkin dil
  // görünür biçimde (ton + Halka 2) ve ekran okuyucuda seçili.
  testWidgets('giriş dil seçimi aktif dili seçili çiple gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: const SignInScreen(),
        authProvider: GateAuthProvider(),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pumpAndSettle();

    final chipFinder = find.byKey(const ValueKey('sign-in-language-chip-KU'));
    expect(chipFinder, findsOneWidget);
    final chip = tester.widget<SahneRailChip>(
      find.descendant(of: chipFinder, matching: find.byType(SahneRailChip)),
    );
    expect(chip.selected, isTrue);
    final other = tester.widget<SahneRailChip>(
      find.descendant(
        of: find.byKey(const ValueKey('sign-in-language-chip-TR')),
        matching: find.byType(SahneRailChip),
      ),
    );
    expect(other.selected, isFalse);
    expect(
      tester
          .getSemantics(chipFinder)
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toString(),
      'Tristate.isTrue',
    );
  });

  testWidgets('kayıt hero alanı ortak Forest kimlik gradientini kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: const SignUpScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();

    _expectLearnStageIdentity(
      tester,
      find.byKey(const ValueKey('sign-up-hero-banner')),
    );
  });

  testWidgets('kayıt ilerleme göstergesi aktif adımda Forest kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(child: const SignUpScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();

    final stepFinder = find.byKey(const ValueKey('signup-progress-step-1'));
    expect(stepFinder, findsOneWidget);
    // 2026-09-29 Şahnê: aktif adım Forest gradyanı + gölge değil, öğrenme
    // rolüdür: Zimrût tonu + Halka 2 Zimrût metni (elmas); pasif adım
    // Kulis. Gölge yok. Korunan kural: aktif adım öğrenme kimliğini taşır
    // ve pasiften ayrılır.
    final step = tester.widget<AnimatedContainer>(stepFinder);
    final decoration = step.decoration! as ShapeDecoration;
    final t = SahneTokens.of(tester.element(stepFinder));
    expect(decoration.color, t.learnTint);
    expect((decoration.shape as BeveledRectangleBorder).side.color, t.learnTx);
    expect(decoration.shadows ?? const <BoxShadow>[], isEmpty);
    final inactive = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('signup-progress-step-2')),
    );
    expect((inactive.decoration! as ShapeDecoration).color, t.s2);
  });

  testWidgets('oyuncu adı hero alanı ortak Forest kimliğini kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: repository,
          onCompleted: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    _expectLearnStageIdentity(
      tester,
      find.byKey(const ValueKey('profile-name-gate-hero-surface')),
    );
  });

  testWidgets('iOS giriş ekranı Google ve Apple seçeneklerini sunar', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;

    expect(find.text('Google ile giriş yap'), findsOneWidget);
    expect(find.text('Apple ile giriş yap'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
    expect(find.text('Veya e-posta ile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desteklenen giriş ekranında Apple seçeneği görünür ve akışı başlatır',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final authProvider = _AppleAuthProvider();
      await tester.pumpWidget(
        testShell(child: const SignInScreen(), authProvider: authProvider),
      );
      await tester.pumpAndSettle();

      final appleButton = find.text('Apple ile giriş yap');
      expect(appleButton, findsOneWidget);

      await tester.tap(appleButton);
      await tester.pumpAndSettle();

      debugDefaultTargetPlatformOverride = null;
      expect(authProvider.appleSignInCalled, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OAuth tarayıcı açılışı tamamlanmış login olarak ölçülmez', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);

    final loginMethods = <String>[];
    AnalyticsService.instance.debugEventSink = (name, parameters) {
      if (name == 'login') {
        loginMethods.add(parameters?['method']?.toString() ?? '');
      }
    };
    addTearDown(() => AnalyticsService.instance.debugEventSink = null);

    // Bu fake, dış OAuth gibi yalnız başlatma başarısını döndürür;
    // AuthProvider.test() authenticated hâle gelmez.
    final authProvider = _AppleAuthProvider();
    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: authProvider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Apple ile giriş yap'));
    await tester.pumpAndSettle();

    debugDefaultTargetPlatformOverride = null;
    expect(authProvider.appleSignInCalled, isTrue);
    expect(authProvider.isAuthenticated, isFalse);
    expect(loginMethods, isEmpty);
  });

  testWidgets(
    'Google OAuth tarayıcı açılışı tamamlanmış login olarak ölçülmez',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final loginMethods = <String>[];
      AnalyticsService.instance.debugEventSink = (name, parameters) {
        if (name == 'login') {
          loginMethods.add(parameters?['method']?.toString() ?? '');
        }
      };
      addTearDown(() => AnalyticsService.instance.debugEventSink = null);

      final authProvider = _GoogleAuthProvider();
      await tester.pumpWidget(
        testShell(child: const SignInScreen(), authProvider: authProvider),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Google ile giriş yap'));
      await tester.pumpAndSettle();

      debugDefaultTargetPlatformOverride = null;
      expect(authProvider.googleSignInCalled, isTrue);
      expect(authProvider.isAuthenticated, isFalse);
      expect(loginMethods, isEmpty);
    },
  );

  testWidgets('auth alanları ve parola görünürlük eylemi adlandırılır', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    expect(tester.getSemantics(fields.at(0)).label, 'E-posta adresi');
    expect(tester.getSemantics(fields.at(1)).label, 'Parola');
    expect(find.bySemanticsLabel('Parolayı göster'), findsOneWidget);
    expect(find.bySemanticsLabel('Parolayı unuttun mu?'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('giriş ve onboarding resmi ZanKurd logosunu kullanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: const SignInScreen(), authProvider: GateAuthProvider()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppLogo), findsOneWidget);

    await tester.pumpWidget(
      testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AppLogo), findsOneWidget);
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

        // Misafir bağlantısı context yüzeyi kullanır: light'ta koyu metin,
        // dark'ta açık metin.
        //
        // 2026-07-25: misafir eylemi tam boy konturlu butondan metin
        // bağlantısına indirildi (Google beyaz + Apple siyah + misafir
        // turuncu = ekranda üç birincil eylem görünüyordu). Bağlantı rengi
        // artık hafif saydam olduğu için `== Colors.white` kimlik
        // karşılaştırması kırılıyordu; testin asıl iddiası okunabilirlik,
        // o yüzden parlaklıkla ölçülür.
        final guestLabel = tester.widget<Text>(
          find.text('Misafir olarak devam et'),
        );
        final guestLuminance = guestLabel.style?.color?.computeLuminance() ?? 0;
        if (mode == ThemeMode.light) {
          expect(guestLuminance, lessThan(0.4));
        } else {
          expect(guestLuminance, greaterThan(0.6));
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
      expect(find.text('Oyuna başla'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('oyuncu adı ekranı doğal Kurmancî yönlendirme gösterir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: ProfileNameGateScreen(
          repository: repository,
          onCompleted: () {},
        ),
        languageProvider: kurmanciLang(),
      ),
    );
    await tester.pumpAndSettle();

    // 2026-09-27: eski karşılama alt yazısı ("Hîn bibe, pêş bikeve û bi
    // hevalên xwe re kêf bike.") ekrandan kaldırıldı — tanıtım turu ve
    // giriş ekranı aynı şeyi zaten iki kez söylemişti, burada üçüncü kez
    // tekrarı yalnız oyalıyordu (bkz. profile_name_gate_screen.dart build()
    // notu). Bu testin asıl iddiası (ekran doğal Kurmancî gösterir) artık
    // kalan tek soru üzerinden sınanır.
    expect(find.text('Navê te di lîstikê de çi be?'), findsOneWidget);
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
    expect(find.text('Günün Etkinliği'), findsNothing);
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

    expect(find.byType(AppLogo), findsOneWidget);
    final logoCenter = tester.getCenter(find.byType(AppLogo));
    expect(logoCenter.dx, closeTo(195, 4));
    expect(find.text('Atla'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('onboarding-age-gate')));
    await tester.pump();
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

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Başla')).dy,
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

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Başla')).dy,
      lessThanOrEqualTo(844),
    );
    expect(tester.takeException(), isNull);

    // 2026-09-29 Şahnê: varsayılan tema GECE (Şahnê "Gece sahnesi";
    // `ThemeProvider` varsayılanı `ThemeMode.dark`). Eski "açık tema
    // varsayılan" (Pirs hizası) sözleşmesi kalktı. Korunan kural: tanıtım
    // yüzeyi düz sayfa zeminidir (degrade değil) ve temanın `bg`sidir.
    final onboardingTheme = Theme.of(
      tester.element(find.byType(OnboardingScreen)),
    );
    expect(onboardingTheme.brightness, Brightness.dark);
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('onboarding-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.gradient, isNull);
    expect(
      decoration.color,
      SahneTokens.of(tester.element(find.byType(OnboardingScreen))).bg,
    );
  });

  testWidgets('iPhone SE accessibility XXXL onboarding stays in viewport', (
    tester,
  ) async {
    const size = Size(375, 667);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      testShell(
        languageProvider: kurmanciLang(),
        child: MediaQuery(
          data: const MediaQueryData(
            size: size,
            // ZanKurdApp production kökü sistem XXXL ölçeğini 2.0'a clamp
            // ediyor. Burada 3.0 kullanmak gerçek iPhone SE geometrisini
            // temsil etmiyor ve header çakışmasını gizliyordu.
            textScaler: TextScaler.linear(2),
          ),
          child: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = tester.getRect(
      find.byKey(const ValueKey('onboarding-surface')),
    );
    final logo = find.byType(AppLogo);
    final skip = find.text('Derbas bike');
    final header = find.byKey(const ValueKey('onboarding-header'));
    final topControls = find.byKey(
      const ValueKey('onboarding-accessibility-top-controls'),
    );
    final accessibilityBrand = find.byKey(
      const ValueKey('onboarding-accessibility-brand'),
    );
    expect(logo, findsOneWidget);
    expect(skip, findsOneWidget);
    expect(header, findsOneWidget);
    expect(topControls, findsOneWidget);
    expect(accessibilityBrand, findsOneWidget);
    expect(
      tester.getSize(topControls).height +
          tester.getSize(accessibilityBrand).height,
      lessThanOrEqualTo(tester.getSize(header).height),
      reason:
          'XXXL başlıkta üst kontroller ile marka aynı header yüksekliğine '
          'çakışmadan sığmalı.',
    );
    expect(find.text('Kurmancî hîn bibe, pêş bikeve.'), findsNothing);
    for (final finder in [
      find.text('Hîn bibe'),
      find.byKey(const ValueKey('onboarding-age-gate')),
      find.text('Bidomîne'),
    ]) {
      expect(finder, findsOneWidget);
      final rect = tester.getRect(finder);
      expect(rect.left, greaterThanOrEqualTo(surface.left));
      expect(rect.right, lessThanOrEqualTo(surface.right));
      expect(rect.top, greaterThanOrEqualTo(surface.top));
      expect(rect.bottom, lessThanOrEqualTo(surface.bottom));
    }

    final ageGate = tester.getRect(
      find.byKey(const ValueKey('onboarding-age-gate')),
    );
    final cta = tester.getRect(find.text('Bidomîne'));
    expect(ageGate.bottom, lessThanOrEqualTo(cta.top));

    // Metin bandı kısa içerikte ortalanır, taşan içerikte aşağıdan kayar
    // (`ConstrainedBox(minHeight)` + `Column(mainAxisSize: min)`,
    // 2026-09-25 SE düzeltmesi). Sözleşme widget tipi değil davranış:
    // günlük ders maddesi kaydırarak görünür hale gelmeli.
    final pageScroll = find.byType(SingleChildScrollView);
    final dailyBullet = find.text('Dersa rojane: bê dem, bi şîroveyê');
    final pageScrollable = find.descendant(
      of: pageScroll,
      matching: find.byType(Scrollable),
    );
    expect(pageScroll, findsOneWidget);
    expect(pageScrollable, findsOneWidget);
    expect(dailyBullet, findsOneWidget);
    final beforeScrollY = tester.getTopLeft(dailyBullet).dy;
    await tester.scrollUntilVisible(
      dailyBullet,
      180,
      scrollable: pageScrollable,
    );
    final afterScrollY = tester.getTopLeft(dailyBullet).dy;
    final scrollRect = tester.getRect(pageScroll);
    final dailyRect = tester.getRect(dailyBullet);
    expect(afterScrollY, lessThan(beforeScrollY));
    expect(dailyRect.top, greaterThanOrEqualTo(scrollRect.top));
    expect(dailyRect.bottom, lessThanOrEqualTo(scrollRect.bottom));
    expect(tester.takeException(), isNull);
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

    await tester.tap(find.text('Sonraki'));
    await tester.pumpAndSettle();

    expect(find.text('Başla'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Başla')).dy,
      lessThanOrEqualTo(800),
    );
    expect(tester.takeException(), isNull);
    // 2026-09-29 Şahnê: varsayılan tema gece (bkz. telefon testi).
    expect(
      Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
      Brightness.dark,
    );
  });

  testWidgets('app logo renders yuksek kalite image filtering ile', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo(width: 160))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    final assetName = provider is ResizeImage
        ? (provider.imageProvider as AssetImage).assetName
        : (provider as AssetImage).assetName;
    expect(assetName, 'assets/zankurd.webp');
    expect(image.filterQuality, FilterQuality.high);
    expect(image.isAntiAlias, isTrue);
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
    // Ana ekranın tek birincil eylemi günün dersidir.
    expect(find.text('Günün dersi'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-duel-row')), findsNothing);

    // 2026-09-27: yarış kapısı ilk oturumdan itibaren ana ekrandadır ve
    // ayrı bir ekran değil, alt menüdeki Yarış sekmesinin kendisini açar —
    // aynı yere giden iki farklı yüzey oluşmaz.
    final playDoor = find.byKey(const ValueKey('home-door-play'));
    await tester.ensureVisible(playDoor);
    await tester.pumpAndSettle();
    await tester.tap(playDoor);
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubScreen), findsOneWidget);
  });

  testWidgets('home header is compact and exposes account quick controls', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
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
    //
    // 2026-07-25 denetimi: sunucu varsayılanı "ZanKurd Oyuncusu" ana ekranda
    // "ZanKurd", profil ekranında "Lîstikvanê ZanKurd" oluyordu — aynı
    // oturumda iki kimlik. Artık her iki ekran da [PlayerIdentity] üzerinden
    // tek bir yedeğe düşer.
    expect(find.text('Hoş geldin, Oyuncu!'), findsOneWidget);
    expect(find.text('Seviye 5'), findsNothing);
    expect(find.byIcon(Icons.diamond), findsNothing);
    expect(
      find.byKey(const ValueKey('home-zana')),
      findsNothing,
      reason: 'Ana başlık yetişkin ürün kimliğinde maskot hero taşımamalı.',
    );

    // Ana ekranın üst bölümü günlük görevin önüne geçen ikinci bir hero olmaz.
    final header = find.byKey(const ValueKey('home-profile-header'));
    expect(header, findsOneWidget);
    expect(
      tester.getSize(header).height,
      lessThanOrEqualTo(150),
      reason: 'Profil/seri araçları kompakt hesap başlığı içinde kalmalı.',
    );
    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
    // "Yarış" sekme etiketi tektir; ana ekrandaki yarış kapısı kendi
    // başlığını ("Arkadaşınla yarış") taşır.
    expect(find.text('Yarış'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);

    // Tema düğmesi 2026-09-27'de başlıktan kalktı (güneş simgesi ayar
    // çarkıyla karışıyordu); tema Ayarlar'da.
    expect(find.byKey(const ValueKey('home-theme-toggle')), findsNothing);
    for (final key in const [ValueKey('home-language-toggle')]) {
      final control = find.byKey(key);
      expect(tester.getSize(control).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(control)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
      );
    }
    final storeBadge = find.bySemanticsLabel(
      RegExp(r'^Mağaza.*\d+.*jeton$', caseSensitive: false),
    );
    expect(
      storeBadge,
      findsOneWidget,
      reason: 'Bakiye görünüyorsa ekran okuyucu da miktarı duymalı.',
    );
    expect(
      tester
          .getSemantics(storeBadge)
          .getSemanticsData()
          .hasAction(ui.SemanticsAction.tap),
      isTrue,
    );

    // 2026-09-29 Şahnê: alt gezinmenin görünüşü tümüyle temadandır
    // (`navigationBarTheme`: 64 yükseklik, `nav` zemini, seçili sekme Ray
    // plaketi). Turuncu gösterge kalktı: Agir ekranın tek birincil eylemidir,
    // gezinme değil. Korunan kural: seçili gösterge sekmeyle değişmez.
    final navContext = tester.element(find.byType(NavigationBar));
    final t = SahneTokens.of(navContext);
    final navTheme = Theme.of(navContext).navigationBarTheme;
    expect(navTheme.height, 64);
    expect(navTheme.backgroundColor, t.nav);
    expect(navTheme.indicatorColor, t.s3);
    expect(navTheme.indicatorColor, isNot(t.act));

    // Alt nav'daki "Yarış" — lobi kartıyla karışmasın.
    await tester.tap(find.byKey(const ValueKey('nav-play')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayHubScreen), findsOneWidget);

    // Bottom nav seçili rengi sekmeyle değişmez.
    final navThemeAfter = Theme.of(
      tester.element(find.byType(NavigationBar)),
    ).navigationBarTheme;
    expect(navThemeAfter.indicatorColor, t.s3);
    semantics.dispose();
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

    // 2026-09-29 Şahnê: varsayılan tema GECE (eski "açık tema varsayılan"
    // Pirs hizası kalktı). Korunan kural: tema düğmesi görünen sayfa
    // zeminini değiştirir; zemin düz renktir (2026-07-24: gradyan zemin
    // kartların 1 px kenarlığını yutuyordu).
    Color homeBg() {
      final page = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(HomeScreen),
              matching: find.byType(Material),
            )
            .first,
      );
      return page.color!;
    }

    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.dark,
    );
    expect(homeBg(), SahneTokens.night.bg);

    theme.toggleDarkLight();
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.light,
    );
    expect(homeBg(), SahneTokens.day.bg);
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
    expect(find.text('Günün dersi'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('player-name-field')),
      'Rojda Test',
    );
    await tester.tap(find.text('Oyuna başla'));
    await tester.pumpAndSettle();

    expect(repository.savedName, 'Rojda Test');
    expect(find.text('Günün dersi'), findsOneWidget);
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
    final beforeDragY = tester.getTopLeft(guestButton).dy;

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    final afterDragY = tester.getTopLeft(guestButton).dy;
    expect(afterDragY, lessThan(beforeDragY - 100));
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

  testWidgets('iPhone SE landscape XXXL auth form stays reachable', (
    tester,
  ) async {
    const size = Size(667, 375);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      testShell(
        authProvider: GateAuthProvider(),
        languageProvider: kurmanciLang(),
        child: const MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(2)),
          child: SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final pageScroll = find.byType(SingleChildScrollView);
    final pageScrollable = find.descendant(
      of: pageScroll,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Scrollable && widget.axisDirection == AxisDirection.down,
      ),
    );
    expect(pageScroll, findsOneWidget);
    expect(pageScrollable, findsOneWidget);

    final scrollRect = tester.getRect(pageScroll);
    for (final label in [
      'Navnîşana e-nameyê',
      'Şîfre',
      'Şîfre ji bîr kir?',
      'Têkeve',
      'Tomar bibe',
    ]) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: label);
      await tester.scrollUntilVisible(finder, 220, scrollable: pageScrollable);
      final rect = tester.getRect(finder);
      expect(rect.top, greaterThanOrEqualTo(scrollRect.top), reason: label);
      expect(rect.bottom, lessThanOrEqualTo(scrollRect.bottom), reason: label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPad erişilebilirlik XXXL auth etiketlerini kesmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(744, 1133));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        authProvider: GateAuthProvider(),
        languageProvider: kurmanciLang(),
        child: const MediaQuery(
          data: MediaQueryData(
            size: Size(744, 1133),
            textScaler: TextScaler.linear(3),
          ),
          child: SignInScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final label in ['Wek mêvan bidomîne', 'An jî bi e-nameyê']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget, reason: label);
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: '$label erişilebilirlik metin ölçeğinde ellipsis olmamalı',
      );
    }
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
