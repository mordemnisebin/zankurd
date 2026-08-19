import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';

import 'support/widget_test_helpers.dart';

/// Podyum puanı büyük yazıda okunur kalır.
///
/// %200 yazıda puan "50/00" gibi iki satıra bölünüyordu. Sayı bir sözcük
/// değildir: bölününce anlamını kaybeder ve birinciyle üçüncüyü
/// karşılaştırmak imkânsızlaşır — podyumun tek işi tam da o karşılaştırma
/// (2026-08-04 görsel denetimi).
///
/// Çözüm değeri kısaltmak ya da erişilebilirlik ölçeğini kapatmak DEĞİL:
/// yalnız sayıya `BoxFit.scaleDown` uygulanır, yani sığdığı sürece
/// kullanıcının seçtiği boyutta çizilir.
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
  // Veri asenkron yüklenir; önce future çözülsün, sonra puan artık
  // `RollingCount` ile saydığı için (tavan 1100ms) ve birinci basamak
  // `KilimReveal` ile açıldığı için (1100ms) animasyonlar tamamlansın.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Podyum puanının çizildiği metin düğümü — tek satırda mı kaldı?
///
/// Puan artık `RollingCount` ile sayarak çıkıyor; bu bileşen tek satırı
/// `maxLines: 1` ile garanti eder (eski düz `Text` gibi `softWrap: false`
/// taşımaz — `maxLines: 1` zaten sarmayı kapatır). Bu yüzden bekçi
/// `softWrap` yerine `maxLines`e bakar (2026-08-19).
void _expectSingleLineScores(WidgetTester tester, String score) {
  final finder = find.text(score);
  expect(finder, findsWidgets, reason: 'puan $score hiç çizilmedi');
  for (final widget in tester.widgetList<Text>(finder)) {
    expect(
      widget.maxLines,
      1,
      reason: 'puan birden çok satıra bölünürse sayı anlamını kaybeder',
    );
  }
}

const _phone = Size(390, 844);
const _narrow = Size(320, 900);
const _ipad = Size(834, 1194);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('%200 yazıda podyum puanı tek satırda kalır', (tester) async {
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
    testWidgets('$count oyuncuyla podyum puanı bozulmaz', (tester) async {
      await _pump(tester, size: _phone, count: count);
      expect(tester.takeException(), isNull);
      _expectSingleLineScores(tester, '5000');
      // Sahte oyuncu eklenmedi: yalnız var olan slotlar çizilir.
      expect(
        find.byKey(const ValueKey('podium-slot-3')),
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
