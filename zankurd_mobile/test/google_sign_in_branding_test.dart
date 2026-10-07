import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Google girişi uydurma metin G yerine marka glifini kullanır', () {
    final source = File(
      'lib/src/screens/sign_in_screen.dart',
    ).readAsStringSync();

    expect(source, contains('BrandIcons.google'));
    expect(source, isNot(contains("Text(\n                      'G'")));
  });

  test('misafir hesap bağlama da uydurma G harfi kullanmaz', () {
    final source = File(
      'lib/src/screens/profile_screen.dart',
    ).readAsStringSync();

    expect(source, contains('BrandIcons.google'));
    expect(
      source,
      isNot(contains("icon: const Text(\n                        'G'")),
    );
  });

  test('ekran turu marka ikon fontunu da yükler', () {
    final source = File(
      'tool/screenshots/screen_tour_test.dart',
    ).readAsStringSync();

    expect(source, contains("'FontAwesomeBrands'"));
    expect(source, contains('Font-Awesome-7-Brands-Regular-400.otf'));
    expect(source, isNot(contains('font_awesome_flutter')));
  });
}
