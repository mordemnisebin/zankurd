import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';

void main() {
  const known = [
    'Ziman', 'Çand', 'Dîrok', 'Edebiyat',
    'Cografya', 'Muzîk', 'Siyaset', 'Paradigma',
  ];

  test('bilinen her kategori için ikon tanımlı', () {
    for (final cat in known) {
      expect(CategoryVisuals.icon(cat), isA<IconData>());
      expect(CategoryVisuals.icon(cat), isNot(Icons.category_outlined),
          reason: '$cat için özel ikon bekleniyor');
    }
  });

  test('bilinmeyen kategori fallback ikon döner', () {
    expect(CategoryVisuals.icon('Yok'), Icons.category_outlined);
  });

  test('imagePath bilinen kategoriler için png yolu döner', () {
    for (final cat in known) {
      expect(CategoryVisuals.imagePath(cat), endsWith('.png'));
    }
  });
}
