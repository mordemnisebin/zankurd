// 2026-07-23 canlı UX denetimi M18: misafir hesabını Google ile bağlama.
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
  final label = isKu ? 'Hesabê Xwe Tomar Bike' : 'Hesabını Kaydet';
  final scrollFinder = find.byType(Scrollable).first;
  final ctaFinder = find.text(label);
  await tester.scrollUntilVisible(ctaFinder, 200, scrollable: scrollFinder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GuestGoogleLink — buton görünürlüğü', () {
    testWidgets('misafir yükseltme dialog\'unda "Google ile Bağla" görünür', (
      tester,
    ) async {
      final guestAuth = _GuestAuthProviderWithGoogleLink();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester);

      expect(find.text('Google ile Bağla'), findsOneWidget);
    });

    testWidgets('iOS misafir yükseltmesinde sosyal hesap seçeneği görünmez', (
      tester,
    ) async {
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

      expect(find.text('Google ile Bağla'), findsNothing);
      expect(find.text('E-posta'), findsWidgets);
      expect(tester.takeException(), isNull);
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

      // "Hesabını Kaydet" satırı hiç yok, dolayısıyla "Google ile Bağla"
      // seçeneği de kalıcı kullanıcıya asla gösterilmez.
      expect(find.text('Hesabını Kaydet'), findsNothing);
      expect(find.text('Google ile Bağla'), findsNothing);
    });
  });

  group('GuestGoogleLink — başarı akışı', () {
    testWidgets(
      '"Google ile Bağla" dokunulunca linkGoogleAccount() çağrılır ve dialog kapanır',
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

        await tester.tap(find.text('Google ile Bağla'));
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
        googleErrorMessage: 'Bu Google hesabı zaten başka bir hesaba bağlı.',
      );
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();
      await _openGuestUpgradeDialog(tester);

      await tester.tap(find.text('Google ile Bağla'));
      await tester.pumpAndSettle();

      expect(guestAuth.googleLinkCalled, isTrue);
      expect(
        find.text('Bu Google hesabı zaten başka bir hesaba bağlı.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'Kurmancî arayüzde Google bağlama hatası Kurmancîye çevrilir',
      (tester) async {
        // 2026-08-14 denetimi: `_linkGoogleAccount` hatayı
        // `translateAuthError`dan geçirmeden basıyordu — Kurmancî
        // kullanıcı sunucunun Türkçe metnini görüyordu. Hemen üstteki
        // test (Türkçe arayüz) hâlâ ham Türkçe metni bekliyor —
        // `translateAuthError` Türkçe arayüzde metni değiştirmeden
        // döndürür, bu yüzden o test bu düzeltmeyle bozulmadı.
        final guestAuth = _GuestAuthProviderWithGoogleLink(
          googleLinkSucceeds: false,
          googleErrorMessage: 'Bu Google hesabı zaten başka bir hesaba bağlı.',
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

        await tester.tap(find.text('Bi Google ve Girêde'));
        await tester.pumpAndSettle();

        expect(guestAuth.googleLinkCalled, isTrue);
        expect(
          find.text('Bu Google hesabı zaten başka bir hesaba bağlı.'),
          findsNothing,
          reason: 'Kurmancî arayüzde Türkçe hata metni gösterilmemeli',
        );
        expect(
          find.text('Ev hesabê Google jixwe bi hesabek din ve girêdayî ye.'),
          findsOneWidget,
        );
      },
    );
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
      expect(message, 'Bu Google hesabı zaten başka bir hesaba bağlı.');
    });

    test('manual_linking_disabled kodu anlamlı Türkçe mesaja çevrilir', () {
      final provider = AuthProvider.test();
      final message = provider.debugTranslateAuthError(
        const AuthException(
          'Manual linking is disabled',
          code: 'manual_linking_disabled',
        ),
      );
      expect(
        message,
        'Hesap bağlama şu anda kapalı. Supabase panelinde manuel bağlamayı aç.',
      );
    });
  });
}
