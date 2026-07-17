import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/avatar_identity.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
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
    expect(applyShopPurchaseEffect('joker_bundle', identity), identity);
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

  testWidgets('bakiye yetersizse uyarı çıkar ve coin harcanmaz', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 50);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Ekstra çark 200c — bakiye 50c ile alınamamalı.
    await tester.tap(find.text('200c'));
    await tester.pumpAndSettle();
    // Confirm dialog appears — tap "Satin Al"
    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    expect(find.text('Bakiye yetersiz!'), findsOneWidget);
    expect(repository.spendReasons, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('satın alma coini düşürür ve doğru gerekçeyle harcar', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
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
      coins: 500,
      purchased: {'spin_wheel_extra'},
    );
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Sende'), findsOneWidget);

    // Purchased items cannot be re-purchased — no buy button shown
    expect(find.text('200c'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spendCoins başarısız dönerse hata mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FailingSpendRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('200c'));
    await tester.pumpAndSettle();
    // Confirm dialog: tap "Satın Al"
    await tester.tap(find.text('Satın Al'));
    await tester.pumpAndSettle();

    expect(find.text('Satın alma başarısız oldu.'), findsOneWidget);
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
