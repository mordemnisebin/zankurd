import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// 2026-07-25 denetim bulgusu: paywall'da otomatik yenileme koşulları
/// yazmıyordu (Apple App Store Review 3.1.2 / Google Play abonelik
/// politikası) ve Kurmancî alt metni anlamsızdı.
///
/// Bu kontroller kaynak metin üzerinden yapılır; ekran RevenueCat
/// yapılandırması olmadan render edilemediği için widget testi ürün
/// listesine ulaşamaz.
void main() {
  test(
    'premium ekranı sunucuda doğrulanmayan ücretsiz kozmetik vaat etmez',
    () {
      final paywall = File(
        'lib/src/screens/paywall_screen.dart',
      ).readAsStringSync();
      final strings = File('lib/src/l10n/strings.dart').readAsStringSync();
      final storeListing = File('docs/store_listing.md').readAsStringSync();
      final terms = File('web/terms.html').readAsStringSync();

      for (final unsupportedClaim in [
        'Tüm kozmetikler bedava',
        'Hemû xeml belaş',
        'Bedava kozmetikler',
        'Xemla belaş',
        'Bedava · Premium',
        'Belaş · Premium',
        'Bedava aç',
        'Belaş veke',
      ]) {
        expect(paywall, isNot(contains(unsupportedClaim)));
        expect(strings, isNot(contains(unsupportedClaim)));
        expect(storeListing, isNot(contains(unsupportedClaim)));
        expect(terms, isNot(contains(unsupportedClaim)));
      }
    },
  );

  late String source;

  setUpAll(() {
    source = File('lib/src/screens/paywall_screen.dart').readAsStringSync();
  });

  test('paywall otomatik yenileme koşullarını yazar', () {
    expect(source, contains('Abonelik otomatik yenilenir'));
    expect(source, contains('24 saat'));
    expect(source, contains('Abonetiya te bixweber nû dibe'));
  });

  test('paywall Kurmancî eylem ve durum metinleri doğaldır', () {
    for (final expected in [
      'Piştgiriya ZanKurdê',
      'Her gav dikarî betal bikî',
      'NAVDAR',
      'Bikire',
      'Pakêtên Premium hîn nehatine çalak kirin',
      'Kirînên xwe vegerîne',
    ]) {
      expect(source, contains(expected));
    }
    for (final obsolete in [
      'Piştgiriya ZanKurd\'',
      'Her gav tê betalkirin',
      "isKu ? 'YÊ'",
      "isKu ? 'Bikirin'",
      'Kirrinan vegerîn',
    ]) {
      expect(source, isNot(contains(obsolete)));
    }
  });

  test('paywall yasal bağlantıları taşır', () {
    expect(source, contains('LegalLinksRow'));
  });

  test('fiyat yanında yenileme dönemi gösterilir', () {
    expect(source, contains('_pricePeriodSuffix'));
    expect(source, contains("'/ay'"));
    expect(source, contains("'/yıl'"));
  });

  test('bozuk Kurmancî alt metni kaldırıldı', () {
    // Eski metin: "Dema kirrinan pê hatin hate vegerandin; bêpûçkirin ji bo
    // carekê dike." — Türkçe karşılığıyla ilgisiz ve dilbilgisel olarak
    // tutarsızdı.
    expect(source, isNot(contains('bêpûçkirin ji bo carekê')));
    expect(source, isNot(contains('2 mehane xerc mesrefa')));
  });

  test('satın alma sonucu bool değil, ayrık durumlarla ele alınır', () {
    // İptal ile hata, askıdaki ödeme ile başarısızlık aynı şeye
    // indirgenmemeli.
    expect(source, contains('PurchaseOutcome.cancelled'));
    expect(source, contains('PurchaseOutcome.pending'));
    expect(source, contains('RestoreOutcome.nothingFound'));
  });

  test('premium servisi RevenueCat kimliğini kullanıcıya bağlar', () {
    final service = File(
      'lib/src/services/premium_service.dart',
    ).readAsStringSync();
    expect(service, contains('Purchases.logIn'));
    expect(service, contains('Purchases.logOut'));
    expect(service, contains('PurchasesErrorHelper.getErrorCode'));
    // Kırılgan string eşleştirmesi kaldırıldı.
    expect(service, isNot(contains("contains('userCancelled')")));
  });

  test('oturum kapanışında premium kimliği bırakılır', () {
    final auth = File(
      'lib/src/providers/auth_provider.dart',
    ).readAsStringSync();
    expect(auth, contains('logOutUser'));
    expect(auth, contains('logInUser'));
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('premium üst yüzeyi $mode temasında şeffaf kalmaz', (
      tester,
    ) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider(initialLang: 'tr'),
            ),
            ChangeNotifierProvider<PremiumService>(
              create: (_) => PremiumService.fallback(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: mode,
            home: PaywallScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(scaffold.backgroundColor, isNot(Colors.transparent));
      expect(appBar.backgroundColor, isNot(Colors.transparent));
    });
  }
}
