import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ARCHITECTURE.md PremiumService'i `lib/src/providers/` listesine yazınca
/// dosya `lib/src/services/premium_service.dart` iken yeni geliştirici
/// yanlış klasörde arıyordu. Belge hiç taranmadığı için sapma sessiz kaldı.
void main() {
  late String architecture;

  setUpAll(() {
    architecture = File('ARCHITECTURE.md').readAsStringSync();
  });

  String section(String heading, String nextHeading) {
    final start = architecture.indexOf(heading);
    final end = architecture.indexOf(nextHeading);
    expect(start, greaterThanOrEqualTo(0), reason: 'eksik başlık: $heading');
    expect(
      end,
      greaterThan(start),
      reason: 'sıra bozuk: $heading → $nextHeading',
    );
    return architecture.substring(start, end);
  }

  test('PremiumService servis katmanında, providers klasöründe değil', () {
    expect(File('lib/src/services/premium_service.dart').existsSync(), isTrue);
    expect(
      File('lib/src/providers/premium_service.dart').existsSync(),
      isFalse,
    );

    final providers = section(
      '### 2. State Management (`lib/src/providers/`)',
      '### 3. Servisler (`lib/src/services/`)',
    );
    final services = section(
      '### 3. Servisler (`lib/src/services/`)',
      '### 4. Veri Katmanı (`lib/src/data/`)',
    );

    expect(providers, isNot(contains('PremiumService')));
    expect(services, contains('PremiumService'));
    expect(services, contains('lib/src/services/premium_service.dart'));

    final readme = File('README.md').readAsStringSync();
    expect(readme, contains('premium_service.dart'));
    expect(
      readme,
      isNot(contains('providers/premium')),
      reason: 'README PremiumService’i providers altına koymamalı',
    );
  });

  test('BadgeService veri katmanında, providers klasöründe değil', () {
    expect(File('lib/src/data/badge_service.dart').existsSync(), isTrue);
    expect(File('lib/src/providers/badge_service.dart').existsSync(), isFalse);

    final providers = section(
      '### 2. State Management (`lib/src/providers/`)',
      '### 3. Servisler (`lib/src/services/`)',
    );
    final data = section(
      '### 4. Veri Katmanı (`lib/src/data/`)',
      '### 5. Yerel Depolar (`lib/src/data/`)',
    );

    expect(providers, isNot(contains('BadgeService')));
    expect(data, contains('BadgeService'));
    expect(data, contains('lib/src/data/badge_service.dart'));
  });
}
