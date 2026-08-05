// 2026-07-22 canlı UX denetimi: misafir hesap yükseltme
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Misafir (isGuest = true) durumunu taklit eden sahte AuthProvider.
class _GuestAuthProvider extends AuthProvider {
  _GuestAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => true;

  @override
  bool get isLoading => false;

  bool upgradeCalled = false;
  String? lastEmail;
  String? lastPassword;

  @override
  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
  }) async {
    upgradeCalled = true;
    lastEmail = email;
    lastPassword = password;
    return true;
  }
}

/// E-posta onayı AÇIK bir projede GoTrue'nun döndürdüğü durumu taklit eder.
///
/// Yerel GoTrue v2.192.0 ile ölçüldü (2026-08-06): onay açıkken
/// `updateUser` İSTİSNA ATMAZ ama kullanıcı hâlâ `is_anonymous: true`,
/// `email: ''` ve `new_email: 'pending1@zk.test'` olarak döner. Yani
/// "başarılı" görünen bir çağrı, hesabı aslında kaydetmemiştir.
class _PendingConfirmationAuthProvider extends AuthProvider {
  _PendingConfirmationAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => true;

  @override
  bool get isLoading => false;

  @override
  bool get needsEmailConfirmation => true;

  @override
  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
  }) async => true;
}

/// Misafir olmayan (isGuest = false) sahte AuthProvider.
class _PermanentAuthProvider extends AuthProvider {
  _PermanentAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isGuest => false;

  @override
  bool get isLoading => false;
}

Widget _wrapWithProviders(Widget child, AuthProvider authProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
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

/// CTA görünür olana kadar aşağı kaydırır.
Future<void> _scrollToCta(WidgetTester tester) async {
  final scrollFinder = find.byType(Scrollable).first;
  final ctaFinder = find.text('Hesabını Kaydet');
  await tester.scrollUntilVisible(ctaFinder, 200, scrollable: scrollFinder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('GuestUpgrade — upgradeGuestAccount metodu', () {
    test(
      'AuthProvider.test() üzerinde upgradeGuestAccount çağrılabilir',
      () async {
        final provider = AuthProvider.test();
        // Mock provider'da _client null olduğu için _run() true döner.
        final result = await provider.upgradeGuestAccount(
          email: 'test@zankurd.com',
          password: 'sifre123',
        );
        expect(result, isTrue);
      },
    );
  });

  group('GuestUpgrade — profil ekranı CTA görünürlüğü', () {
    testWidgets('misafir kullanıcıya "Hesabını Kaydet" CTA gösterilir', (
      tester,
    ) async {
      final guestAuth = _GuestAuthProvider();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Hesabını Kaydet'),
        findsOneWidget,
        reason: 'Misafir kullanıcıda "Hesabını Kaydet" menü satırı görünmeli',
      );
    });

    testWidgets('kalıcı kullanıcıda "Hesabını Kaydet" CTA gösterilmez', (
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

      expect(
        find.text('Hesabını Kaydet'),
        findsNothing,
        reason: 'Kalıcı kullanıcıda "Hesabını Kaydet" menü satırı görünmemeli',
      );
    });
  });

  group('GuestUpgrade — dialog akışı', () {
    testWidgets('CTA tıklanınca e-posta/şifre dialog açılır', (tester) async {
      final guestAuth = _GuestAuthProvider();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();

      // CTA'yı görünür yap ve tıkla
      await _scrollToCta(tester);
      await tester.tap(find.text('Hesabını Kaydet'));
      await tester.pumpAndSettle();

      // Dialog açıldı — başlık ve iki form alanı
      expect(
        find.byType(TextFormField),
        findsNWidgets(2),
        reason: 'E-posta ve şifre için iki form alanı olmalı',
      );
      // Vazgeç butonu dialog'da olmalı
      expect(find.text('Vazgeç'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);
    });

    testWidgets('boş form gönderilemez — doğrulama hataları gösterilir', (
      tester,
    ) async {
      final guestAuth = _GuestAuthProvider();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();

      // CTA'yı görünür yap ve tıkla
      await _scrollToCta(tester);
      await tester.tap(find.text('Hesabını Kaydet'));
      await tester.pumpAndSettle();

      // Kaydet butonuna dokun (form boş)
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      // Doğrulama hataları görünmeli
      expect(
        find.text('Geçerli bir e-posta gir'),
        findsOneWidget,
        reason: 'Boş e-posta alanı için hata mesajı gösterilmeli',
      );
      expect(
        find.text('Parola en az 6 karakter olmalı'),
        findsOneWidget,
        reason: 'Kısa şifre için hata mesajı gösterilmeli',
      );
      // upgradeGuestAccount çağrılmamış olmalı
      expect(guestAuth.upgradeCalled, isFalse);
    });

    testWidgets('geçerli form gönderilince upgradeGuestAccount çağrılır', (
      tester,
    ) async {
      final guestAuth = _GuestAuthProvider();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          guestAuth,
        ),
      );
      await tester.pumpAndSettle();

      // CTA'yı görünür yap ve tıkla
      await _scrollToCta(tester);
      await tester.tap(find.text('Hesabını Kaydet'));
      await tester.pumpAndSettle();

      // E-posta alanını doldur
      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'test@zankurd.com');
      await tester.pumpAndSettle();

      // Şifre alanını doldur
      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, 'gizli123');
      await tester.pumpAndSettle();

      // Kaydet butonuna dokun
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(guestAuth.upgradeCalled, isTrue);
      expect(guestAuth.lastEmail, 'test@zankurd.com');
      expect(guestAuth.lastPassword, 'gizli123');

      // Başarı snackbar'ı görünmeli
      expect(
        find.text('Hesabın başarıyla kaydedildi!'),
        findsOneWidget,
        reason: 'Başarılı yükseltme sonrası başarı mesajı gösterilmeli',
      );
    });
  });

  group('GuestUpgrade — onay bekleyen yükseltme başarı sayılmıyor', () {
    testWidgets('onay açıkken "kaydedildi" DEĞİL "e-postanı doğrula" denir', (
      tester,
    ) async {
      final auth = _PendingConfirmationAuthProvider();
      await tester.pumpWidget(
        _wrapWithProviders(
          ProfileScreen(repository: MockZanKurdRepository()),
          auth,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToCta(tester);
      await tester.tap(find.text('Hesabını Kaydet'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'bekleyen@zankurd.com',
      );
      await tester.enterText(find.byType(TextFormField).last, 'gizli123');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();

      expect(
        find.text('Hesabın başarıyla kaydedildi!'),
        findsNothing,
        reason:
            'Kullanıcı hâlâ anonim ve adres yalnız onay bekliyor; '
            '"kaydedildi" demek ilerlemesinin kalıcı olduğu yalanıdır',
      );
      expect(
        find.text('Hesap oluşturuldu! Doğrulamak için e-postanı kontrol et.'),
        findsOneWidget,
      );
    });
  });
}
