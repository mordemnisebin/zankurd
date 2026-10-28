import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';

void main() {
  test('all supported categories retain explicit visual mappings', () {
    const categories = [
      'Ziman',
      'Çand',
      'Dîrok',
      'Edebiyat',
      'Cografya',
      'Muzîk',
      'Siyaset',
      'Paradigma',
      'Teknolojî',
      'Sînema',
      'Cîhan',
    ];
    for (final category in categories) {
      expect(CategoryVisuals.icon(category), isNot(Icons.category_outlined));
      expect(CategoryVisuals.mark(category), isNotNull, reason: category);
    }
  });

  // Kusur: Cîhan ve Cografya ikisi de `AppIcons.globe` kullanıyordu. Ana
  // sayfada silüet ayırır ama profil istatistiği, oda/düello konu seçici ve
  // sıralama yalnız simge gösterir; iki konu birbirinin aynı görünüyordu.
  // Hata vermez, yalnız okunmaz. Bekçi: hiçbir iki kategori simge paylaşmaz.
  test('no two categories share the same icon', () {
    const categories = [
      'Ziman',
      'Çand',
      'Dîrok',
      'Edebiyat',
      'Cografya',
      'Muzîk',
      'Siyaset',
      'Paradigma',
      'Teknolojî',
      'Sînema',
      'Cîhan',
    ];
    final seen = <IconData, String>{};
    for (final category in categories) {
      final icon = CategoryVisuals.icon(category);
      expect(
        seen[icon],
        isNull,
        reason: '$category, ${seen[icon]} ile aynı simgeyi kullanıyor',
      );
      seen[icon] = category;
    }
  });

  test('category mappings avoid dart2js string-switch expressions', () {
    final source = File(
      'lib/src/config/category_visuals.dart',
    ).readAsStringSync();
    expect(source, contains('static const Map<String, IconData>'));
    expect(source, contains('static const Map<String, String>'));
    expect(source, isNot(contains('=> switch (category)')));
  });

  test('category display labels use Kurmanci names', () {
    expect(CategoryNames.localized('Edebiyat', true), 'Wêje');
    expect(CategoryNames.localized('Cografya', true), 'Erdnîgarî');
    expect(CategoryNames.localized('Paradigma', true), 'Zanist');
    expect(CategoryNames.localized('Teknolojî', true), 'Teknolojî');
  });
}
