// 2026-10-28 TUR 4 — jüri maddeleri U1, U2, U3, U4, U10, U11 bekçileri
// (U5/U6/U8 `soru_sonuc_ortak_sahne_test.dart`, U12 `duello_inceleme_istemci_test.dart`).
//
// ## Kusurlar
//
// * U1 Öğren: ünite çubuğu "0/5 ders" derken hero kapsülü "0/21 ders" diyordu;
//   aynı ekranda iki çelişen kesir. Toplam yalnız "Tüm dersler (+N)" satırında.
// * U2 Günün turu: bordo hero + ayrı dağ illüstrasyonu iki üst üste blok; içerik
//   ile sabit "Başla" arasında ölü boşluk.
// * U3 Çark: sahne koyu, üst çubuk beyazdı; çark ikonu üç yerde üç ayrı glif.
// * U4 Profil: yeni oyuncuda dört ayrı boş kart (0/7, "Henüz soru çözmedin",
//   "İlk rekorunu kır", Başarılar ipucu).
// * U10 Üst çubuk: sıralama ve hikâyede sağda iki eylem.
// * U11 Ana sayfa: ayrı Seviye/XP kartı (seviye profilde durur).
//
// ## Niçin sessiz kalırdı
//
// Hiçbiri istisna ya da taşma değildir; yalnız metin sayısı, ağaçtaki blok
// sayısı, piksel aralığı ve renk ölçülünce yakalanır.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/profile/profile_week_strip.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

