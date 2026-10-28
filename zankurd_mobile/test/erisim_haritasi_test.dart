// Erişim haritası bekçisi (2026-10-21).
//
// Kusur: özelliklerin "yeri belli değildi". Günlük çark yalnız mağazadan ve
// "jeton yetmedi" iletisinden açılıyordu; arkadaşlar yalnız Sıralama
// ekranındaki yalnız-simge düğmesindeydi; jeton çipi bakiye 0 iken
// kayboluyor ve her sekmede mağazaya götürmüyordu; Kurmancî öğren kapısı
// konu ızgarasının ALTINDA, sayfanın dibindeydi; seviye testi yalnız ilk
// açılış kartında ve Ayarlar'ın derinindeydi. Sessizdi: hiçbir özellik
// bozuk değildi, yalnız bulunamıyordu. Bu dosya her birini "kaç dokunuşta,
// nerede" diye ölçer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

class _CoinRepo extends MockZanKurdRepository {
  _CoinRepo(this.coins);
  final int coins;

  @override
  Future<int> loadCoinBalance() async => coins;
}

Finder _coinGlyph() => find.byWidgetPredicate(
  (w) => w is SahneGlyph && w.kind == SahneGlyphKind.coin,
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Future<void> _pumpHub(WidgetTester tester, MockZanKurdRepository repo) async {
  await tester.binding.setSurfaceSize(const Size(390, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: PlayHubScreen(repository: repo)),
    ),
  );
  await _settle(tester);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed.user': true,
      'zankurd.navTour.seen': true,
    });
  });

  testWidgets('çark Yarış sekmesinden tek dokunuşla açılır', (tester) async {
    await _pumpHub(tester, MockZanKurdRepository());
    await tester.tap(find.byKey(const ValueKey('play-hub-spin-wheel')));
    await _settle(tester);
    expect(find.byType(SpinWheelScreen), findsOneWidget);
  });

  testWidgets('arkadaşlar Yarış sekmesinden tek dokunuşla açılır', (
    tester,
  ) async {
    await _pumpHub(tester, MockZanKurdRepository());
    await tester.tap(find.byKey(const ValueKey('play-hub-friends')));
    await _settle(tester);
    expect(find.byType(FriendsScreen), findsOneWidget);
  });

  for (final coins in [0, 120]) {
    testWidgets('jeton çipi Yarış sekmesinde (bakiye $coins) mağazayı açar', (
      tester,
    ) async {
      await _pumpHub(tester, _CoinRepo(coins));
      expect(_coinGlyph(), findsOneWidget);
      await tester.tap(_coinGlyph());
      await _settle(tester);
      expect(find.byType(ShopScreen), findsOneWidget);
    });
  }

  testWidgets('öğren kapısı konu ızgarasının üstünde', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: HomeScreen(repository: MockZanKurdRepository())),
      ),
    );
    await _settle(tester);

    final learn = tester.getTopLeft(
      find.byKey(const ValueKey('home-door-learn')),
    );
    final play = tester.getTopLeft(
      find.byKey(const ValueKey('home-door-play')),
    );
    final grid = tester.getTopLeft(find.byType(HomeTopicGrid));
    expect(learn.dy, lessThan(grid.dy));
    expect(play.dy, lessThan(grid.dy));
  });

  // 2026-10-28 kurul K8 (eski "her zaman var" kararı DEĞİŞTİ): "Seviyeni
  // yeniden belirle" Öğren ekranından kalktı; Ayarlar'da durur, Öğren'de
  // yalnız seviye hiç belirlenmediyse "Seviyeni bul" daveti çıkar.
  testWidgets('seviye testi satırı öğrenme ekranında tekrar edilmez', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: LearningScreen(repository: MockZanKurdRepository())),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('learning-retake-placement')),
      findsNothing,
    );
    final settings = File(
      'lib/src/screens/settings_screen.dart',
    ).readAsStringSync();
    expect(settings.contains('K.retakePlacement'), isTrue);
  });
}
