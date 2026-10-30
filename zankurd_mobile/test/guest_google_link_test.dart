// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-07-23 canlı UX denetimi M18: misafir hesabını Google ile devam etma.
// signInWithGoogle() anonim oturumu değiştiriyordu (ilerleme kaybı riski);
// linkGoogleAccount() Supabase'in linkIdentity PKCE akışını kullanarak
// mevcut anonim kimliği genişletir. Gerçek OAuth akışı (tarayıcı açılışı,
// deep link callback'i) widget testinde simüle edilemez — bu dosya sadece
// UI akışını (buton görünürlüğü, çağrı, hata mesajı) sahte bir
// AuthProvider ile doğrular. Gerçek cihazda "misafirken puan kazan →
// Google'a bağla → puan hâlâ duruyor mu?" senaryosu ayrıca elle
// denenmelidir (bkz. ZANKURD_LIVE_UX_REVIEW.md §7).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Misafir durumunu taklit eden ve linkGoogleAccount() çağrılarını
/// izleyen sahte AuthProvider.
class _GuestAuthProviderWithGoogleLink extends AuthProvider {
  _GuestAuthProviderWithGoogleLink({
    this.googleLinkSucceeds = true,
    this.googleErrorMessage,
  }) : super.test();

  final bool googleLinkSucceeds;
  final String? googleErrorMessage;

  bool googleLinkCalled = false;
  bool appleLinkCalled = false;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => true;

  @override
  bool get isLoading => false;

  @override
  Future<bool> linkGoogleAccount() async {
    googleLinkCalled = true;
    return googleLinkSucceeds;
  }

  @override
  Future<bool> linkAppleAccount() async {
    appleLinkCalled = true;
    return googleLinkSucceeds;
  }

  @override
  String? get errorMessage => googleLinkSucceeds ? null : googleErrorMessage;
}

class _PermanentAuthProvider extends AuthProvider {
  _PermanentAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => false;

  @override
  bool get isLoading => false;
}

