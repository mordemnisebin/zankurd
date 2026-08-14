import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'package:zankurd_mobile/src/widgets/legal_links.dart';

import 'support/widget_test_helpers.dart';

/// KVKK/gizlilik bağlantısı açılamazsa kullanıcı hiçbir şey görmüyordu.
///
/// ## Kusur
///
/// `LegalLinksRow._open` yalnız `launchUrl`ı bir `try/catch` içinde
/// çağırıyordu; `catch` yalnız `ErrorReporter.record` yapıyordu (görünmez
/// bir telemetri). Kullanıcı KVKK/gizlilik bağlantısına dokunuyor, cihazda
/// hedefi açacak bir uygulama yoksa (`launchUrl` bu durumda İSTİSNA
/// FIRLATMAZ, yalnız `false` döner — bu okunmuyordu bile) hiçbir görünür
/// sonuç doğmuyordu; asıl istisna yolu da yalnız Crashlytics'e gidiyordu.
/// Kullanıcı dokunuşun işe yarayıp yaramadığını hiçbir zaman bilemiyordu
/// (2026-08-14 denetimi).
///
/// ## Bekçi
///
/// `UrlLauncherPlatform.instance`, cihazda hedefi açacak bir uygulama
/// bulunamadığını simüle eden sahte bir uygulamayla değiştirilir. Gerçek
/// bir tarayıcı açmadan (bu test sahte olmasaydı CI'da bir sekme açardı)
/// düzeltmenin GÖRÜNÜR sonucu doğrulanır.
void main() {
  late UrlLauncherPlatform original;

  setUp(() {
    original = UrlLauncherPlatform.instance;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = original;
  });

  testWidgets('bağlantı açılamayınca görünür bir SnackBar çıkar', (
    tester,
  ) async {
    UrlLauncherPlatform.instance = _NoAppCanHandleThis();

    await tester.pumpWidget(
      testShell(child: const Scaffold(body: LegalLinksRow())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gizlilik Politikası'));
    await tester.pumpAndSettle();

    expect(
      find.text('Bağlantı açılamadı.'),
      findsOneWidget,
      reason:
          'Eskiden `launchUrl`ın `false` dönüşü hiç okunmuyordu; kullanıcı '
          'ekranda hiçbir şey görmüyordu',
    );
  });
}

/// Cihazda `url`yi açacak bir uygulama yokmuş gibi davranır — `launchUrl`
/// istisna FIRLATMADAN `false` döner, gerçek platformlardaki en yaygın
/// başarısızlık biçimiyle aynı.
class _NoAppCanHandleThis extends UrlLauncherPlatform {
  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async => false;
}
