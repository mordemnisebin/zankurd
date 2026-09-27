/// Liderlik podyumunun SAHNE bekçisi.
///
/// ## Kusur
///
/// Podyum sıradan bir yüzey kartıydı: düz `AppTheme.surfaceColor` zemin,
/// ince bir kenarlık; madalyalar açık temada SOLUK varyantlarına düşüyordu
/// (`silverLight`, `bronzeLight`). Kutlamanın etrafında (kazananın
/// `KilimReveal` ile açılması, puanın `RollingCount` ile sayması) hiçbir
/// "sahne" yoktu — Yarış sekmesi aynı sorunu `StageBackdropPainter` ile
/// çözdü (bkz. `stage_backdrop.dart`, `_QuickDuelHero`), ama podyum hâlâ
/// eski, belge gibi yüzeyindeydi (sahibin 2026-09-27 bulgusu: uygulama
/// renksiz duruyor; podyum da aynı sahnede durmalı).
///
/// ## Niçin sessiz kalırdı
///
/// Var olan bekçiler yalnız DAVRANIŞA bakıyordu: puanın tek satırda kalması
/// (`leaderboard_podium_score_test.dart`), kutlama widget'larının VAR OLMASI
/// (`leaderboard_podium_celebration_test.dart` — `CategoryEmblem`,
/// `KilimReveal`, `RollingCount`), anahtarların doğru yerde durması
/// (`leaderboard_result_profile_test.dart`). Hiçbiri RENGİ ya da
/// okunabilirliği ölçmüyordu: podyumun düz mü sahne mi olduğu, isim
/// metninin hangi renkte çizildiği, kaidenin/vitrin unvanının kontrastı
/// hiçbir yerde denetlenmiyordu — görsel dil testin değil simülatörün
/// konusu sanılıyordu (`play_hub_stage_test.dart`ın kendi başlığındaki
/// itirafla aynı kusur). Bu dosya sahneyi (`StageBackdropPainter`, tek
/// çizici, beyaz isimler, konfetinin içerikle kesişmemesi) VE
/// okunabilirliğini (WCAG ≥ 4.5:1) birlikte sabitler.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';
import 'package:zankurd_mobile/src/widgets/stage_backdrop.dart';

import 'support/widget_test_helpers.dart';

/// `leaderboard_podium_celebration_test.dart` ile AYNI 3 kişi: isimler sabit
/// olduğu için testte "isim metni" doğrudan `find.text(...)` ile aranabilir.
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

/// `play_hub_stage_test.dart` ile aynı iskele: dil/tema kombinasyonu
/// değişince `testShell`in `create:` ile kurulan sağlayıcıları (dil)
/// GÜNCELLENMEZ, yalnız YENİDEN KURULUR — her kombinasyon ayrı bir
/// `ValueKey` ile ağacın şeklini değiştirip sıfırdan kurulmasını sağlar.
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
  // Puan `RollingCount` ile sayar (tavan 1100ms), birinci basamak
  // `KilimReveal` ile açılır (1100ms) — `leaderboard_podium_celebration_
  // test.dart` ile aynı bekleme.
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pump(const Duration(milliseconds: 100));
}

/// WCAG göreli kontrast oranı — `AppColors._contrast` ile aynı formül; o
/// yardımcı private olduğu için burada yinelenir (`play_hub_stage_test.dart`
/// aynı yinelemeyi yapar).
double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

