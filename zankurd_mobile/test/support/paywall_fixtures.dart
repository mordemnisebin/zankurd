import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

/// Paketli paywall durumunu kurmak için sahte RevenueCat teklifleri.
///
/// Paywall'ın widget testleri uzun süre yalnız `Offerings({})` ile koştu ve o
/// yolda ne paket kartı ne fiyat ne yenileme metni çizilir; paketli durumu
/// ölçen test olmadığı için orada olan kusurlar görünmezdi
/// (bkz. `subscription_disclosure_test.dart`). Bu yardımcı o durumu
/// kurar. Fiyatlar uydurmadır; yalnız biçim ve düzen için.
Package fakePackage({
  required PackageType type,
  required String id,
  required double price,
  required String priceString,
}) => Package(
  id,
  type,
  StoreProduct(
    'zankurd_pro_$id',
    'ZanKurd Pro',
    'ZanKurd Pro',
    price,
    priceString,
    'TRY',
  ),
  const PresentedOfferingContext('default', null, null),
);

/// Aylık ve yıllık paketli bir teklif. [unknownMonthlyPrice] aylık paketin
/// fiyatını çözülmemiş (0) bırakır.
PremiumService fakePaywallService({bool unknownMonthlyPrice = false}) {
  final monthly = fakePackage(
    type: PackageType.monthly,
    id: r'$rc_monthly',
    price: unknownMonthlyPrice ? 0 : 39.99,
    priceString: unknownMonthlyPrice ? '' : '₺39,99',
  );
  final annual = fakePackage(
    type: PackageType.annual,
    id: r'$rc_annual',
    price: 399.99,
    priceString: '₺399,99',
  );
  final offering = Offering(
    'default',
    'ZanKurd Pro',
    const {},
    [monthly, annual],
    monthly: monthly,
    annual: annual,
  );
  return PremiumService.forTesting(
    isAnonymous: () async => true,
    logOut: () async => throw UnimplementedError(),
    fetchOfferings: () async => Offerings({'default': offering}),
  );
}
