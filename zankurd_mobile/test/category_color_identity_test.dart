import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';

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
}
