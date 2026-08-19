import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/kilim_motifs.dart';
import 'package:zankurd_mobile/src/widgets/kilim_reveal.dart';
import 'package:zankurd_mobile/src/widgets/rolling_count.dart';

import 'support/widget_test_helpers.dart';

/// Podyum "belge gibi" duruyordu: beyaz bir kartın içinde, hareketsiz.
/// Oysa burası uygulamanın en "yarışma programı" anı. Bu bekçiler podyumun
/// kutlama dilini korur: kazanan rozeti `CategoryEmblem` (elmas + kupa/
/// madalya), birinci basamak `KilimReveal` ile açılır, puan `RollingCount`
/// ile sayar — ve podyum sekme şeridinin hemen altında, kaydırmadan
/// görünür (2026-08-19).
///
/// Kusur niçin sessiz kalmıştı: önceki bekçiler yalnız puanın tek satırda
/// kalmasına ve slotların null-güvenli kurulmasına bakıyordu; podyumun
/// KUTLANIP KUTLANMADIĞINI hiçbir test denetlemiyordu. Görsel dil (madalya,
/// açılış, sayım) testin değil simülatörün konusu sanılıyordu.
///
/// 2026-08-19 review: kazanan rozeti ilk önce `RankMedal` yapılmıştı; o
/// sıra NUMARASINI basıp kaidedeki `#sıra` ile aynı şeyi iki kez söylüyordu.
/// Rozet `CategoryEmblem`e çevrildi — elmas kimliği taşır, rakam yalnız
/// kaidede kalır.
class _Repo extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => const [
    LeaderboardEntry(
      rank: 1,
      playerId: 'p0',
      displayName: 'Rojda',
      totalScore: 8420,
      bestStreak: 11,
      roomsPlayed: 14,
    ),
    LeaderboardEntry(
      rank: 2,
      playerId: 'p1',
      displayName: 'Baran',
      totalScore: 7190,
      bestStreak: 9,
      roomsPlayed: 12,
    ),
    LeaderboardEntry(
      rank: 3,
      playerId: 'p2',
      displayName: 'Dilan',
      totalScore: 6540,
      bestStreak: 8,
      roomsPlayed: 10,
    ),
  ];

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

Future<void> _pump(WidgetTester tester, MockZanKurdRepository repo) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      child: Scaffold(body: LeaderboardScreen(repository: repo)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('podyum madalyaları CategoryEmblem ile çizilir', (tester) async {
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);
    // Üç basamak da aynı rozet dilini kullanır; sıra rakamı basan bir
    // madalya çizilmez (rakam kaidede `#sıra` olarak tek yerdedir).
    expect(find.byType(CategoryEmblem), findsNWidgets(3));
  });

  testWidgets('birinci basamak KilimReveal ile açılır', (tester) async {
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);
    // Kutlama yalnız kazananın basamağında; ikinci/üçüncü sade kalır.
    expect(find.byType(KilimReveal), findsOneWidget);
  });

  testWidgets('podyum puanları RollingCount ile sayar', (tester) async {
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);
    expect(find.byType(RollingCount), findsNWidgets(3));
  });

  testWidgets('podyum sekme şeridinin hemen altında görünür', (tester) async {
    // Yalnız ilk 3 kişi varken içerik dikeyde ORTALANIYORDU; podyum
    // ekranın ortasına itiliyor ve araya ~350px ölü boşluk giriyordu
    // (2026-08-19). Podyum banner'ın hemen altında durmalı.
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);

    final banner = tester.getRect(
      find.byKey(const ValueKey('league-banner')),
    );
    final podium = tester.getRect(
      find.byKey(const ValueKey('leaderboard-podium')),
    );
    expect(
      podium.top - banner.bottom,
      closeTo(AppSpacing.cardGap, 6),
      reason: 'podyum banner\'ın altında değil; arada ölü boşluk var',
    );
  });

  testWidgets('hareket azaltma açıkken sayım yapılmaz', (tester) async {
    // RollingCount/KilimReveal kendi hareket-azaltma bekçilerine sahiptir
    // (bkz. reward_feel_test, kilim_reveal_test). Burada yalnız bağlantının
    // doğru kurulduğu doğrulanır: kaynak, KilimReveal'e sağlayıcıdan
    // `isReducedIn` değerini geçer.
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('reducedMotion: ReducedMotionProvider.isReducedIn(context)'),
    );
  });
}