Widget _wrapWithProviders(
  Widget child,
  AuthProvider authProvider, {
  bool isKu = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang(isKu ? 'ku' : 'tr'),
      ),
      ChangeNotifierProvider(create: (_) => authProvider),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _openGuestUpgradeDialog(
  WidgetTester tester, {
  bool isKu = false,
}) async {
  final label = isKu ? 'Hesabê xwe tomar bike' : 'Hesabını kaydet';
  final scrollFinder = find.byType(Scrollable).first;
  final ctaFinder = find.text(label);
  await tester.scrollUntilVisible(ctaFinder, 200, scrollable: scrollFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final ku in [false, true]) {
    testWidgets('E1/E2 hesap seçenekleri ve geçerli form bekçisi ($ku)', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          _GuestAuthProviderWithGoogleLink(),
          isKu: ku,
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester, isKu: ku);
      debugDefaultTargetPlatformOverride = null;
      final body = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(Tr.forKu(K.saveAccountBody, ku)),
      );
      expect(body, findsOneWidget);
      expect(
        tester.widget<Text>(body).style!.fontSize,
        greaterThanOrEqualTo(14),
      );
      for (final key in [K.saveAccountBody, K.saveAccountSub]) {
        expect(Tr.forKu(key, ku), contains('Apple'));
        expect(Tr.forKu(key, ku), contains('Google'));
        expect(Tr.forKu(key, ku), contains(ku ? 'e-name' : 'e-posta'));
      }
      final save = find.byKey(const ValueKey('guest-upgrade-save'));
      bool enabled() => tester.widget<FilledButton>(save).onPressed != null;
      expect(enabled(), isFalse);
      expect(find.byKey(const ValueKey('guest-upgrade-apple')), findsOneWidget);
      expect(find.byKey(const ValueKey('auth-google')), findsOneWidget);
      final fields = find.byType(TextField);
      await tester.enterText(fields.first, 'name@example.com');
      await tester.pump();
      expect(enabled(), isFalse);
      await tester.enterText(fields.last, '12345');
      await tester.pump();
      expect(enabled(), isFalse);
      await tester.enterText(fields.last, '123456');
      await tester.pump();
      expect(enabled(), isTrue);
      for (final invalid in ['', '@', 'a@', 'a@b', 'a b@example.com']) {
        await tester.enterText(fields.first, invalid);
        await tester.pump();
        expect(enabled(), isFalse, reason: invalid);
      }
      await tester.enterText(fields.first, 'name@example.com');
      await tester.pump();
      expect(enabled(), isTrue);
      await tester.enterText(fields.last, '');
      await tester.pump();
      expect(enabled(), isFalse);
      expect(tester.takeException(), isNull);
    });
  }

  group('GuestGoogleLink — buton görünürlüğü', () {
    testWidgets(
      'misafir yükseltme dialog\'unda "Google ile devam et" görünür',
      (tester) async {
        final guestAuth = _GuestAuthProviderWithGoogleLink();
        await tester.pumpWidget(
          _wrapWithProviders(
            ProfileScreen(repository: MockZanKurdRepository()),
            guestAuth,
          ),
        );
        await tester.pumpAndSettle();
        await _openGuestUpgradeDialog(tester);

        expect(find.text('Google ile devam et'), findsOneWidget);
      },
    );

    // Kusur: iOS'ta misafirin tek kalıcı yolu e-postaydı. `linkAppleAccount`
    // yazılmıştı ama hiçbir çağrı yeri yoktu; Google bağlama bu platformda
    // kapalı olduğundan Apple seçeneği hiç görünmüyordu. Sessizdi çünkü
    // eski test tam tersini ("sosyal seçenek görünmez") sabitliyordu.
    testWidgets(
      'T4 iOS misafir Google yolu gizliydi; eski bekçi gizlemeyi sabitliyordu',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final guestAuth = _GuestAuthProviderWithGoogleLink();

        await tester.pumpWidget(
          _wrapWithProviders(
            ProfileScreen(repository: MockZanKurdRepository()),
            guestAuth,
          ),
        );
        await tester.pumpAndSettle();
        await _openGuestUpgradeDialog(tester);
        debugDefaultTargetPlatformOverride = null;

        expect(find.text('Google ile devam et'), findsOneWidget);
        expect(find.text('Apple ile devam et'), findsOneWidget);
        expect(find.text('E-posta'), findsWidgets);
        final apple = find.byKey(const ValueKey('guest-upgrade-apple'));
        final google = find.byKey(const ValueKey('auth-google'));
        expect(tester.getSize(apple), tester.getSize(google));
        expect(
          tester.getTopLeft(google).dy,
          lessThan(tester.getTopLeft(find.byType(TextField).first).dy),
        );
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const ValueKey('guest-upgrade-apple')));
        await tester.pumpAndSettle();
        expect(guestAuth.appleLinkCalled, isTrue);
        expect(guestAuth.googleLinkCalled, isFalse);
      },
    );

    testWidgets('Kurmancî iOS yükseltmesinde Apple etiketi Kurmancî', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          _GuestAuthProviderWithGoogleLink(),
          isKu: true,
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester, isKu: true);
      debugDefaultTargetPlatformOverride = null;

      expect(find.text('Bi Apple re bidomîne'), findsOneWidget);
      expect(find.text('Bi Google re bidomîne'), findsOneWidget);
    });

    testWidgets('Android yükseltmesinde Apple görünmez, Google görünür', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          _GuestAuthProviderWithGoogleLink(),
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester);
      debugDefaultTargetPlatformOverride = null;

      expect(find.text('Apple ile devam et'), findsNothing);
      expect(find.text('Google ile devam et'), findsOneWidget);
    });

    testWidgets('kalıcı kullanıcıda misafir yükseltme dialog\'u hiç açılamaz', (
      tester,
    ) async {
      final permanentAuth = _PermanentAuthProvider();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          permanentAuth,
        ),
      );
      await tester.pumpAndSettle();

      // "Hesabını kaydet" satırı hiç yok, dolayısıyla "Google ile devam et"
      // seçeneği de kalıcı kullanıcıya asla gösterilmez.
      expect(find.text('Hesabını kaydet'), findsNothing);
      expect(find.text('Google ile devam et'), findsNothing);
    });
  });

  group('GuestGoogleLink — başarı akışı', () {
    testWidgets(
      '"Google ile devam et" dokunulunca linkGoogleAccount() çağrılır ve dialog kapanır',
      (tester) async {
        final guestAuth = _GuestAuthProviderWithGoogleLink();
        await tester.pumpWidget(
          _wrapWithProviders(
            ProfileScreen(repository: MockZanKurdRepository()),
            guestAuth,
          ),
        );
        await tester.pumpAndSettle();
        await _openGuestUpgradeDialog(tester);

        await tester.tap(find.text('Google ile devam et'));
        await tester.pumpAndSettle();

        expect(guestAuth.googleLinkCalled, isTrue);
        // Başarılı bağlamada hata snackbar'ı gösterilmemeli.
        expect(
          find.text('Bu Google hesabı zaten başka bir hesaba bağlı.'),
          findsNothing,
        );
      },
    );
  });

  group('GuestGoogleLink — hata akışı', () {
    testWidgets('zaten bağlı Google hesabı hatası snackbar olarak gösterilir', (
      tester,
    ) async {
      final guestAuth = _GuestAuthProviderWithGoogleLink(
        googleLinkSucceeds: false,
        googleErrorMessage: K.authErrIdentityLinked,
      );
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester);

      await tester.tap(find.text('Google ile devam et'));
      await tester.pumpAndSettle();

      expect(guestAuth.googleLinkCalled, isTrue);
      expect(
        find.text('Bu hesap zaten başka bir hesaba bağlı.'),
        findsOneWidget,
      );
    });

    testWidgets('Kurmancî arayüzde Google bağlama hatası Kurmancîye çevrilir', (
      tester,
    ) async {
      // 2026-08-14 denetimi: `_linkGoogleAccount` hatayı
      // `translateAuthError`dan geçirmeden basıyordu — Kurmancî
      // kullanıcı sunucunun Türkçe metnini görüyordu. Hemen üstteki
      // test (Türkçe arayüz) hâlâ ham Türkçe metni bekliyor —
      // `translateAuthError` Türkçe arayüzde metni değiştirmeden
      // döndürür, bu yüzden o test bu düzeltmeyle bozulmadı.
      final guestAuth = _GuestAuthProviderWithGoogleLink(
        googleLinkSucceeds: false,
        googleErrorMessage: K.authErrIdentityLinked,
      );
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
          isKu: true,
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester, isKu: true);

      await tester.tap(find.text('Bi Google re bidomîne'));
      await tester.pumpAndSettle();

      expect(guestAuth.googleLinkCalled, isTrue);
      expect(
        find.text('Bu hesap zaten başka bir hesaba bağlı.'),
        findsNothing,
        reason: 'Kurmancî arayüzde Türkçe hata metni gösterilmemeli',
      );
      expect(
        find.text('Ev hesab jixwe bi hesabekî din ve girêdayî ye.'),
        findsOneWidget,
      );
    });
  });

  group('GuestGoogleLink — hata çevirisi (AuthProvider)', () {
    test('identity_already_exists kodu anlamlı Türkçe mesaja çevrilir', () {
      final provider = AuthProvider.test();
      final message = provider.debugTranslateAuthError(
        const AuthException(
          'Identity is already linked to another user',
          code: 'identity_already_exists',
        ),
      );
      expect(message, K.authErrIdentityLinked);
    });

    test('manual_linking_disabled kodu anlamlı Türkçe mesaja çevrilir', () {
      final provider = AuthProvider.test();
      final message = provider.debugTranslateAuthError(
        const AuthException(
          'Manual linking is disabled',
          code: 'manual_linking_disabled',
        ),
      );
      expect(message, K.authErrLinkingDisabled);
    });
  });
}