Widget _plain(Widget child, {String lang = 'tr'}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang(lang)),
    ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ChangeNotifierProvider<ReducedMotionProvider>(
      create: (_) => ReducedMotionProvider(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

class _ContestRepo extends MockZanKurdRepository {
  @override
  Future<Contest?> loadTodayContest() async => Contest(
    id: 'c1',
    dayKey: DateTime.utc(2026, 8, 4),
    themeNameKu: 'Pisporê Ziman',
    themeDescriptionKu: 'Bibe hostayê ziman!',
    themeNameTr: 'Dil Uzmanı',
    themeDescriptionTr: 'Dilin ustası ol!',
    category: 'Ziman',
    difficultyMin: 1,
    difficultyMax: 3,
    participationReward: 10,
    rank1Reward: 500,
    rank2Reward: 300,
    rank3Reward: 100,
    questionCount: 10,
  );
}

class _SpinRepo extends MockZanKurdRepository {
  @override
  Future<bool> canSpinToday() async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() async => SyncManager.resetForTesting());

  testWidgets('U1: Öğren ekranında iki çelişen "x/y ders" kesri yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      _plain(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
    final fractions = <String>{};
    for (final e in find.byType(Text).evaluate()) {
      final text = (e.widget as Text).data ?? '';
      final m = RegExp(r'(\d+)\s*/\s*(\d+)\s*ders').firstMatch(text);
      if (m != null) fractions.add(text);
    }
    expect(
      fractions.length,
      lessThanOrEqualTo(1),
      reason: 'ünite çubuğu ile hero çelişen iki kesir gösteriyor: $fractions',
    );
    // 2026-10-29 son kurul tur 2 (E): hero'nun "1. ders" sıra kapsülü
    // kalktı (düğüm, ünite kartı ve ders kartıyla aynı başlangıcı dördüncü
    // kez söylüyordu). Kesir kuralı yukarıda korunur.
    expect(
      find.byKey(const ValueKey('learning-progress-capsule')),
      findsNothing,
    );
  });

  for (final size in const [Size(390, 844), Size(360, 740)]) {
    testWidgets('U2: Günün turu tek hero; içerik ile Başla arası ≤ 120 '
        '(${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          themeProvider: ThemeProvider(initialMode: ThemeMode.light),
          languageProvider: turkishLang(),
          child: ContestScreen(repository: _ContestRepo()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(ArenaHero), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ArenaHero),
          matching: find.byKey(const ValueKey('contest-scene')),
        ),
        findsOneWidget,
        reason: 'dağ sahnesi hero içine gömülü olmalı',
      );
      expect(
        find.byType(SahneEntryScene),
        findsOneWidget,
        reason: 'ayrı ikinci illüstrasyon bloğu geri geldi',
      );
      final start = tester.getRect(find.byKey(const ValueKey('contest-start')));
      var contentBottom = 0.0;
      for (final e in find.byType(Text).evaluate()) {
        final r = tester.getRect(find.byWidget(e.widget));
        if (r.bottom < start.top && r.bottom > contentBottom) {
          contentBottom = r.bottom;
        }
      }
      expect(
        start.top - contentBottom,
        lessThanOrEqualTo(120),
        reason: 'içerik ile Başla arasında ölü boşluk',
      );
    });
  }

  testWidgets('U3: çark ekranında üst çubuk da koyu sahne', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_plain(SpinWheelScreen(repository: _SpinRepo())));
    await tester.pump();
    await tester.pump();
    final bar = find.byKey(const ValueKey('sahne-pushed-stage-bar'));
    expect(bar, findsOneWidget);
    // 2026-10-29 G1: çubuk sahne zeminiyle (gece dağları) kaynaşır: saydam.
    expect(tester.widget<ColoredBox>(bar).color, Colors.transparent);
    expect(find.byKey(const ValueKey('sahne-night-stage')), findsOneWidget);
    final rect = tester.getRect(bar);
    expect(rect.top, lessThan(80));
    final title = tester.widget<Text>(find.text('Günün çarkı'));
    expect(title.style?.color, SahneTokens.night.tx);
  });

  test('U3: çark ikonu oyun merkezi, mağaza ve çark ekranında aynı glif', () {
    for (final path in const [
      'lib/src/screens/play_hub_screen.dart',
      'lib/src/screens/spin_wheel_screen.dart',
    ]) {
      final src = File(path).readAsStringSync();
      expect(src, isNot(contains('AppIcons.dice')), reason: path);
      expect(src, contains('AppIcons.ferrisWheel'), reason: path);
    }
    final shop = File('lib/src/screens/shop_screen.dart').readAsStringSync();
    expect(
      shop,
      contains('icon: AppIcons.ferrisWheel,\n      role: SahneRole.gold'),
    );
    final hub = File('lib/src/screens/play_hub_screen.dart').readAsStringSync();
    expect(
      hub,
      contains("icon: AppIcons.ferrisWheel,\n      role: SahneRole.gold"),
      reason: 'oyun merkezi satırı ile mağaza satırı AYNI renkte (altın)',
    );
  });

  testWidgets('U4: yeni oyuncuda profil TEK "Başlangıç" kartı taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    final card = find.byKey(const ValueKey('profile-start-card'));
    for (var i = 0; i < 40 && card.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(card, findsOneWidget);
    expect(find.text('Başlangıç'), findsOneWidget);
    expect(find.text('İlk yarışını oyna'), findsOneWidget);
    for (final gone in const [
      'Henüz soru çözmedin.',
      'İlk rekorunu kır',
      'İlk başarın için bir yarış bitir.',
    ]) {
      expect(find.text(gone), findsNothing, reason: '"$gone" ayrı boş kart');
    }
    expect(find.byType(ProfileWeekStrip), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is SahneButton && w.isPrimary),
      findsOneWidget,
      reason: 'profilde tek turuncu eylem',
    );
  });

  testWidgets('U10: sıralama ve hikâye çubuğunda sağda en çok 1 eylem', (
    tester,
  ) async {
    // Hikâye: çubuk sağında tek "⋯".
    await tester.pumpWidget(_plain(StoryScreen(story: cayxaneStory)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('story-menu')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-restart')), findsNothing);
    expect(find.byKey(const ValueKey('story-open-guide')), findsNothing);
    final appBar = find.byType(AppBar);
    expect(
      find.descendant(of: appBar, matching: find.byType(SahneIconButton)),
      findsNWidgets(2),
      reason: 'geri + ⋯ (sağda tek eylem)',
    );
  });

  test('U10: sıralama çubuğunda yenile düğmesi yok, çekerek yenilenir', () {
    final src = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    expect(src, isNot(contains("'leaderboard-refresh-button'")));
    expect(src, contains('onRefresh: _pullRefresh'));
  });

  test('U11: ana sayfada ayrı Seviye/XP kartı yok', () {
    final home = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(home, isNot(contains('ProgressSummary')));
    expect(home, isNot(contains('home-progress-summary')));
    expect(
      File('lib/src/widgets/progress_summary.dart').existsSync(),
      isFalse,
      reason: 'seviye özeti bileşeni ölü kod olarak geri gelmesin',
    );
  });

  testWidgets('U11: Bugün panelinde tamamlanmamış görevde XP rozeti yok', (
    tester,
  ) async {
    final missions = [
      DailyMission(
        type: MissionType.completeQuiz,
        target: 3,
        coinReward: 0,
        progress: 1,
      ),
      DailyMission(
        type: MissionType.answerCorrect,
        target: 10,
        coinReward: 0,
        progress: 4,
      ),
      DailyMission(
        type: MissionType.keepStreak,
        target: 1,
        coinReward: 0,
        progress: 1,
        completed: true,
      ),
    ];
    await tester.pumpWidget(
      _plain(
        Scaffold(
          body: SingleChildScrollView(
            child: DailyMissionsCard(
              isKu: false,
              missions: missions,
              onClaimReward: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('+100 XP'), findsNothing);
    // Alınabilir görevin ödül düğmesi yine durur ve ekranda en çok 3 satır.
    expect(
      find.byKey(const ValueKey('claim-mission-keepStreak:1')),
      findsOneWidget,
    );
    final rows = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'home-mission-row-',
              ),
        )
        .evaluate()
        .length;
    expect(rows, lessThanOrEqualTo(3));
  });

  test('U7: ızgara fiyat çipi liste ile AYNI bileşen ve genişlik', () {
    final src = File('lib/src/screens/shop_screen.dart').readAsStringSync();
    // İki yerleşim de aynı `_buildBuyButton` ile çizilir; ızgara tam
    // genişliğe yayılmaz, listeyle aynı 112 px'e oturur.
    expect(
      RegExp(
        '_buildBuyButton\\(item, ku, expand: true\\)',
      ).allMatches(src).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      src,
      contains('maxWidth: _largeText(context) ? double.infinity : _priceWidth'),
    );
  });

  test('U8: HUD etiketleri ve joker adı ≥ 12 sp', () {
    expect(SahneType.eyebrow.fontSize, greaterThanOrEqualTo(12));
    expect(SahneType.caption.fontSize, greaterThanOrEqualTo(12));
    final joker = File(
      'lib/src/widgets/sahne/sahne_buttons.dart',
    ).readAsStringSync();
    expect(joker, contains('fontSize: 12,'));
    expect(joker, contains('c.withValues(alpha: 0.4)'));
  });
}
