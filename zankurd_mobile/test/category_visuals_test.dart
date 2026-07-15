import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';

void main() {
  test('all supported categories retain explicit visual mappings', () {
    const expectedImagePaths = {
      'Ziman': 'assets/question_images/cat_ziman.webp',
      'Çand': 'assets/question_images/cat_cand.webp',
      'Dîrok': 'assets/question_images/cat_dirok.webp',
      'Edebiyat': 'assets/question_images/cat_edebiyat.webp',
      'Cografya': 'assets/question_images/cat_cografya.webp',
      'Muzîk': 'assets/question_images/cat_muzik.webp',
      'Siyaset': 'assets/question_images/cat_siyaset.webp',
      'Paradigma': 'assets/question_images/cat_paradigma.webp',
      'Teknolojî': 'assets/question_images/cat_paradigma.webp',
    };
    for (final category in expectedImagePaths.keys) {
      expect(CategoryVisuals.icon(category), isNot(Icons.category_outlined));
      expect(CategoryVisuals.imagePath(category), expectedImagePaths[category]);
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
    expect(CategoryNames.localized('Paradigma', true), 'Paradîgma');
    expect(CategoryNames.localized('Teknolojî', true), 'Teknolojî');
  });
}
