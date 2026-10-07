import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/widgets/kilim_reveal.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Sıralamanın ilk üçü: üç pahlı kaideli podyum, 4. sıradan itibaren liste.
///
/// ## Kusur (2026-10-01, tasarım denetimi A8)
///
/// 2026-09-29 doğallık (K9) podyumu kaldırmıştı (büyük elmas avatarlar,
/// madalya halkası, taç, altın hale — "hiçbir şey kazanılmadan çizilen
/// kutlama"); ilk üç yalnız sıra rakamının renginden ayrılıyordu. Sonuç:
/// birinci ile onuncu aynı satırdı, "kim önde" bilgisi sayfanın ilk
/// bakışında okunmuyordu. Denetim ilk üçün ayrışmasını istedi.
///
/// Karar: süs değil YAPI — `LeaderboardPodium`: ortada birinci (en uzun
/// kaide), solda ikinci, sağda üçüncü; Şahnê L pahlı kaideler, avatar, ad,
/// puan. Hale, madalya halkası ve elmas hâlâ yok (K9'un asıl şikâyeti);
/// yalnız birincinin üstünde küçük bir taç. Üçten az oyuncuda ya da üç
/// sütunun sığmadığı yerde (büyük yazı) ilk üç de liste satırı kalır.
///
/// ## Niçin sessiz kalırdı
///
/// Önceki bekçi podyumun YOKLUĞUNU sabitliyordu; podyum geri gelince tek
/// başına kırılırdı ama kaidelerin sırası (2·1·3), birincinin en uzun
/// olması, "bildir" düğmesinin podyumda da bulunması ve dar ekranda ad
/// kırılması hiçbir yerde ölçülmüyordu.
class _Repo extends MockZanKurdRepository {
  _Repo({this.count = 3, this.names = _defaultNames});

  final int count;
  final List<String> names;

  static const _defaultNames = ['Rojda', 'Baran', 'Dilan', 'Zelal', 'Hêvî'];

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => List.generate(
    count,
    (i) => LeaderboardEntry(
      rank: i + 1,
      playerId: 'p$i',
      displayName: names[i % names.length],
      totalScore: 8420 - i * 900,
      bestStreak: 11 - i,
      roomsPlayed: 14 - i,
    ),
  );

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

Future<void> _pump(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      themeProvider: ThemeProvider(initialMode: mode),
      child: Scaffold(body: LeaderboardScreen(repository: repo)),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

Color? _rankDigitColor(WidgetTester tester, int rank) {
  final digit = find.descendant(
    of: find.byKey(ValueKey('leaderboard-rank-row-$rank')),
    matching: find.text('$rank'),
  );
  expect(digit, findsOneWidget, reason: 'sıra $rank rakamla yazılmalı');
  return tester.widget<Text>(digit).style?.color;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('üç ve daha çok oyuncuda podyum: 2 · 1 · 3, birinci en uzun', (
    tester,
  ) async {
    await _pump(tester, _Repo(count: 5));
    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('leaderboard-podium')), findsOneWidget);
    final r1 = tester.getRect(
      find.byKey(const ValueKey('leaderboard-rank-row-1')),
    );
    final r2 = tester.getRect(
      find.byKey(const ValueKey('leaderboard-rank-row-2')),
    );
    final r3 = tester.getRect(
      find.byKey(const ValueKey('leaderboard-rank-row-3')),
    );
    expect(r2.center.dx, lessThan(r1.center.dx), reason: 'ikinci solda');
    expect(r1.center.dx, lessThan(r3.center.dx), reason: 'üçüncü sağda');
    expect(r1.height, greaterThan(r2.height), reason: 'birinci en uzun');
    expect(r2.height, greaterThan(r3.height));
    expect(r1.bottom, r2.bottom, reason: 'kaideler aynı tabanda');
    expect(r1.bottom, r3.bottom);

    // İlk üç listede TEKRAR edilmez: liste 4. sıradan başlar.
    final list = find.byKey(const ValueKey('leaderboard-rank-list'));
    for (final rank in [1, 2, 3]) {
      expect(
        find.descendant(
          of: list,
          matching: find.byKey(ValueKey('leaderboard-rank-row-$rank')),
        ),
        findsNothing,
        reason: 'sıra $rank yalnız podyumda',
      );
    }
    for (final rank in [4, 5]) {
      expect(
        find.descendant(
          of: list,
          matching: find.byKey(ValueKey('leaderboard-rank-row-$rank')),
        ),
        findsOneWidget,
      );
    }
    final crowns = tester
        .widgetList<SahneGlyph>(find.byType(SahneGlyph))
        .where((g) => g.kind == SahneGlyphKind.crown);
    expect(crowns, hasLength(1), reason: 'taç yalnız birincide');
    expect(find.byType(KilimReveal), findsNothing);
  });

  testWidgets('tam üç oyuncuda liste yüzeyi çizilmez', (tester) async {
    await _pump(tester, _Repo());
    expect(find.byKey(const ValueKey('leaderboard-podium')), findsOneWidget);
    expect(find.byKey(const ValueKey('leaderboard-rank-list')), findsNothing);
  });

