import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
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
  testWidgets('mağaza bakiyeyi ve ürünleri listeler', (tester) async {
    final repository = _ShopRepository(coins: 500);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('500 coin'), findsOneWidget);
    expect(find.text('Joker Paketi'), findsOneWidget);
    expect(find.text('Ekstra Can'), findsOneWidget);
    expect(find.text('Ekstra Çark Çevirme'), findsOneWidget);
    expect(find.text('Premium Renkler'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bakiye yetersizse uyarı çıkar ve coin harcanmaz', (
    tester,
  ) async {
    final repository = _ShopRepository(coins: 50);
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Ekstra Can 100c — bakiye 50c ile alınamamalı.
    await tester.tap(find.text('100c'));
    await tester.pump();

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

    await tester.tap(find.text('100c'));
    await tester.pumpAndSettle();

    expect(repository.spendReasons, ['purchase_extra_lifeline']);
    expect(repository.coins, 400);
    expect(find.text('400 coin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alınmış ürün "Alındı" görünür ve tekrar alınamaz', (
    tester,
  ) async {
    final repository = _ShopRepository(
      coins: 500,
      purchased: {'extra_lifeline'},
    );
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.text('Alındı'), findsOneWidget);

    final purchasedButton = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('Alındı'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(purchasedButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('spendCoins başarısız dönerse hata mesajı gösterilir', (
    tester,
  ) async {
    final repository = _FailingSpendRepository();
    await tester.pumpWidget(_shell(ShopScreen(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('100c'));
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
