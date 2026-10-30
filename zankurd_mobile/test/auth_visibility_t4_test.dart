import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

class _Auth extends AuthProvider {
  _Auth({this.guest = false}) : super.test();
  final bool guest;
  final calls = <String>[];
  bool succeed = false;
  bool authenticated = false;
  String? error;
  @override
  String? get errorMessage => error;
  void completeSocial() {
    authenticated = true;
    notifyListeners();
  }

  @override
  bool get isGuest => guest && !authenticated;
  @override
  bool get isAuthenticated => guest || authenticated;
  @override
  Future<bool> signInWithGoogle() async {
    calls.add('google');
    return succeed;
  }

  @override
  Future<bool> signInWithApple() async {
    calls.add('apple');
    return succeed;
  }

  @override
  Future<bool> linkGoogleAccount() async {
    calls.add('link-google');
    return false;
  }

  @override
  Future<bool> linkAppleAccount() async {
    calls.add('link-apple');
    return false;
  }

  @override
  Future<bool> signInAsGuest() async {
    calls.add('guest');
    return false;
  }
}

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    freshMockRepository();
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  Future<void> open(
    WidgetTester tester,
    Widget screen,
    _Auth auth, {
    double width = 375,
    double scale = 1,
    bool dark = false,
    bool ku = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 667);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        authProvider: auth,
        languageProvider: ku ? kurmanciLang() : turkishLang(),
        themeProvider: ThemeProvider(
          initialMode: dark ? ThemeMode.dark : ThemeMode.light,
        ),
        child: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 667),
            padding: const EdgeInsets.only(top: 20),
            textScaler: TextScaler.linear(scale),
          ),
          child: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets(
      'T4 sosyal girişler gizliydi; K10 yalnız form açılınca ölçüyordu — $platform',
      (tester) async {
        debugDefaultTargetPlatformOverride = platform;
        final auth = _Auth();
        await open(tester, const SignInScreen(), auth);
        final labels = [
          'Misafir olarak devam et',
          if (platform == TargetPlatform.iOS) 'Apple ile devam et',
          'Google ile devam et',
          'E-posta ile giriş',
        ];
        for (final label in labels) {
          expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
        }
        expect(find.byType(TextField), findsNothing);
        expect(
          tester
              .widgetList<SahneButton>(find.byType(SahneButton))
              .where((b) => b.isPrimary)
              .single
              .label,
          'Misafir olarak devam et',
        );
        final guest = tester.getRect(
          find.byKey(const ValueKey('sign-in-play-now')),
        );
        final google = tester.getRect(
          find.byKey(const ValueKey('auth-google')),
        );
        expect(guest.bottom, lessThan(google.top));
        if (platform == TargetPlatform.iOS) {
          final apple = tester.getRect(
            find.byKey(const ValueKey('auth-apple')),
          );
          expect(apple.size, google.size);
          await tester.tap(find.text('Apple ile devam et'));
          await tester.pumpAndSettle();
          expect(auth.calls, ['apple']);
        } else {
          expect(find.byKey(const ValueKey('auth-apple')), findsNothing);
        }
        await tester.tap(find.text('Google ile devam et'));
        await tester.pumpAndSettle();
        expect(auth.calls.last, 'google');
        await tester.tap(find.text('E-posta ile giriş'));
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsNWidgets(2));
        final play = find.byKey(const ValueKey('sign-in-play-now'));
        expect(tester.widget<SahneButton>(play).isPrimary, isFalse);
        await tester.ensureVisible(play);
        await tester.tap(play);
        await tester.pumpAndSettle();
        expect(auth.calls.last, 'guest');
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  for (final guest in [false, true]) {
    testWidgets(
      'T4 kayıt sosyal yolları yoktu; yalnız e-posta sınanıyordu — misafir=$guest',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final auth = _Auth(guest: guest);
        await open(tester, const SignUpScreen(), auth);
        for (final entry in [
          ('Apple ile kaydol', 'apple'),
          ('Google ile kaydol', 'google'),
        ]) {
          final button = find.text(entry.$1);
          expect(button, findsOneWidget);
          expect(
            tester.getTopLeft(button).dy,
            lessThan(tester.getTopLeft(find.byType(TextField).first).dy),
          );
          await tester.ensureVisible(button);
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(auth.calls.last, guest ? 'link-${entry.$2}' : entry.$2);
        }
        expect(find.text('Veya e-posta ile'), findsOneWidget);
        expect(find.text('Misafir olarak devam et'), findsOneWidget);
        expect(
          tester.getTopLeft(find.textContaining('Zaten hesabın var mı?')).dy,
          greaterThan(
            tester.getBottomLeft(find.text('Misafir olarak devam et')).dy,
          ),
          reason:
              'T4 misafir ve hesap girişi aynı satıra karışıyordu; eski bekçi yalnız varlığı sayıyordu',
        );
        expect(find.text('Giriş yap'), findsOneWidget);
        expect(
          tester.getSize(find.byKey(const ValueKey('auth-apple'))),
          tester.getSize(find.byKey(const ValueKey('auth-google'))),
        );
        await tester.ensureVisible(find.text('Misafir olarak devam et'));
        await tester.tap(find.text('Misafir olarak devam et'));
        await tester.pumpAndSettle();
        expect(auth.calls.where((c) => c == 'guest').length, guest ? 0 : 1);
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets(
    'T4 Android kayıt Apple yolunu açıyordu; yalnız giriş platform kapısı sınanıyordu',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await open(tester, const SignUpScreen(), _Auth());
      expect(find.text('Apple ile kaydol'), findsNothing);
      expect(find.text('Google ile kaydol'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  for (final succeeds in [false, true]) {
    testWidgets(
      'T4 kayıt OAuth başlatılınca erken kapanırdı; mevcut bekçi kayıt dönüşünü ölçmüyordu — success=$succeeds',
      (tester) async {
        final auth = _Auth()..succeed = succeeds;
        await open(
          tester,
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SignUpScreen()),
                ),
                child: const Text('kaydı aç'),
              ),
            ),
          ),
          auth,
        );
        await tester.tap(find.text('kaydı aç'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Google ile kaydol'));
        await tester.tap(find.text('Google ile kaydol'));
        await tester.pumpAndSettle();
        expect(
          find.byType(SignUpScreen),
          findsOneWidget,
          reason: 'iptal veya yalnız tarayıcı açılması kayıt ekranını kapatmaz',
        );
        if (succeeds) {
          auth.completeSocial();
          await tester.pumpAndSettle();
          expect(find.byType(SignUpScreen), findsNothing);
          expect(find.text('kaydı aç'), findsOneWidget);
        } else {
          auth.error = K.authErrNetwork;
          await tester.tap(find.text('Google ile kaydol'));
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.byType(SignUpScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  for (final screen in [const SignInScreen(), const SignUpScreen()]) {
    for (final width in [320.0, 375.0]) {
      for (final scale in [1.3, 2.0]) {
        for (final ku in [false, true]) {
          for (final dark in [false, true]) {
            testWidgets(
              'T4 dar/büyük yazı taşması; ilk görünüm ölçülmüyordu — ${screen.runtimeType} $width $scale ku=$ku dark=$dark',
              (tester) async {
                debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
                await open(
                  tester,
                  screen,
                  _Auth(),
                  width: width,
                  scale: scale,
                  ku: ku,
                  dark: dark,
                );
                expect(tester.takeException(), isNull);
                for (final key in ['auth-apple', 'auth-google']) {
                  final button = find.byKey(ValueKey(key));
                  await tester.ensureVisible(button);
                  await tester.pumpAndSettle();
                  expect(button.hitTestable(), findsOneWidget);
                }
                expect(
                  tester.getSize(find.byKey(const ValueKey('auth-apple'))),
                  tester.getSize(find.byKey(const ValueKey('auth-google'))),
                );
                expect(tester.takeException(), isNull);
                debugDefaultTargetPlatformOverride = null;
              },
            );
          }
        }
      }
    }
  }
}
