import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

import 'support/widget_test_helpers.dart';

/// Abonelik ekranına giden yolun bekçisi.
///
/// ## Kusur
///
/// `PaywallScreen`in kod tabanında tek bir çağıranı vardı: ayarlar ekranının
/// en altındaki "Premium" bölümü. Yani para kazandıran tek yüzeye giden yol
/// profil sekmesi → Ayarlar → aşağı kaydır → Premium idi ve hiçbir yerde
/// ilan edilmiyordu. Bu, 2026-08-17'deki 3.1.2(c) reddi sırasında görüldü:
/// App Review Notes'ta yazan yol ("Profile > Shop") uygulamada yoktu ve
/// doğrusunu bulmak için kaynağı taramak gerekti.
///
/// Aynı kusur bir kez daha yaşanmıştı ve çözümü de aynıydı: mağazaya tek
/// giriş profil ekranının içindeydi, coin rozeti ana ekrana konunca çözüldü
/// (bkz. `home_shop_entry_test.dart`, 2026-07-27). Abonelik girişi de aynı
/// kararı alır.
///
/// ## Kural
///
/// Ana ekranın gövdesinde, abonesi OLMAYAN oyuncuya satın alma ekranına
/// götüren bir satır durur. Abone olana gösterilmez: satın alınmış bir şeyi
/// satmaya devam etmek, ödemiş kullanıcıya reklam gibi görünür.
///
/// Satır bilerek gövdenin sonunda ve başlık rozetlerinde DEĞİL: ana ekranın
/// ilk sorusu "şimdi ne yapmalıyım?"dır ve cevabı turuncu "Başla" düğmesidir;
/// üçüncü bir başlık rozeti ise 320pt genişlikte rozet satırını taşırıyordu.
void main() {
  setUp(() {
    AchievementStore.resetInstance();
    // Satın alınabilirlik kapısı derleme bayrağıdır; testte düğmeyle açılır.
    AppConfig.debugHasRevenuecatConfig = true;
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
      'zankurd.achievements.unlocked': ['first_game'],
    });
  });

  tearDown(() {
    AppConfig.debugHasRevenuecatConfig = null;
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    PremiumService? premiumService,
  }) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: HomeScreen(repository: MockZanKurdRepository())),
        premiumService: premiumService,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('abonesi olmayan oyuncu satın alma ekranını ana ekrandan bulur', (
    tester,
  ) async {
    await pumpHome(tester);

    final row = find.byKey(const ValueKey('home-premium-row'));
    expect(
      row,
      findsOneWidget,
      reason:
          'Satın alma ekranına ana ekrandan giriş yok; tek yol yine ayarların '
          'en altı demektir.',
    );
    // Satırda mağaza kaydındaki ad yazmalı — "Premium" gibi genel bir
    // özellik adı değil (bkz. `subscription_disclosure_test.dart`).
    expect(
      find.descendant(
        of: row,
        matching: find.text(AppConfig.subscriptionDisplayName),
      ),
      findsOneWidget,
    );

    // `ensureVisible` ile `tap` ARASINDA pump şart: kaydırma bir kare
    // sonra yerleşir ve pump atlanınca dokunuş satırın ESKİ konumuna
    // gider, hiçbir şey açılmaz ve test "satır var ama açmıyor" diye
    // yanlış bir kusur bildirir.
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      find.byType(PaywallScreen),
      findsOneWidget,
      reason: 'Satır çiziliyor ama satın alma ekranını açmıyor.',
    );
  });

  testWidgets('abone olana satış satırı gösterilmez', (tester) async {
    await pumpHome(tester, premiumService: PremiumService.premiumForTesting());

    expect(
      find.byKey(const ValueKey('home-premium-row')),
      findsNothing,
      reason:
          'Zaten abone olan kullanıcıya abonelik satılmaya devam ediliyor; '
          'ödemiş kullanıcı için bu bir reklamdır.',
    );
  });

  testWidgets('yapılandırma yoksa ölü paywall girişi çizilmez', (tester) async {
    // Ürünsüz derlemede (API anahtarı yok) giriş gizlenir: "çok yakında"
    // vaat eden ölü sokak güven zedeler (2026-09-05 canlı turu).
    AppConfig.debugHasRevenuecatConfig = false;
    await pumpHome(tester);

    expect(
      find.byKey(const ValueKey('home-premium-row')),
      findsNothing,
      reason: 'Satın alınabilir ürün yokken satış satırı çiziliyor.',
    );
  });
}
