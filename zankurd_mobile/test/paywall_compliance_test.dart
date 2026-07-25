import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 2026-07-25 denetim bulgusu: paywall'da otomatik yenileme koşulları
/// yazmıyordu (Apple App Store Review 3.1.2 / Google Play abonelik
/// politikası) ve Kurmancî alt metni anlamsızdı.
///
/// Bu kontroller kaynak metin üzerinden yapılır; ekran RevenueCat
/// yapılandırması olmadan render edilemediği için widget testi ürün
/// listesine ulaşamaz.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/src/screens/paywall_screen.dart').readAsStringSync();
  });

  test('paywall otomatik yenileme koşullarını yazar', () {
    expect(source, contains('Abonelik otomatik yenilenir'));
    expect(source, contains('24 saat'));
    expect(source, contains('Abone bixweber nû dibe'));
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
}
