import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

/// 2026-07-22 canlı UX denetimi (P1-B): kategori renkleri **sıraya** göre
/// veriliyordu. Kategori listesi `widget.index`, alt kategori ve quiz
/// ekranları ise `repository.categories.indexOf(...)` kullanıyordu; iki
/// sıralama örtüşmediği için aynı kategori ekrandan ekrana renk
/// değiştiriyordu (Muzîk listede hardal → detayda bordo, Dîrok listede
/// bordo → düelloda lacivert).
///
/// Renk artık kategorinin adına bağlı. Bu testler sıradan bağımsızlığı ve
/// kategoriler arası ayırt edilebilirliği korur.
void main() {
  final repository = MockZanKurdRepository();

  test('renk kategori adına bağlı, sıraya değil', () {
    final categories = repository.categories;
    expect(categories, isNotEmpty);

    // Sırayı tersine çevirmek rengi değiştirmemeli.
    for (final category in categories) {
      final direct = CategoryVisuals.gradientColors(category);
      final reversedOrder = categories.reversed.toList();
      final viaReversed = CategoryVisuals.gradientColors(
        reversedOrder[reversedOrder.indexOf(category)],
      );
      expect(viaReversed, equals(direct), reason: category);
    }
  });

  test('her kategorinin açıkça tanımlı bir rengi var', () {
    for (final category in repository.categories) {
      expect(
        CategoryVisuals.colorDefinedCategories,
        contains(category),
        reason: '$category için renk tanımlanmamış (fallback\'e düşüyor)',
      );
    }
  });

  test('kategoriler birbirinden ayırt edilebilir renklerde', () {
    final seen = <int, String>{};
    for (final category in repository.categories) {
      final primary = CategoryVisuals.color(category);
      final previous = seen[primary.toARGB32()];
      expect(
        previous,
        isNull,
        reason: '$category ile $previous aynı rengi paylaşıyor',
      );
      seen[primary.toARGB32()] = category;
    }
  });

  test('gradyan iki renkten oluşur ve koyu uç daha koyudur', () {
    for (final category in repository.categories) {
      final colors = CategoryVisuals.gradientColors(category);
      expect(colors.length, 2, reason: category);
      expect(
        colors.last.computeLuminance(),
        lessThan(colors.first.computeLuminance()),
        reason: '$category gradyanının ikinci rengi daha koyu olmalı',
      );
    }
  });

  // 2026-09-29 doğallık (K1): kategori renkleri Şahnê'den bağımsız bir
  // tabloda ("Rengîn Editorial") duruyordu; artık tek kaynak
  // `SahneCategoryTone`. Zemin, çizimsiz karoda adın okunduğu yüzeydir:
  // gece birincil metni üstünde AA (4.5) geçmeli.
  test('kategori renkleri yalnız Şahnê tonundan gelir, ad okunur', () {
    for (final category in CategoryVisuals.colorDefinedCategories) {
      final tone = CategoryVisuals.tone(category);
      expect(tone, SahneCategoryTone.of(category), reason: category);
      expect(CategoryVisuals.color(category), tone.ground, reason: category);
      final a = tone.ground.computeLuminance();
      final b = SahneTokens.night.tx.computeLuminance();
      expect((b + 0.05) / (a + 0.05), greaterThanOrEqualTo(4.5));
    }
    expect(CategoryVisuals.tone('Tarih'), SahneCategoryTone.dirok);
  });

  // Kategori fotoğrafları (K1'de üretilmiş görünüşlüler, sonra Şahnê'nin
  // silüet karosuyla geri kalanı) ekrandan kalktı ama sekizi pakette
  // ~580 KB olarak taşınmaya devam etti. Yalnız cat_siyaset bir sorunun
  // görseli olarak yaşar; yeni bir kategori fotoğrafı ancak bilinçli
  // kararla geri gelir.
  test('pakette soru görseli dışında kategori fotoğrafı yok', () {
    final cats = Directory('assets/question_images')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('cat_'))
        .toList();
    expect(cats, ['cat_siyaset.webp']);

    final users = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('question_images/cat_'))
        .map((f) => f.path)
        .toList();
    expect(users, ['lib/src/data/curated_question_bank.dart']);
  });
}
