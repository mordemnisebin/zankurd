import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Bakiye ve satın alma durumunu deterministik kontrol eden sahte depo.
class _ShopRepository extends MockZanKurdRepository {
  _ShopRepository({required this.coins, Set<String>? purchased})
    : purchased = purchased ?? <String>{};

  int coins;
  final Set<String> purchased;
  final List<String> spendReasons = [];

  @override
  Future<int> loadCoinBalance() async => coins;

  @override
  Future<bool> spendCoins(int amount, String reason) async {
    if (coins < amount) return false;
    coins -= amount;
    spendReasons.add(reason);
    return true;
  }

  @override
  Future<bool> hasPurchased(String itemId) async => purchased.contains(itemId);
}

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  test('mağaza kozmetik etkileri profil kimliğine uygulanır', () {
    const identity = AvatarIdentity(iconId: 'roj', colorHex: '#E94560');

    expect(
      applyShopPurchaseEffect('avatar_frame_gold', identity).frameId,
      'gold',
    );
    expect(
      applyShopPurchaseEffect('profile_badge_vip', identity).showcaseTitle,
      'VIP',
    );
    expect(applyShopPurchaseEffect('spin_wheel_extra', identity), identity);
  });

  // 2026-07-31: katalog 13 ürün tanımlıyordu ama yalnız 3'ü yayınlanıyordu;
  // kalan 10'u ölü veriydi ve `_supportedItemIds`e yanlışlıkla eklenirlerse
  // coin alıp hiçbir şey yapmazlardı. Dokuzu tamamen silindi, neon çerçeve
  // ise gerçekten uygulandı (AvatarFrame.neon + hasPurchased kancası).
  //
  // Bu bekçinin işi: katalogda YAYINLANMAYAN ürün kalmaması. Yani liste
  // artık hem "ne yayınlanıyor" hem "ne tanımlı" sorusunun tek cevabı.
  test('mağaza yalnız gerçekten çalışan ürünleri yayınlar', () {
    expect(debugShopItems.map((item) => item.id).toSet(), {
      'spin_wheel_extra',
      'avatar_frame_gold',
      'avatar_frame_neon',
      'profile_badge_vip',
    });
  });

  testWidgets('mağaza bakiyeyi ve ürünleri listeler', (tester) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('500 coin'), findsOneWidget);
    expect(find.text('Ekstra Çevirme'), findsOneWidget);
    expect(find.text('Altın Çerçeve'), findsOneWidget);
    expect(find.text('VIP Rozeti'), findsOneWidget);
    expect(find.text('Joker Paketi'), findsNothing);
    expect(find.text('Ekstra Can'), findsNothing);
    expect(find.text('Premium Renkler'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dar kart açıklamayı gizler, ürüne dokununca ayrıntıyı açar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    const description = 'Bugün çarkı tekrar çevirmek için ekstra hak verir.';
    expect(find.text(description), findsNothing);
    await tester.ensureVisible(find.text('Ekstra Çevirme'));
    await tester.tap(find.text('Ekstra Çevirme'));
    await tester.pumpAndSettle();
    expect(find.text(description), findsOneWidget);
    expect(find.text('Satın Al'), findsOneWidget);
  });

  testWidgets('satın alma eylemleri düz ve gölgesizdir', (tester) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('200c'));
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.ancestor(of: find.text('200c'), matching: find.byType(FilledButton)),
    );
    expect(button.style?.elevation?.resolve(<WidgetState>{}), 0);
    expect(
      button.style?.shadowColor?.resolve(<WidgetState>{}),
      Colors.transparent,
    );
  });

  testWidgets('bakiye yetersizse uyarı çıkar ve coin harcanmaz', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 50);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Ekstra çark 200c — bakiye 50c ile alınamamalı.
    await tester.ensureVisible(find.text('200c'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('200c'));
    await tester.pumpAndSettle();
    // Dalga 5: yetersiz bakiyede onay dialogunda 'Satın Al' gri disabled
    // olur ve 'Coin kazan' ikincil butonu görünür; harcama yapılmaz.
    final buyButton = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Satın Al'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(buyButton.onPressed, isNull);
    expect(find.text('Coin kazan'), findsOneWidget);
    expect(repository.spendReasons, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('satın alma coini düşürür ve doğru gerekçeyle harcar', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('200c'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('200c'));
    await tester.pumpAndSettle();
    // Confirm dialog: tap "Satın Al"
    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    expect(repository.spendReasons, ['purchase_spin_wheel_extra']);
    expect(repository.coins, 300);
    expect(find.text('300 coin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alınmış ürün "Alındı" görünür ve tekrar alınamaz', (
    tester,
  ) async {
    final repository = _ShopRepository(
      coins: 1000,
      purchased: {'avatar_frame_gold'},
    );
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Sende'), findsOneWidget);

    // Purchased items cannot be re-purchased — no buy button shown
    expect(find.text('750c'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekstra çevirme tüketilebilir olduğu için yeniden alınabilir', (
    tester,
  ) async {
    final repository = _ShopRepository(
      coins: 500,
      purchased: {'spin_wheel_extra'},
    );
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('200c'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spendCoins başarısız dönerse hata mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FailingSpendRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('200c'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('200c'));
    await tester.pumpAndSettle();
    // Confirm dialog: tap "Satın Al"
    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    expect(find.text('Satın alma başarısız oldu.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Yayın kataloğunda yalnız gerçek etkisi bulunan ürünler kalır. Fiyatlar
  // istemci ve sunucu arasında birebir korunmalıdır.
  test('mağaza paleti marka tonları çoğunlukta (M24)', () {
    final brandTones = <Color>{
      AppTheme.gold,
      AppTheme.accent,
      AppTheme.correct,
    };
    final brandCount = debugShopItems
        .where((item) => brandTones.contains(item.themeColor))
        .length;
    final offBrandCount = debugShopItems.length - brandCount;

    expect(
      brandCount,
      greaterThan(offBrandCount),
      reason:
          'Marka dışı tonlar (playPink/playCyan/playPurple) çoğunlukta '
          'kalmamalı — M24 denetiminin amacı buydu.',
    );
  });

  test('mağaza ürün fiyatları M24 paleti değişikliğinden etkilenmedi', () {
    const expectedCosts = {
      'spin_wheel_extra': 200,
      'avatar_frame_gold': 750,
      // 600'lük bant boştu: 200 ile 750 arasında harcanacak yer yoktu.
      'avatar_frame_neon': 600,
      'profile_badge_vip': 1000,
    };

    final actualCosts = {for (final item in debugShopItems) item.id: item.cost};
    expect(actualCosts, expectedCosts);
  });

  // 2026-07-23 M33 marka kimliği için başlığa bir Roj maskotu şeridi
  // eklemişti. 2026-07-25 canlı denetiminde bu şerit, AppBar başlığı ve
  // kimlik kartıyla birlikte üst üste üçüncü kez "mağaza / coinlerini
  // harca" diyordu ve ilk ürün ancak ekranın yarısından sonra başlıyordu.
  // Şerit kaldırıldı; karşılamayı kimlik kartının alt başlığı taşır.
  // Maskot onboarding, liderlik ve boş durumlarda görünmeye devam eder.
  testWidgets('mağaza başlığı tek karşılama gösterir', (tester) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop-mascot-header')), findsNothing);
    expect(find.text('Mağaza'), findsOneWidget);
  });

  testWidgets('bakiye 0 iken earn-coin CTA 390x844 ekranda taşmadan çizilir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = _ShopRepository(coins: 0);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('shop-earn-coin-cta')), findsOneWidget);
    // Overflow olsaydı framework exception fırlatırdı.
    expect(tester.takeException(), isNull);
  });
}

/// Bakiye yeterli görünürken sunucunun harcamayı reddettiği senaryo
/// (ör. eşzamanlı harcama sonrası sunucu bakiyesi düşmüş olabilir).
class _FailingSpendRepository extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 500;

  @override
  Future<bool> spendCoins(int amount, String reason) async => false;

  @override
  Future<bool> hasPurchased(String itemId) async => false;
}
