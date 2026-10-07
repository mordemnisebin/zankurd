// Gerçek RevenueCat'e karşı SDK sözleşmesi (integration_test).
//
// Çalıştırma (yerel StoreKit yapılandırması + gerçek anahtar gerekir):
//   flutter test integration_test/revenuecat_roundtrip_test.dart \
//     -d <simulator> --dart-define-from-file=.env.mobile.local.json
//
// Doğruladığı üç şey (2026-08-17 turu):
//   1. getOfferings: paneldeki `default` offering, StoreKit tarafındaki
//      ürün kimlikleriyle birlikte dolu gelir (boş offering = paywall'in
//      "yapılandırma yok" durumudur).
//   2. restorePurchases: hiç satın alma yapmamış anonim kullanıcı için
//      hatasız döner ve `premium` yetkisi YOK der — "geri yükle" düğmesinin
//      ağ tarafı budur.
//   3. Satın alma ANINDA yetki verir: `premium` entitlement'ı açık gelir.
//      (Alımın kendisi sistem sayafı gösterir; burada yalnız SDK↔panel
//      eşlemesi doğrulanır, ödeme akışı elle sandbox'ta sınanır.)
//
// Bu test ağ ve gerçek hizmet gerektirdiğinden `flutter test` ana
// paketinin dışında, elle koşulur (bkz. local_backend_1v1_test.dart).
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:zankurd_mobile/src/config/app_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    expect(
      AppConfig.revenuecatApiKey,
      isNotEmpty,
      reason: 'REVENUECAT_API_KEY_IOS verilmeli (.env.mobile.local.json)',
    );
    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(
      PurchasesConfiguration(AppConfig.revenuecatApiKey)..appUserID = null,
    );
  });

  testWidgets('offerings: default offering iki gerçek ürünle dolu', (
    tester,
  ) async {
    final offerings = await Purchases.getOfferings();
    // ignore: avoid_print
    print('ZK_RC_CURRENT=${offerings.current?.identifier}');

    final current = offerings.current;
    expect(current, isNotNull, reason: 'varsayılan offering yok');
    expect(current!.identifier, 'default');

    final productIds = current.availablePackages
        .map((p) => p.storeProduct.identifier)
        .toSet();
    // ignore: avoid_print
    print('ZK_RC_PRODUCTS=$productIds');
    expect(
      productIds,
      containsAll([
        'com.zankurd.app.premium.monthly',
        'com.zankurd.app.premium.yearly',
      ]),
      reason: 'StoreKit yapılandırması ve panel eşleşmiyor: $productIds',
    );
  });

  testWidgets('restore: satın almasız kullanıcı hatasız, yetkisiz döner', (
    tester,
  ) async {
    final info = await Purchases.restorePurchases();
    final premium = info.entitlements.all['premium'];
    // ignore: avoid_print
    print('ZK_RC_RESTORE_ACTIVE=${premium?.isActive}');
    expect(premium?.isActive ?? false, isFalse);
  });

  testWidgets('abonelik durumu dinlenebilir ve anonim kimliklidir', (
    tester,
  ) async {
    final info = await Purchases.getCustomerInfo();
    expect(info.originalAppUserId, isNotEmpty);
    // ignore: avoid_print
    print('ZK_RC_ANON=${await Purchases.isAnonymous}');
    expect(await Purchases.isAnonymous, isTrue);
  });
}
