import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
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

  // Bu üç kontrol bir zamanlar `paywall_screen.dart`in KAYNAK METNİNİ
  // tarıyordu: dosyada 'Abonelik otomatik yenilenir' dizesi geçiyorsa
  // geçmiş sayılıyordu. Metinler 2026-07-31'de anahtar defterine taşınınca
  // testler kırıldı — kırılmaları doğruydu, çünkü ölçtükleri şey metnin
  // *nerede yazıldığıydı*, kullanıcıya *ne gösterildiği* değil. Artık
  // defterden okunuyor: hangi dosyada durduğu değil, iki dilde de doğru
  // metnin teslim edildiği ölçülüyor.
  test('paywall otomatik yenileme koşullarını iki dilde yazar', () {
    // Apple 3.1.2 / Google Play: yenileme, ücretlendirme anı ve iptal yolu
    // satın alma ekranının kendisinde yazmalı.
    final tr = Tr.of(K.paywallRenewalTerms, AppLanguage.tr);
    final ku = Tr.of(K.paywallRenewalTerms, AppLanguage.ku);
    expect(tr, contains('otomatik yenilenir'));
    expect(tr, contains('24 saat'));
    expect(tr, contains('iptal'));
    expect(ku, contains('bixweber nû dibe'));
    expect(ku, contains('24 saetan'));
    expect(ku, contains('betal'));
  });

  test('paywall Kurmancî eylem ve durum metinleri doğaldır', () {
    expect(Tr.of(K.paywallPerkSupport, AppLanguage.ku), 'Piştgiriya ZanKurdê');
    expect(Tr.of(K.cancelAnytime, AppLanguage.ku), 'Her gav dikarî betal bikî');
    expect(Tr.of(K.popularBadge, AppLanguage.ku), 'NAVDAR');
    expect(Tr.of(K.buyAction, AppLanguage.ku), 'Bikire');
    expect(
      Tr.of(K.paywallPackagesInactive, AppLanguage.ku),
      'Pakêtên Premium hîn nehatine çalak kirin',
    );
    expect(Tr.of(K.restorePurchases, AppLanguage.ku), 'Kirînên xwe vegerîne');

    // Terk edilmiş biçimler hiçbir anahtarda yaşamamalı.
    for (final key in Tr.keys) {
      final ku = Tr.of(key, AppLanguage.ku);
      for (final obsolete in [
        "Piştgiriya ZanKurd'",
        'Her gav tê betalkirin',
        'Kirrinan vegerîn',
        'Bikirin',
      ]) {
        expect(ku, isNot(contains(obsolete)), reason: '$key eski biçimi taşıyor');
      }
    }
  });

  test('paywall yasal bağlantıları taşır', () {
    expect(source, contains('LegalLinksRow'));
  });

  test('fiyat yanında yenileme dönemi gösterilir', () {
    expect(source, contains('_pricePeriodSuffix'));
    expect(Tr.of(K.perMonthSuffix, AppLanguage.tr), '/ay');
    expect(Tr.of(K.perYearSuffix, AppLanguage.tr), '/yıl');
    expect(Tr.of(K.perWeekSuffix, AppLanguage.tr), '/hafta');
    expect(Tr.of(K.perMonthSuffix, AppLanguage.ku), '/meh');
    expect(Tr.of(K.perYearSuffix, AppLanguage.ku), '/sal');
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
