import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/password_recovery_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// "Parolamı unuttum" hiçbir parolayı değiştirmiyordu.
///
/// ## Kusur
///
/// `resetPassword` yalnız `resetPasswordForEmail(...)` çağırıyor ve
/// ekranda "bağlantı e-postana gönderildi" yazıyordu. Bağlantı gerçekten
/// uygulamaya dönüyor — şema hem Android manifest'inde hem iOS
/// `Info.plist`inde kayıtlı ve `Supabase.initialize` `detectSessionInUri`
/// varsayılanıyla çalıştığı için oturum da açılıyor.
///
/// Ama `AuthProvider`ın dinleyicisi YALNIZ `state.session?.user` okuyordu;
/// `state.event` hiç sorulmuyordu. Depoda `AuthChangeEvent` geçen tek bir
/// satır bile yoktu ve `UserAttributes(password: ...)` yalnız
/// `upgradeGuestAccount` içinde kullanılıyordu — yani parola değiştiren
/// bir yol hiç yoktu.
///
/// Sonuç: kullanıcı bağlantıya dokunuyor, uygulama açılıyor, doğrudan
/// Home'a düşüyor ve **parolası eski hâliyle kalıyor**. Kurtarma bir
/// kerelik girişten ibaretti; parolasını unutan kullanıcı e-posta/parola
/// girişini bir daha asla düzeltemiyordu (2026-08-06 denetimi).
///
/// ## Bekçinin tuttuğu üç şey
///
/// 1. Olay TÜRÜ okunuyor ve ayrı bir duruma dönüşüyor.
/// 2. Kurtarma tamamlanmadan normal akışa geçilmiyor — ve bu bir rota
///    değil `AppShell` build kapısı olduğu için geri tuşuyla atlanamıyor.
/// 3. Parolayı gerçekten yazan çağrı var.
class _RecoveryAuthProvider extends AuthProvider {
  _RecoveryAuthProvider() : super.test(authenticated: true);

  bool completeCalled = false;
  String? lastPassword;
  bool cancelCalled = false;
  bool succeed = true;
  String? forcedError;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => forcedError;

  @override
  Future<bool> completePasswordRecovery(String password) async {
    completeCalled = true;
    lastPassword = password;
    return succeed;
  }

  @override
  Future<void> cancelPasswordRecovery() async {
    cancelCalled = true;
  }
}

