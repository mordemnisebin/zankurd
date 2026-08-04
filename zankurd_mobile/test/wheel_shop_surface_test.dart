import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';

import 'support/widget_test_helpers.dart';

/// Çark ve mağaza yüzeylerinin görsel sözleşmeleri.
///
/// Çarkın başlık gradyanı `brandDeep` (kahve-turuncu) ile koyu yeşili
/// karıştırıyor ve ortada çamurlu bir ton bırakıyordu. Night Jewel bu
/// geçişi açıkça dışlar: derin mürekkep zemin, kontrollü mücevher
/// aksanları, çamurlu yeşil-kahve gradyan YOK (2026-08-04).
///
/// Mağaza ise zaten gerçek bir vitrin: telefonda iki sütunlu grid, ürün
/// türüne göre kontrollü ton, öne çıkan ürün ve gerçek coin bakiyesi.
/// Bekçi bunun düz beyaz kart yığınına geri dönmesini engeller.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('çark başlığı çamurlu yeşil-kahve gradyan taşımıyor', () {
    final source = File(
      'lib/src/screens/spin_wheel_screen.dart',
    ).readAsStringSync();
    final code = source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');
    expect(
      code,
      isNot(contains('colors: [AppTheme.brandDeep, Color(0xFF17503A)]')),
      reason: 'kahve-turuncu ile yeşili karıştıran gradyan geri geldi',
    );
  });

  testWidgets('mağaza telefonda iki sütunlu grid kullanır', (tester) async {
    // Tek sütuna düşerse ekran başına bir ürün görünür ve vitrin
    // beyaz kart yığınına döner.
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 1000) * 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: ShopScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));

    final grids = tester.widgetList<GridView>(find.byType(GridView));
    expect(grids, isNotEmpty, reason: 'ürün grid’i hiç çizilmedi');
    final delegate = grids.first.gridDelegate;
    expect(delegate, isA<SliverGridDelegateWithFixedCrossAxisCount>());
    expect(
      (delegate as SliverGridDelegateWithFixedCrossAxisCount).crossAxisCount,
      greaterThanOrEqualTo(2),
      reason: 'modern telefonlarda vitrin iki sütun olmalı',
    );
  });

  testWidgets('mağaza gerçek coin bakiyesini gösterir', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 1000) * 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: ShopScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    // Bakiye rozeti: oyuncu neyi karşılayabildiğini vitrinden ayrılmadan
    // görmeli.
    expect(find.textContaining('coin'), findsWidgets);
  });

  testWidgets('mağaza karanlık temada çizim hatasız', (tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 1000) * 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
        child: ShopScreen(repository: MockZanKurdRepository()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mağaza iPad’de daha çok sütun kullanır', (tester) async {
    tester.view.devicePixelRatio = 2.0;
    tester.view.physicalSize = const Size(834, 1194) * 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: ShopScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 800));
    final delegate =
        tester.widgetList<GridView>(find.byType(GridView)).first.gridDelegate
            as SliverGridDelegateWithFixedCrossAxisCount;
    expect(
      delegate.crossAxisCount,
      greaterThanOrEqualTo(3),
      reason: 'tablet telefon düzenini gerdirmemeli',
    );
  });
}
