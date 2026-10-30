import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Misafir girişi başarısız olduğunda kullanıcı bunu görmeli.
///
/// 2026-07-27: uygulama ulaşılamayan bir sunucuya bağlıyken simülatörde
/// "Wek mêvan bidomîne"ye basıldı ve **hiçbir şey olmadı** — ne bekleme
/// göstergesi, ne hata. Ekranın donduğu izlenimi doğuyordu. Kod okununca
/// akış doğru görünüyordu (yükleme katmanı + hata bildirimi), yani gözle
/// bakarak karar verilemezdi: SnackBar birkaç saniyede kaybolur ve ekran
/// görüntüsü onu ıskalayabilir.
///
/// Bu yüzden davranış burada ölçülüyor: sağlayıcı başarısızlık
/// döndürdüğünde ekranda **hata metni** görünmeli. Ağa, zamanlamaya ya da
/// ekran görüntüsünün anına bağlı olmayan tek yol budur.
class _FailingGuestAuthProvider extends AuthProvider {
  _FailingGuestAuthProvider() : super.test();

  int attempts = 0;

  @override
  bool get isAuthenticated => false;

  @override
  bool get isLoading => false;

  @override
  String? get errorMessage => attempts == 0
      ? null
      : 'Bağlantı kurulamadı. İnternet bağlantını kontrol et.';

  @override
  Future<bool> signInAsGuest() async {
    attempts++;
    notifyListeners();
    return false;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('misafir girişi başarısızsa hata gösterilir', (tester) async {
    final auth = _FailingGuestAuthProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => LanguageProvider()..setLang('tr'),
          ),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const SignInScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Misafir olarak devam et'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(auth.attempts, 1, reason: 'misafir girişi hiç denenmedi');
    expect(
      find.textContaining('Bağlantı kurulamadı'),
      findsOneWidget,
      reason: 'başarısızlık kullanıcıya hiç bildirilmedi',
    );
  });
}
