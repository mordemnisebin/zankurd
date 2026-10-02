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

  test(
    'hikâye, arkadaş, çark, yerleştirme ve turnuva belgede ikinci katmandadır',
    () {
      // README bir ara günün etkinliğini turnuvayla aynı "ikinci katman"
      // cümlesine koyuyordu. PlayHub'da etkinlik kartı her zaman görünür;
      // turnuva `_moreOpen` arkasındadır. Hikâye LearningScreen, arkadaş
      // Liderlik, çark Mağaza, yerleştirme Ayarlar üzerindendir — ana yol
      // değil. Belge sessiz kalınca kapsam şişiyordu.
      final readme = File('README.md').readAsStringSync();
      expect(
        readme,
        isNot(contains('Turnuva ve günün etkinliği')),
        reason:
            'günlük etkinlik PlayHub\'da birincil grupta, ikinci katman değil',
      );

      for (final entry in {
        'README.md': readme,
        'ARCHITECTURE.md': architecture,
      }.entries) {
        final doc = entry.value.toLowerCase();
        expect(doc, contains('ikinci katman'), reason: entry.key);
        for (final word in [
          'hikâye',
          'arkadaş',
          'çark',
          'yerleştirme',
          'turnuva',
        ]) {
          expect(doc, contains(word), reason: '${entry.key} $word');
        }
      }

      final playHub = File(
        'lib/src/screens/play_hub_screen.dart',
      ).readAsStringSync();
      final moreIdx = playHub.indexOf('if (_moreOpen)');
      final tourneyIdx = playHub.indexOf("ValueKey('play-hub-tournament')");
      expect(moreIdx, greaterThanOrEqualTo(0));
      expect(
        tourneyIdx,
        greaterThan(moreIdx),
        reason: 'turnuva kartı Daha fazla açılınca görünür',
      );

      expect(
        File('lib/src/screens/app_shell.dart').readAsStringSync(),
        contains('LearningScreen('),
      );
      expect(
        File('lib/src/screens/learning_screen.dart').readAsStringSync(),
        contains('StoryScreen'),
      );
      expect(
        File('lib/src/screens/leaderboard_screen.dart').readAsStringSync(),
        contains('FriendsScreen'),
      );
      expect(
        File('lib/src/screens/shop_screen.dart').readAsStringSync(),
        contains('SpinWheelScreen'),
      );
      expect(
        File('lib/src/screens/settings_screen.dart').readAsStringSync(),
        contains('LevelPlacementScreen'),
      );
    },
  );

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

  test('LearnHomeScreen HomeScreen sarmalayıcısıdır, eş ekran değil', () {
    // ARCHITECTURE "LearnHomeScreen / HomeScreen — günlük görev…" diye
    // iki eş ekran yazınca yeni geliştirici ikinci bir ana sayfa arıyor.
    // Kaynak tek StatelessWidget: AppShell sekme 0 LearnHomeScreen açar,
    // o da HomeScreen döner (kategori gezinmesi). Belge sarmalayıcıyı
    // söylemezse sapma sessiz kalır.
    final learnHome = File(
      'lib/src/screens/learn_home_screen.dart',
    ).readAsStringSync();
    expect(learnHome, contains('class LearnHomeScreen'));
    expect(learnHome, contains('return HomeScreen('));

    final appShell = File('lib/src/screens/app_shell.dart').readAsStringSync();
    expect(appShell, contains('LearnHomeScreen('));

    final ui = section(
      '### 1. UI Katmanı (`lib/src/screens/`)',
      '### 2. State Management (`lib/src/providers/`)',
    );
    expect(
      ui,
      contains('sarmala'),
      reason:
          'ARCHITECTURE LearnHomeScreen’i HomeScreen ile eş ekran gibi '
          'yazmamalı; sarmalayıcı olduğunu söylemeli',
    );
    expect(ui, contains('LearnHomeScreen'));
    expect(ui, contains('HomeScreen'));

    final readme = File('README.md').readAsStringSync();
    expect(
      readme,
      contains('LearnHomeScreen'),
      reason: 'README Öğren kökünün LearnHomeScreen olduğunu söylemeli',
    );
    expect(
      readme,
      contains('HomeScreen'),
      reason: 'README sarmalanan ekranı adıyla söylemeli',
    );
    expect(
      readme,
      contains('sarmala'),
      reason: 'README LearnHomeScreen’i HomeScreen sarmalayıcısı diye yazmalı',
    );
  });
}
