import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_reveal.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
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
///
/// 2026-09-29 Şahnê: kutlama dili Şahnê'ye taşındı. Madalya artık elmas
/// avatarın Halka 3'üdür (altın / gümüş / bronz), birincinin üstünde taç
/// glifi ve arkasında altın hale durur; `CategoryEmblem` madalyaları ve
/// büyük kilim açılışı (`KilimReveal`) kalktı — kilim motifi yalnız kilim
/// göz şeridinde yaşar. Puan yine `RollingCount` ile sayar.
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

  testWidgets('birinci taç glifi taşır; madalyalar halka olarak çizilir', (
    tester,
  ) async {
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);
    final crowns = tester
        .widgetList<SahneGlyph>(find.byType(SahneGlyph))
        .where((g) => g.kind == SahneGlyphKind.crown);
    expect(crowns, hasLength(1), reason: 'taç yalnız birincinin');
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('podium-slot-1')),
        matching: find.byType(SahneGlyph),
      ),
      findsOneWidget,
    );
    // Sıra rakamı yalnız kaidede: her basamakta tek bir rakam metni.
    for (final rank in [1, 2, 3]) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('podium-slot-$rank')),
          matching: find.text('$rank'),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('büyük kilim açılışı yok (kilim yalnız göz şeridinde)', (
    tester,
  ) async {
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);
    expect(find.byType(KilimReveal), findsNothing);
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

    final podium = tester.getRect(
      find.byKey(const ValueKey('leaderboard-podium')),
    );
    if (kWeeklyLeagueEnabled) {
      final banner = tester.getRect(
        find.byKey(const ValueKey('league-banner')),
      );
      expect(
        podium.top - banner.bottom,
        closeTo(AppSpacing.cardGap, 6),
        reason: 'podyum banner\'ın altında değil; arada ölü boşluk var',
      );
    } else {
      // Lig bandı kapalı (kWeeklyLeagueEnabled): podyum, dönem sekmelerinin
      // altında ilk ekranın üst yarısında durmalı; ortaya itilmemeli.
      final screenHeight =
          tester.view.physicalSize.height / tester.view.devicePixelRatio;
      expect(
        podium.top,
        lessThan(screenHeight * 0.45),
        reason: 'podyum ekranın ortasına itilmiş; arada ölü boşluk var',
      );
    }
  });

  testWidgets('podyumda ekrana ait animasyon denetleyicisi yok', (
    tester,
  ) async {
    // Sayım `RollingCount`un kendi hareket-azaltma bekçisine tabidir (bkz.
    // reward_feel_test). Ekran kendi animasyonunu kurmaz; kurarsa
    // `reduced_motion_coverage_test` gibi o da tercihi okumalıdır.
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('AnimationController')));
    expect(source, isNot(contains('TweenAnimationBuilder')));
  });
}