  testWidgets('üçten az oyuncuda podyum yok, düz liste', (tester) async {
    await _pump(tester, _Repo(count: 2));
    expect(find.byKey(const ValueKey('leaderboard-podium')), findsNothing);
    for (final rank in [1, 2]) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('leaderboard-rank-list')),
          matching: find.byKey(ValueKey('leaderboard-rank-row-$rank')),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets('podyumdaki oyuncu da bildirilebilir (görünür düğme)', (
    tester,
  ) async {
    await _pump(tester, _Repo(count: 4));
    for (final id in ['p0', 'p1', 'p2']) {
      expect(
        find.byKey(ValueKey('leaderboard-report-$id')),
        findsOneWidget,
        reason: '$id podyumda bildirilebilmeli (Apple 1.2)',
      );
    }
  });

  testWidgets('320 px ve uzun adlar: taşma yok, adlar tam okunur', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        themeProvider: ThemeProvider(initialMode: ThemeMode.light),
        child: Scaffold(
          body: LeaderboardScreen(
            repository: _Repo(
              count: 5,
              names: const [
                'Rojda',
                'Ayşegül Hêvîdar Bayram',
                'Abdurrahman Cizîrî',
                'Zelal',
                'Hêvî',
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('leaderboard-podium')), findsOneWidget);
    // En uzun sözcük sütundan geniş çıkınca yazı küçülür (sözcük ortasından
    // kırılıp "Abdurrahma/n" olmaz); sığan ad küçülmez. Test ortamında
    // yazı tipi ölçü fontudur, yani uzun adlar kesin taşar — ölçülen şey
    // küçültme kararıdır.
    double sizeOf(int rank, String name) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('leaderboard-rank-row-$rank')),
            matching: find.text(name),
          ),
        )
        .style!
        .fontSize!;
    expect(sizeOf(1, 'Rojda'), 14);
    expect(sizeOf(3, 'Abdurrahman Cizîrî'), lessThan(14));
    expect(sizeOf(2, 'Ayşegül Hêvîdar Bayram'), lessThan(14));
  });

  testWidgets('%200 yazıda podyum yerine liste: ilk üç ad da yazılı', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        themeProvider: ThemeProvider(initialMode: ThemeMode.light),
        child: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: LeaderboardScreen(repository: _Repo(count: 4))),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('leaderboard-podium')), findsNothing);
    for (final rank in [1, 2, 3, 4]) {
      expect(
        find.byKey(ValueKey('leaderboard-rank-row-$rank')),
        findsOneWidget,
      );
    }
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('podyum rakamları madalya rengini taşır ($mode)', (
      tester,
    ) async {
      await _pump(tester, _Repo(count: 5), mode: mode);
      final t = SahneTokens.of(
        tester.element(find.byKey(const ValueKey('leaderboard-podium'))),
      );
      expect(_rankDigitColor(tester, 1), t.goldTx);
      expect(_rankDigitColor(tester, 2), t.silverTx);
      expect(_rankDigitColor(tester, 3), t.bronzeTx);
      expect(_rankDigitColor(tester, 4), t.tx2);
      expect(_rankDigitColor(tester, 5), t.tx2);
    });
  }

  // 2026-09-29 doğallık: satır sunucunun yer tutucu adını ham basıyordu
  // ("ZanKurd Oyu…" diye kesilerek). Öteki ekranlar gibi
  // `PlayerIdentity.resolveName` ile dile göre "Oyuncu" olur; ekran okuyucu
  // da aynı adı duyar.
  testWidgets('yer tutucu ad satırda ham basılmaz', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      _Repo(names: const ['Rojda', 'ZanKurd Oyuncusu', 'Dilan']),
    );
    final row = find.byKey(const ValueKey('leaderboard-rank-row-2'));
    expect(
      find.descendant(of: row, matching: find.text('ZanKurd Oyuncusu')),
      findsNothing,
    );
    expect(
      find.descendant(of: row, matching: find.text('Oyuncu')),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(row).label,
      allOf(contains('Oyuncu'), isNot(contains('ZanKurd Oyuncusu'))),
    );
    semantics.dispose();
  });

  testWidgets('podyum dönem şeridinin hemen altında başlar', (tester) async {
    // Yalnız birkaç kişi varken içerik dikeyde ortalanıp ekranın ortasına
    // itilmemeli (2026-08-19'daki podyum bulgusu).
    await _pump(tester, _Repo());
    final list = tester.getRect(
      find.byKey(const ValueKey('leaderboard-podium')),
    );
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(list.top, lessThan(screenHeight * 0.45));
  });

  test('ekran kendi animasyon denetleyicisini kurmaz', () {
    // Sayım ve açılış kalktı; ekran kendi animasyonunu kurarsa
    // `reduced_motion_coverage_test` gibi tercihi okumalıdır.
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('AnimationController')));
    expect(source, isNot(contains('TweenAnimationBuilder')));
    expect(source, isNot(contains('haloGold')));
    final podium = File(
      'lib/src/widgets/leaderboard_podium.dart',
    ).readAsStringSync();
    expect(podium, isNot(contains('AnimationController')));
    expect(podium, isNot(contains('haloGold')));
  });
}
