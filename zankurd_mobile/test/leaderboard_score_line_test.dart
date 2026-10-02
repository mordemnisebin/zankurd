import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Sıralama puanı büyük yazıda okunur kalır.
///
/// %200 yazıda puan "50/00" gibi iki satıra bölünüyordu. Sayı bir sözcük
/// değildir: bölününce anlamını kaybeder ve birinciyle üçüncüyü
/// karşılaştırmak imkânsızlaşır (2026-08-04 görsel denetimi).
///
/// Çözüm değeri kısaltmak ya da erişilebilirlik ölçeğini kapatmak DEĞİL:
/// yalnız sayıya `BoxFit.scaleDown` uygulanır, yani sığdığı sürece
/// kullanıcının seçtiği boyutta çizilir.
///
/// 2026-09-29 doğallık (K9): podyum kalktı, ilk üç de liste satırıdır. Bu
/// dosyanın önceki adı `leaderboard_podium_score_test`; bekçi aynı sözü
/// artık her sıra satırının puanı için tutar.
class _Repo extends MockZanKurdRepository {
  _Repo({this.count = 3, this.score = 5000});

  final int count;
  final int score;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => List.generate(
    count,
    (i) => LeaderboardEntry(
      playerId: 'p$i',
      displayName: 'Oyuncu ${i + 1}',
      totalScore: score - i,
      bestStreak: 3,
      roomsPlayed: 7,
      rank: i + 1,
    ),
  );

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  int count = 3,
  int score = 5000,
  double textScale = 2.0,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      themeProvider: ThemeProvider(initialMode: mode),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: LeaderboardScreen(
            repository: _Repo(count: count, score: score),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Puan metni tek satırda mı kaldı?
///
/// Puan `FittedBox(scaleDown)` içindedir: metin sınırsız genişlikte dizilir
/// (sarmaz), yalnız gerekirse küçülerek sığar. Bekçi çizilen metnin
/// yüksekliğine bakar: iki satıra bölünen puan bir satırlık yükseklikten
/// uzun olur.
void _expectSingleLineScores(WidgetTester tester, String score) {
  final finder = find.text(score);
  expect(finder, findsWidgets, reason: 'puan $score hiç çizilmedi');
  final scale = MediaQuery.textScalerOf(tester.element(finder.first));
  final oneLine =
      scale.scale(SahneType.bodyStrong.fontSize!) *
      SahneType.bodyStrong.height!;
  for (final element in finder.evaluate()) {
    final height = (element.renderObject! as RenderBox).size.height;
    expect(
      height,
      lessThan(oneLine * 1.5),
      reason: 'puan birden çok satıra bölünürse sayı anlamını kaybeder',
    );
  }
}

const _phone = Size(390, 844);
const _narrow = Size(320, 900);
const _ipad = Size(834, 1194);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('%200 yazıda sıra puanı tek satırda kalır', (tester) async {
    await _pump(tester, size: _narrow);
    expect(tester.takeException(), isNull);
    _expectSingleLineScores(tester, '5000');
  });

  for (final score in const [9999, 87654]) {
    testWidgets('$score puanı %200 yazıda bölünmez', (tester) async {
      await _pump(tester, size: _narrow, score: score);
      expect(tester.takeException(), isNull);
      _expectSingleLineScores(tester, '$score');
    });
  }

  for (final count in const [1, 2, 3]) {
    testWidgets('$count oyuncuyla sıra puanı bozulmaz', (tester) async {
      await _pump(tester, size: _phone, count: count);
      expect(tester.takeException(), isNull);
      _expectSingleLineScores(tester, '5000');
      // Sahte oyuncu eklenmedi: yalnız var olan satırlar çizilir.
      expect(
        find.byKey(const ValueKey('leaderboard-rank-row-3')),
        count >= 3 ? findsOneWidget : findsNothing,
      );
    });
  }

  testWidgets('iPad ve %200 yazıda puan bölünmez', (tester) async {
    await _pump(tester, size: _ipad);
    expect(tester.takeException(), isNull);
    _expectSingleLineScores(tester, '5000');
  });

  testWidgets('karanlık temada puan bölünmez', (tester) async {
    await _pump(tester, size: _narrow, mode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    _expectSingleLineScores(tester, '5000');
  });

  testWidgets('normal yazıda da puan tam değeriyle görünür', (tester) async {
    // Kısaltma yok: `FittedBox` yalnız KÜÇÜLTÜR, değeri değiştirmez.
    await _pump(tester, size: _phone, textScale: 1.0, score: 87654);
    expect(find.text('87654'), findsWidgets);
    expect(find.textContaining('…'), findsNothing);
  });
}
