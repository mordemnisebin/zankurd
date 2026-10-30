import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'T4 Google tek renk çiziliyordu; eski bekçi yalnız G harfini yasaklıyordu',
    () {
      final source = File(
        'lib/src/widgets/auth_social_buttons.dart',
      ).readAsStringSync();

      expect(source, contains('assets/brand/google_g.svg'));
      expect(source, isNot(contains('BrandIcons.google')));
      final logo = File('assets/brand/google_g.svg').readAsStringSync();
      for (final color in ['#EA4335', '#4285F4', '#FBBC05', '#34A853']) {
        expect(logo, contains(color));
      }
      expect(source, isNot(contains("Text(\n                      'G'")));
    },
  );

  test('misafir hesap bağlama da uydurma G harfi kullanmaz', () {
    // Yükseltme diyaloğu `profile/profile_widgets.dart` (part) dosyasına
    // taşındı (denetleyici ömrü düzeltmesi); ekran dosyasıyla birlikte taranır.
    final source = [
      File('lib/src/screens/profile_screen.dart').readAsStringSync(),
      File('lib/src/screens/profile/profile_widgets.dart').readAsStringSync(),
      File('lib/src/widgets/auth_social_buttons.dart').readAsStringSync(),
    ].join('\n');

    expect(source, contains('assets/brand/google_g.svg'));
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