/// `leaderboard_screen.dart`daki private `_stageGold` ile AYNI değer —
/// başka bir dosyadan içe aktarılamadığı için (Dart görünürlüğü dosya
/// bazlıdır) burada yinelenir.
const Color _stageGold = Color(0xFFF2C75C);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'podyum HER dilde ve temada aynı sahnede durur: kimlik gradyanı, tek '
    'StageBackdropPainter, beyaz isimler, konfeti içerikle kesişmez',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await _pump(tester, isKu: isKu, isDark: isDark);
          expect(
            tester.takeException(),
            isNull,
            reason: 'ku=$isKu dark=$isDark',
          );

          final podium = find.byKey(const ValueKey('leaderboard-podium'));
          expect(podium, findsOneWidget, reason: 'ku=$isKu dark=$isDark');

          // Podyum artık düz bir yüzey değil: kimlik yeşilinden koyu ormana
          // inen sahne gradyanı — HER temada aynı (tema podyumu etkilemez).
          final container = tester.widget<Container>(podium);
          final decoration = container.decoration! as BoxDecoration;
          final gradient = decoration.gradient! as LinearGradient;
          expect(
            gradient.colors,
            contains(AppTheme.culturalBrandBg),
            reason: 'ku=$isKu dark=$isDark: podyum kimlik yeşiliyle açılmalı',
          );
          expect(
            gradient.colors,
            contains(AppTheme.surface),
            reason: 'ku=$isKu dark=$isDark: podyum koyu ormana inmeli',
          );

          // Sahne deseni TEK bir çizici: diğer CustomPaint'ler (madalya
          // amblemindeki elmas deseni, kazananın KilimReveal'i) farklı
          // painter türleri taşır, bu yüzden predikat yalnız birini bulur.
          final stage = find.descendant(
            of: podium,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is StageBackdropPainter,
            ),
          );
          expect(
            stage,
            findsOneWidget,
            reason: 'ku=$isKu dark=$isDark: podyum TEK bir sahne fonu çizmeli',
          );

          for (final name in ['Rojda', 'Baran', 'Dilan']) {
            final nameText = tester.widget<Text>(
              find.descendant(of: podium, matching: find.text(name)),
            );
            expect(
              nameText.style?.color,
              Colors.white,
              reason: 'ku=$isKu dark=$isDark: $name beyaz olmalı',
            );
          }

          // Konfeti hiçbir metnin, ikonun ya da avatarın üstüne düşmez —
          // aynı teknik `play_hub_stage_test.dart`da: sahnenin gerçek
          // kutusunu al, sabit konfeti dikdörtgenlerini ona göre kaydır,
          // içerikle çakışmadığını doğrula.
          final stageBox = tester.getRect(stage);
          final confetti = StageBackdropPainter.confettiRects(
            stageBox.size,
          ).map((rect) => rect.shift(stageBox.topLeft)).toList();
          final content = [
            ...find
                .descendant(of: podium, matching: find.byType(Text))
                .evaluate(),
            ...find
                .descendant(of: podium, matching: find.byType(Icon))
                .evaluate(),
            ...find
                .descendant(of: podium, matching: find.byType(PlayerAvatar))
                .evaluate(),
          ].map((element) => tester.getRect(find.byWidget(element.widget)));
          for (final rect in content) {
            for (final piece in confetti) {
              expect(
                rect.overlaps(piece),
                isFalse,
                reason:
                    'ku=$isKu dark=$isDark: konfeti $piece, içerik $rect '
                    'ile kesişiyor.',
              );
            }
          }
        }
      }
    },
  );

  test(
    'WCAG kontrastı: sahne beyazı, vitrin altını ve kaide ink\'i ≥ 4.5:1',
    () {
      // İsim metni: sahne gradyanının İKİ ucunda da okunmalı.
      expect(
        _contrast(Colors.white, AppTheme.culturalBrandBg),
        greaterThanOrEqualTo(4.5),
        reason: 'beyaz isim, sahnenin kimlik (üst) ucunda okunmalı',
      );
      expect(
        _contrast(Colors.white, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'beyaz isim, sahnenin koyu (alt) ucunda okunmalı',
      );

      // Vitrin unvanı: `_stageGold`, düz `AppTheme.gold`un aksine küçük
      // (10px) yazı için de sahnenin İKİ ucunda AA'yı geçmeli.
      expect(
        _contrast(_stageGold, AppTheme.culturalBrandBg),
        greaterThanOrEqualTo(4.5),
        reason: 'vitrin unvanının altın tonu, sahnenin kimlik ucunda okunmalı',
      );
      expect(
        _contrast(_stageGold, AppTheme.surface),
        greaterThanOrEqualTo(4.5),
        reason: 'vitrin unvanının altın tonu, sahnenin koyu ucunda okunmalı',
      );

      // Kaide: ink (`AppTheme.lightTextPrimary`) HER üç madalyada da
      // gradyanın İKİ ucuna (açık üst = %18 beyaza yaklaştırılmış, doygun
      // alt = düz madalya rengi) karşı ≥4.5:1 olmalı.
      for (final color in [AppTheme.gold, AppTheme.silver, AppTheme.bronze]) {
        final top = Color.lerp(color, Colors.white, 0.18)!;
        expect(
          _contrast(AppTheme.lightTextPrimary, top),
          greaterThanOrEqualTo(4.5),
          reason: 'ink, kaide gradyanının açık (üst) ucunda okunmalı: $color',
        );
        expect(
          _contrast(AppTheme.lightTextPrimary, color),
          greaterThanOrEqualTo(4.5),
          reason: 'ink, kaide gradyanının doygun (alt) ucunda okunmalı: $color',
        );
      }
    },
  );
}
