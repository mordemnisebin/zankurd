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

/// Sıralamanın ilk üçü: podyum yok, sıralı liste.
///
/// ## Kusur
///
/// 2026-09-29 doğallık (K9): ilk üç büyük elmas avatarlarla kaidelere
/// diziliyordu — madalya renginde halka, birincide taç ve arkasında altın
/// hale. Üç kişilik bir haftada ekranın tamamı bu podyumdu; hiçbir şey
/// kazanılmadan çizilen bir kutlama "üretilmiş" görünüyordu ve asıl bilgiyi
/// (kim kaç puanla kaçıncı) büyük süslerin arasına dağıtıyordu.
///
/// Karar: bütün sıralama tek liste. İlk üç yalnız sıra rakamının renginden
/// ayrılır (birinci altın, ikinci gümüş, üçüncü bronz, gerisi ikincil
/// metin); taç, hale, madalya halkası ve kaide yok.
///
/// 2026-09-29 doğallık: ikinci ve üçüncü eskiden birincil metinle aynıydı
/// (temaya duyarlı gümüş/bronz metin belirteci yoktu); `SahneTokens`
/// `silverTx`/`bronzeTx` kazandı, beklenti ona göre güncellendi.
///
/// ## Niçin sessiz kalırdı
///
/// Eski bekçiler (bu dosyanın önceki adı `leaderboard_podium_celebration_
/// test`) kutlamanın VARLIĞINI sabitliyordu: taç sayısı, madalya halkası,
/// podyumun sekme şeridine yakınlığı. Kutlamanın geri gelmesini hiçbir test
/// yakalamazdı; bu dosya yokluğunu ve sıra rakamlarının ayrımını ölçer.
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

  testWidgets('ilk üç de liste satırıdır; podyum, taç ve hale yok', (
    tester,
  ) async {
    await _pump(tester, _Repo());
    expect(tester.takeException(), isNull);

    expect(find.byKey(const ValueKey('leaderboard-podium')), findsNothing);
    for (final rank in [1, 2, 3]) {
      final row = find.byKey(ValueKey('leaderboard-rank-row-$rank'));
      expect(row, findsOneWidget, reason: 'sıra $rank');
      expect(
        find.ancestor(of: row, matching: find.byType(SahneListGroup)),
        findsOneWidget,
        reason: 'sıra $rank öteki satırlarla aynı listede',
      );
    }
    final crowns = tester
        .widgetList<SahneGlyph>(find.byType(SahneGlyph))
        .where((g) => g.kind == SahneGlyphKind.crown);
    expect(crowns, isEmpty, reason: 'taç yok');
    expect(find.byType(KilimReveal), findsNothing);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('ilk üç yalnız sıra rakamının renginden ayrılır ($mode)', (
      tester,
    ) async {
      await _pump(tester, _Repo(count: 5), mode: mode);
      final t = SahneTokens.of(
        tester.element(find.byKey(const ValueKey('leaderboard-rank-list'))),
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

  testWidgets('liste dönem şeridinin hemen altında başlar', (tester) async {
    // Yalnız birkaç kişi varken içerik dikeyde ortalanıp ekranın ortasına
    // itilmemeli (2026-08-19'daki podyum bulgusu listeye de geçerli).
    await _pump(tester, _Repo());
    final list = tester.getRect(
      find.byKey(const ValueKey('leaderboard-rank-list')),
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
  });
}
