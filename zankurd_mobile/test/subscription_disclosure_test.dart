import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Apple 3.1.2'nin "abonelik bilgisi uygulamanın içinde" listesi.
///
/// ## Kusur
///
/// 1.9.2 (17) Guideline 3.1.2(c) ile reddedildi (2026-08-17, iPad Air 11").
/// Apple'ın adını koyduğu eksik App Store metadata'sındaki EULA bağlantısıydı,
/// ama ret mektubunun kaynak listesi uygulamanın İÇİNDE dört şey ister:
///
/// - aboneliğin **başlığı** (mağaza ürün adıyla aynı olabilir),
/// - **süresi**,
/// - **fiyatı**, uygunsa **birim fiyatı**,
/// - gizlilik politikası ve kullanım koşullarına **çalışan bağlantılar**.
///
/// Ret üzerine yapılan taramada ikisinin eksik olduğu görüldü ve ikisi de
/// `paywall_compliance_test`in kör noktasındaydı — o dosya yenileme
/// koşullarını, Kurmancî metinleri ve `LegalLinksRow`un varlığını ölçüyor,
/// ürünün KİMLİĞİNİ hiç ölçmüyordu:
///
/// **Başlık.** Ekranın tepesinde 'Premium' yazıyordu. 'Premium' bir özellik
/// adıdır; App Store Connect'teki abonelik grubu "ZanKurd Pro", ürünler
/// "ZanKurd Pro Monthly"/"Yearly". İncelemeci ekranda gördüğü adı mağaza
/// kaydındaki adla eşleştiremez ve bu, aynı yönergenin altında ikinci bir
/// ret sebebidir. Kartlardaki "Aylık"/"Yıllık" ile birleşince başlık artık
/// tam ürün adını okutur.
///
/// **Birim fiyat.** Yıllık kartta yalnız "₺399,99/yıl" yazıyordu. Kullanıcı
/// bunun aylık plana göre ucuz mu pahalı mı olduğunu ekranda hesap yapmadan
/// bilemiyordu; Apple bu yüzden "price per unit if appropriate" der.
///
/// ## Niçin sessiz kaldı
///
/// Paywall'ın widget testleri RevenueCat yapılandırması olmadan ürün listesine
/// ulaşamıyor: `Offerings({})` ile koşuyorlar ve o yolda ne kart başlığı ne
/// fiyat satırı çizilir. Yani paketli durumu ölçen hiçbir test yoktu ve
/// olmayan şey de fark edilmedi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('abonelik adı', () {
    test('mağaza kaydındaki adla birebir aynıdır', () {
      // App Store Connect'teki abonelik grubu adı. Değişirse burası da
      // değişmeli — ekrandaki ad ile mağazadaki ad ayrışırsa incelemeci
      // ikisini eşleştiremez.
      expect(AppConfig.subscriptionDisplayName, 'ZanKurd Pro');
    });

    Future<void> pumpPaywall(WidgetTester tester, String lang) async {
      final service = PremiumService.forTesting(
        isAnonymous: () async => true,
        logOut: () async => throw UnimplementedError(),
        fetchOfferings: () async => const Offerings({}),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider(initialLang: lang),
            ),
            ChangeNotifierProvider<PremiumService>.value(value: service),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: PaywallScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final lang in ['tr', 'ku']) {
      testWidgets('satın alma ekranının tepesinde yazar ($lang)', (
        tester,
      ) async {
        await pumpPaywall(tester, lang);

        expect(
          find.text(AppConfig.subscriptionDisplayName),
          findsOneWidget,
          reason:
              'Aboneliğin adı satın alma ekranında görünmüyor; Apple 3.1.2 '
              'bunu şart koşar.',
        );
        // Ad çevrilmez: mağaza kaydındaki ad da çevrilmiyor.
        expect(
          find.text('Premium'),
          findsNothing,
          reason:
              "'Premium' bir özellik adıdır, ürün adı değil; başlıkta durursa "
              'incelemeci mağaza kaydıyla eşleştiremez.',
        );
      });
    }
  });

  /// İncelemeciye tarif edilen yol, uygulamadaki yolla aynı olmalı.
  ///
  /// ## Kusur
  ///
  /// App Review Notes'ta satın alma ekranına giden yol "Profile > Shop"
  /// yazıyordu. Öyle bir yol yok: `PaywallScreen`in kod tabanında TEK bir
  /// çağıranı var ve o da ayarlar ekranı. İncelemeci mağaza (jeton) ekranına
  /// gider, aboneliği bulamaz ve 3.1.2 altında ikinci kez reddeder —
  /// uygulamada eksik bir şey olmadığı hâlde (2026-08-17).
  ///
  /// Yanlış yol sessiz kaldı çünkü hiçbir şeyi kırmıyor: paket ve notlar
  /// düzyazıdır, kod onları okumaz. Sürüklenme yalnız reddedildikten sonra
  /// görünürdü.
  ///
  /// ## Kural
  ///
  /// Bekçi yolu tarif etmez — tarif edilenin DOĞRU KALMASINI sağlar: paywall
  /// başka bir ekrandan da açılır hâle gelirse ya da ayarlardan kaldırılırsa
  /// test kırılır ve paketteki cümle güncellenene kadar kırmızı kalır.
  group('incelemeci yolu', () {
    test('paywall yalnız bilinen iki ekrandan açılır', () {
      final callers = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.path.endsWith('.dart'))
          .where((file) => !file.path.endsWith('paywall_screen.dart'))
          .where((file) => file.readAsStringSync().contains('PaywallScreen('))
          .map((file) => file.uri.pathSegments.last)
          .toList()
        ..sort();

      expect(
        callers,
        ['home_screen.dart', 'settings_screen.dart'],
        reason:
            'App Review paketi ve App Store Connect notları satın alma '
            'ekranına giden yolları sayıyor. Giriş noktaları değiştiyse o '
            'iki metin de değişmeli; yoksa incelemeci ekranı bulamaz.',
      );
    });

    test('yayınlanacak paket bu yolu tarif eder', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final build = RegExp(
        r'^version:\s*\d+\.\d+\.\d+\+(\d+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1)!;

      final packet = File(
        'docs/app_review_packet_1.9.2_build$build.md',
      ).readAsStringSync();

      // Yolun iki durağı da yazılı olmalı: hangi sekmeden girileceği ve
      // hangi bölüme inileceği. Yalnız "Settings" demek yetmez — ayarlar
      // ekranı uzun ve premium kartı en altta.
      expect(packet, contains('Settings'));
      expect(packet, contains('Premium'));
      expect(
        packet,
        contains('Home tab'),
        reason:
            'Ana ekrandaki kısa yol pakette yazmalı; incelemeci en kolay '
            'yolu bilmeli.',
      );
      expect(
        packet,
        contains('only two entry points'),
        reason:
            'Paket, satın alma ekranının kaç girişi olduğunu söylemeli; '
            'incelemeci başka yerlerde aramamalı.',
      );
    });
  });

  group('birim fiyat', () {
    // Ölçülen şey aritmetik değil BİÇİM: sayı doğru olsa bile ayırıcı ya da
    // simge yeri yanlışsa fiyat yanlış okunur.
    test('Türk lirası biçimini korur: simge önde, ayırıcı virgül', () {
      expect(monthlyEquivalentPrice('₺399,99', 399.99), '₺33,33');
    });

    test('ABD doları biçimini korur: simge önde, ayırıcı nokta', () {
      expect(monthlyEquivalentPrice(r'$59.99', 59.99), r'$5.00');
    });

    test('simge arkada duran yerelleri bozmaz', () {
      // Almanya/Fransa biçimi: "59,99 €". Simge ve aradaki boşluk yerinde
      // kalmalı; sayı yalnız sayının durduğu yerde değişir.
      expect(monthlyEquivalentPrice('59,99 €', 59.99), '5,00 €');
    });

    test('binlik ayırıcılı fiyatlarda sayının tamamını değiştirir', () {
      // İlk rakamdan SON rakama kadar olan aralık değişir; yalnız ilk sayı
      // parçası değişseydi "₺1.33,00" gibi bozuk bir metin çıkardı.
      expect(monthlyEquivalentPrice('₺1.199,88', 1199.88), '₺99,99');
    });

    test('fiyat bilinmiyorken birim fiyat uydurulmaz', () {
      // RevenueCat ürünü çözemediğinde `price` 0 döner. O anda "≈ ₺0,00/ay"
      // yazmak, olmayan bir fiyatı varmış gibi göstermek olurdu.
      expect(monthlyEquivalentPrice('₺399,99', 0), isNull);
      expect(monthlyEquivalentPrice('Fiyat geliyor', 399.99), isNull);
    });
  });
}
