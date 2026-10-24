// Bekçi: oturum kapanınca kabuğun üstündeki rotalar temizlenir (A3).
//
// ## Kusur
// Hesap silme (Ayarlar) ya da uzaktan oturum kapanması `AuthProvider`ı
// "oturumsuz"a çevirir; `AppShell` yerine `SignInScreen` çizer. Ama Ayarlar
// gibi kabuğun ÜSTÜNE itilmiş rotalar yığında kalır: kullanıcı giriş
// ekranının değil, sonsuza dek dönen bir "siliniyor" göstergesi olan Ayarlar
// sayfasının karşısındaydı.
//
// ## Niçin sessiz kalırdı
// Kabuk testleri hep oturumlu kurulur; "oturum kapanınca yığın" durumu hiçbir
// testte kurulmadı. Çökme yok, log yok — yalnız takılı bir ekran.
//
// ## Kural
// Oturumlu → oturumsuz geçişinde kabuk, kendi rotasına kadar yığını boşaltır.
// Oturumsuz kalan (hiç girmemiş) kullanıcının sonradan açtığı sayfalar
// (Kayıt ol vb.) ETKİLENMEZ: yalnız GEÇİŞ tetikler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';

import 'support/widget_test_helpers.dart';

class _ToggleAuth extends AuthProvider {
  _ToggleAuth() : super.test();

  bool authenticated = true;

  @override
  bool get isAuthenticated => authenticated;

  @override
  bool get isLoading => false;

  void setAuthenticated(bool value) {
    authenticated = value;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('oturum kapanınca kabuğun üstündeki sayfa kapanır ve giriş '
      'ekranı görünür', (tester) async {
    final auth = _ToggleAuth();
    await tester.pumpWidget(
      testShell(
        authProvider: auth,
        child: AppShell(
          repository: freshMockRepository(),
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigator = Navigator.of(tester.element(find.byType(AppShell)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('ayarlar-benzeri sayfa')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ayarlar-benzeri sayfa'), findsOneWidget);

    auth.setAuthenticated(false);
    await tester.pumpAndSettle();

    expect(find.text('ayarlar-benzeri sayfa'), findsNothing);
    expect(find.byType(SignInScreen), findsOneWidget);
  });

  testWidgets('hiç girmemiş kullanıcının açtığı sayfa kapatılmaz', (
    tester,
  ) async {
    final auth = _ToggleAuth()..authenticated = false;
    await tester.pumpWidget(
      testShell(
        authProvider: auth,
        child: AppShell(
          repository: freshMockRepository(),
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final navigator = Navigator.of(tester.element(find.byType(AppShell)));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('kayıt ekranı gibi')),
      ),
    );
    await tester.pumpAndSettle();

    auth.notifyListeners();
    await tester.pumpAndSettle();

    expect(find.text('kayıt ekranı gibi'), findsOneWidget);
  });
}
