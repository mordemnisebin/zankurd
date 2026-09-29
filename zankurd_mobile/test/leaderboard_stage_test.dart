// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
/// Liderlik podyumunun SAHNE bekçisi.
///
/// ## Kusur
///
/// Podyum sıradan bir yüzey kartıydı: düz zemin, ince bir kenarlık;
/// madalyalar açık temada SOLUK varyantlarına düşüyordu. Kutlamanın
/// etrafında hiçbir "sahne" yoktu (sahibin 2026-09-27 bulgusu: uygulama
/// renksiz duruyor).
///
/// ## Niçin sessiz kalırdı
///
/// Var olan bekçiler yalnız DAVRANIŞA bakıyordu (puanın tek satırda
/// kalması, kutlama widget'larının VAR OLMASI). Hiçbiri RENGİ ya da
/// okunabilirliği ölçmüyordu.
///
/// ## 2026-09-29 Şahnê:
///
/// Podyum artık bir sahne kartı değil, sayfanın kendi zemininde durur
/// (maket): elmas avatarlar madalya renginde Halka 3 taşır, birincinin
/// üstünde taç ve arkasında altın hale; kaideler Kulis/Perde tonunda, üst
/// kenarları madalya renginde. Işık hüzmesi + konfeti ressamı
/// (`StageBackdropPainter`), yeşil degrade ve beyaz isimler kalktı. Bu dosya
/// yeni sahneyi ve okunabilirliğini (WCAG ≥ 4.5:1, iki temada) sabitler.
///
/// ## 2026-09-29 doğallık:
///
/// Podyum, taç, hale ve madalya halkaları kalktı (K9): bütün sıralama tek
/// liste, ilk üç yalnız sıra rakamının renginden ayrılır. Bekçi artık
/// listenin her dilde ve temada sade kaldığını (taç yok, degrade/Ink yok,
/// adlar birincil metin) ve rakam renklerinin okunabilirliğini ölçer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// `leaderboard_top_three_test.dart` ile aynı adlar.
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

/// Dil/tema kombinasyonu değişince sağlayıcılar yeniden kurulsun diye her
/// kombinasyon ayrı bir `ValueKey` taşır.
Widget _shell({required bool isKu, required bool isDark}) {
  return KeyedSubtree(
    key: ValueKey('leaderboard-stage-$isKu-$isDark'),
    child: testShell(
      languageProvider: isKu ? kurmanciLang() : turkishLang(),
      themeProvider: ThemeProvider(
        initialMode: isDark ? ThemeMode.dark : ThemeMode.light,
      ),
      child: Scaffold(body: LeaderboardScreen(repository: _Repo())),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required bool isKu,
  required bool isDark,
}) async {
  await tester.pumpWidget(_shell(isKu: isKu, isDark: isDark));
  await tester.pump();
  // Puan `RollingCount` ile sayar (tavan 1100ms).
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pump(const Duration(milliseconds: 100));
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('başlık eylemleri marka satırında, ekranın içinde durur', (
    tester,
  ) async {
    // A iskeleti: başlık tam genişliktir; eylemler (arkadaşlar, yenile)
    // marka satırının sağındadır — başlığın ÜSTÜNDE, ekran dışına taşmadan.
    for (final width in [320.0, 360.0, 390.0]) {
      await tester.binding.setSurfaceSize(Size(width, 844));
      await _pump(tester, isKu: false, isDark: false);
      final title = tester.getRect(find.text('Sıralama'));
      for (final key in [
        'leaderboard-friends-button',
        'leaderboard-refresh-button',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey(key)));
        expect(rect.bottom, lessThanOrEqualTo(title.top), reason: '$width');
        expect(rect.right, lessThanOrEqualTo(width), reason: '$width');
        expect(rect.height, greaterThanOrEqualTo(48), reason: '$width');
      }
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'sıralama HER dilde ve temada sade liste: taç yok, degrade yok, adlar '
    'birincil metin',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await _pump(tester, isKu: isKu, isDark: isDark);
          final why = 'ku=$isKu dark=$isDark';
          expect(tester.takeException(), isNull, reason: why);

          expect(
            find.byKey(const ValueKey('leaderboard-podium')),
            findsNothing,
            reason: why,
          );
          final list = find.byKey(const ValueKey('leaderboard-rank-list'));
          expect(list, findsOneWidget, reason: why);
          final t = SahneTokens.of(tester.element(list));

          expect(
            find.descendant(of: list, matching: find.byType(Ink)),
            findsNothing,
            reason: why,
          );
          final crowns = tester
              .widgetList<SahneGlyph>(find.byType(SahneGlyph))
              .where((g) => g.kind == SahneGlyphKind.crown);
          expect(crowns, isEmpty, reason: why);

          for (final name in ['Rojda', 'Baran', 'Dilan']) {
            final nameText = tester.widget<Text>(
              find.descendant(of: list, matching: find.text(name)),
            );
            expect(nameText.style?.color, t.tx, reason: '$why: $name');
          }
        }
      }
    },
  );

  test('WCAG: sıra rakamları ve adlar iki temada da ≥ 4.5:1', () {
    for (final t in [SahneTokens.night, SahneTokens.day]) {
      // Satırlar liste grubunun Perde yüzeyinde: birinci koyu altın,
      // ikinci ve üçüncü birincil metin, gerisi ikincil metin.
      expect(_contrast(t.goldTx, t.s1), greaterThanOrEqualTo(4.5));
      expect(_contrast(t.tx, t.s1), greaterThanOrEqualTo(4.5));
      expect(_contrast(t.tx2, t.s1), greaterThanOrEqualTo(4.5));
    }
  });
}