Widget _wrap(Widget child, AuthProvider auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

/// Varsayılan 800x600 test görünümünde kaydet/vazgeç düğmeleri katlamanın
/// altında kalıyor; dokunmadan önce görünür kılınmalı.
Future<void> _tapLabel(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('olay türü ayrı bir durum olarak modelleniyor', () {
    test('passwordRecovery olayı kurtarma kapısını açar', () {
      final provider = AuthProvider.test(authenticated: true);
      expect(provider.needsPasswordRecovery, isFalse);

      provider.applyAuthEvent(
        AuthChangeEvent.passwordRecovery,
        hasSession: true,
      );

      expect(
        provider.needsPasswordRecovery,
        isTrue,
        reason:
            'Kurtarma bağlantısı normal oturumdan ayırt edilmezse kullanıcı '
            'doğrudan Home\'a düşer ve parolası değişmez',
      );
    });

    test('normal giriş kurtarma kapısını AÇMAZ', () {
      final provider = AuthProvider.test(authenticated: true);
      provider.applyAuthEvent(AuthChangeEvent.signedIn, hasSession: true);
      expect(provider.needsPasswordRecovery, isFalse);
    });

    test('çıkışta bayrak düşer', () {
      final provider = AuthProvider.test(authenticated: true);
      provider.applyAuthEvent(
        AuthChangeEvent.passwordRecovery,
        hasSession: true,
      );
      provider.applyAuthEvent(AuthChangeEvent.signedOut, hasSession: false);
      expect(
        provider.needsPasswordRecovery,
        isFalse,
        reason:
            'Bayrak asılı kalırsa bir sonraki oturum sebepsiz parola '
            'ekranıyla açılır',
      );
    });

    test('token yenileme bayrağı düşürmez', () {
      // Kurtarma ekranı açıkken gelen bir token yenilemesi, kullanıcıyı
      // parolayı yazmadan içeri almamalı.
      final provider = AuthProvider.test(authenticated: true);
      provider.applyAuthEvent(
        AuthChangeEvent.passwordRecovery,
        hasSession: true,
      );
      provider.applyAuthEvent(AuthChangeEvent.tokenRefreshed, hasSession: true);
      expect(provider.needsPasswordRecovery, isTrue);
    });
  });

  group('parolayı gerçekten değiştiren çağrı', () {
    late String provider;
    late String shell;

    setUpAll(() {
      provider = File(
        'lib/src/providers/auth_provider.dart',
      ).readAsStringSync();
      shell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    });

    test('updateUser(password) çağrısı var', () {
      expect(
        provider,
        contains('UserAttributes(password: password)'),
        reason:
            'Kurtarma akışında parolayı YAZAN çağrı buydu ve hiç yoktu; '
            'olmadan bağlantı yalnız bir kerelik giriş yapar',
      );
    });

    test('kurtarma kapısı AppShell build içinde — itilmiş rota değil', () {
      expect(
        shell,
        contains('needsPasswordRecovery'),
        reason: 'Kapı yoksa kurtarma oturumu doğrudan Home\'a düşer',
      );
      expect(shell, contains('PasswordRecoveryScreen()'));
      expect(
        shell,
        isNot(contains('push(AppRoute(const PasswordRecoveryScreen()')),
        reason:
            'İtilmiş rota olsaydı geri tuşu ya da tarayıcı geri düğmesi '
            'kurtarmayı sessizce atlardı',
      );
    });

    test('kapı, oturum açıldıktan SONRA ve Home\'dan ÖNCE', () {
      final signInGate = shell.indexOf('return const SignInScreen();');
      final recoveryGate = shell.indexOf(
        'return const PasswordRecoveryScreen();',
      );
      final nameGate = shell.indexOf('ProfileNameGateScreen(');
      expect(signInGate, greaterThan(-1));
      expect(recoveryGate, greaterThan(signInGate));
      expect(
        recoveryGate,
        lessThan(nameGate),
        reason:
            'Kurtarma, ad kapısından ve Home\'dan önce gelmeli; sonra '
            'gelirse kullanıcı parolasını yazmadan uygulamayı kullanır',
      );
    });
  });

  group('kurtarma ekranı', () {
    testWidgets('kısa parola reddedilir, sunucuya gidilmez', (tester) async {
      final auth = _RecoveryAuthProvider();
      await tester.pumpWidget(_wrap(const PasswordRecoveryScreen(), auth));

      await tester.enterText(find.byType(TextField).first, '123');
      await tester.enterText(find.byType(TextField).last, '123');
      await _tapLabel(tester, 'Parolayı kaydet');

      expect(auth.completeCalled, isFalse);
      expect(find.text('Parola en az 6 karakter olmalı'), findsWidgets);
    });

    testWidgets('parolalar uyuşmazsa sunucuya gidilmez', (tester) async {
      final auth = _RecoveryAuthProvider();
      await tester.pumpWidget(_wrap(const PasswordRecoveryScreen(), auth));

      await tester.enterText(find.byType(TextField).first, 'sifre123');
      await tester.enterText(find.byType(TextField).last, 'sifre999');
      await _tapLabel(tester, 'Parolayı kaydet');

      expect(auth.completeCalled, isFalse);
      expect(find.text('Parolalar eşleşmiyor'), findsWidgets);
    });

    testWidgets('geçerli parola sunucuya yazılır', (tester) async {
      final auth = _RecoveryAuthProvider();
      await tester.pumpWidget(_wrap(const PasswordRecoveryScreen(), auth));

      await tester.enterText(find.byType(TextField).first, 'yeniSifre123');
      await tester.enterText(find.byType(TextField).last, 'yeniSifre123');
      await _tapLabel(tester, 'Parolayı kaydet');

      expect(auth.completeCalled, isTrue);
      expect(auth.lastPassword, 'yeniSifre123');
      expect(find.text('Parolan değiştirildi.'), findsOneWidget);
    });

    testWidgets('süresi geçmiş bağlantı hatası ekranda görünür', (
      tester,
    ) async {
      final auth = _RecoveryAuthProvider()
        ..forcedError = 'Bu bağlantının süresi dolmuş.';
      await tester.pumpWidget(_wrap(const PasswordRecoveryScreen(), auth));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('recovery-error')), findsOneWidget);
    });

    testWidgets('vazgeçmek oturumu kapatır — parolasız içeri bırakmaz', (
      tester,
    ) async {
      final auth = _RecoveryAuthProvider();
      await tester.pumpWidget(_wrap(const PasswordRecoveryScreen(), auth));

      await _tapLabel(tester, 'Vazgeç');

      expect(
        auth.cancelCalled,
        isTrue,
        reason:
            'Yalnız bayrağı düşürmek, parolası hâlâ eski olan bir oturumu '
            'Home\'a bırakırdı — düzeltilmek istenen durumun aynısı',
      );
    });

    testWidgets('Kurmancî metinler yerinde', (tester) async {
      final auth = _RecoveryAuthProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider()..setLang('ku'),
            ),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(create: (_) => SoundProvider()),
            ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const PasswordRecoveryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Şîfreyeke nû saz bike'), findsOneWidget);
      expect(find.text('Şîfreyê tomar bike'), findsOneWidget);
    });
  });
}
