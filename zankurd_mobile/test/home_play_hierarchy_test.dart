// 2026-09-29 doğallık (K7): oda eylemleri ikincil düğme, günün etkinliğinde
// adını tekrarlayan rozet yok.
// 2026-09-29 Şahnê: ana ekranın kapıları ve oyun merkezinin öteki yolları
// degrade kart değil, liste satırıdır (`SahneListRow`); bekçi
// "tek birincil (turuncu) eylem, öteki yollar sakin ve erişilebilir"
// kuralını bu dilde sorar.
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _homeShell({
  required bool isKu,
  required bool isDark,
  MockZanKurdRepository? repository,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
      ),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(
      key: ValueKey('home-$isKu-$isDark'),
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: HomeScreen(
        repository: repository ?? MockZanKurdRepository(),
        onOpenLearning: () async {},
        onOpenPlay: () {},
      ),
    ),
  );
}

Widget _playShell({required bool isKu, required bool isDark}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
      ),
    ],
    child: MaterialApp(
      key: ValueKey('play-$isKu-$isDark'),
      theme: isDark ? AppTheme.dark() : AppTheme.light(),
      home: PlayHubScreen(repository: MockZanKurdRepository()),
    ),
  );
}

void _expectActionSemantics(WidgetTester tester, String key) {
  final data = tester
      .getSemantics(find.byKey(ValueKey(key)))
      .getSemanticsData();
  expect(data.hasAction(ui.SemanticsAction.tap), isTrue, reason: key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AchievementStore.resetInstance();
    SharedPreferences.setMockInitialValues({
      'zankurd.achievements.unlocked': ['first_game'],
    });
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

  // 2026-09-29 Şahnê: kapılar ve oyun yolları liste satırıdır; bekçi aynı
  // kuralı yeni dilde sorar.
  // 2026-09-27: ana ekran tek turuncu eylem + iki kapı + konu ızgarası
  // düzenine geçti. Bekçinin koruduğu kural aynı: ekranda tek bir birincil
  // (turuncu) eylem vardır, diğer yollar erişilebilir ama sakin kalır.
  testWidgets(
    'Home has one daily hero action and calmer accessible alternative modes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await tester.pumpWidget(_homeShell(isKu: isKu, isDark: isDark));
          await tester.pump(const Duration(seconds: 1));

          expect(
            find.byKey(const ValueKey('home-daily-task-start')),
            findsOneWidget,
          );
          _expectActionSemantics(tester, 'home-daily-task-start');

          for (final door in ['home-door-learn', 'home-door-play']) {
            final finder = find.byKey(ValueKey(door));
            expect(finder, findsOneWidget, reason: door);
            _expectActionSemantics(tester, door);
            // 2026-09-29 Şahnê: kapı bir liste satırıdır ve rolü Agir
            // değildir (Agir bir rol değil, tek birincil eylemin rengidir);
            // satırda dolgulu düğme yok.
            final tile = tester.widget<SahneModeTile>(finder);
            expect(tile.role, isNot(SahneRole.neutral), reason: door);
            expect(
              find.descendant(of: finder, matching: find.byType(FilledButton)),
              findsNothing,
              reason: 'Turuncu yalnız günün dersi düğmesine ayrılmış: $door',
            );
          }

          expect(find.byKey(const ValueKey('home-topic-grid')), findsOneWidget);
          final ziman = find.byKey(const ValueKey('home-topic-Ziman'));
          await tester.ensureVisible(ziman);
          _expectActionSemantics(tester, 'home-topic-Ziman');

          // Eski dört kapılı düzenin parçaları geri gelmemeli.
          for (final legacy in [
            'home-lessons-row',
            'home-browse-categories-row',
            'home-continue-section',
            'home-duel-row',
          ]) {
            expect(find.byKey(ValueKey(legacy)), findsNothing, reason: legacy);
          }
        }
      }
    },
  );

  testWidgets(
    'Play Hub keeps quick duel primary while every other mode stays accessible without a full accent fill',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await tester.pumpWidget(_playShell(isKu: isKu, isDark: isDark));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const ValueKey('play-hub-quick-duel')),
            findsOneWidget,
          );
          // Turnuva `kTournamentEnabled` açıkken doğrudan satırdır (2026-10-27;
          // eskiden "Daha fazla" ardındaydı). Aşağıdaki blok altın rolünü
          // denetler.
          if (!kTournamentEnabled) {
            expect(
              find.byKey(const ValueKey('play-hub-tournament')),
              findsNothing,
            );
          } else {
            _expectActionSemantics(tester, 'play-hub-tournament');
          }
          // 2026-09-29 Şahnê: öteki yollar liste satırıdır (liste grubunda);
          // degrade, gölge ve dolgulu düğme taşımazlar. Günün etkinliği
          // yarış rolünde; turnuva ödül (Zêr) rolü.
          //
          // 2026-09-29 doğallık (K7): "Oda kur" ve "Kodla katıl" yan yana iki
          // İKİNCİL düğmedir (Kulis tonu, Agir değil); günün etkinliğinin
          // "Bugün" rozeti kalktı (satırın adı zaten "Günün soruları").
          // 2026-10-24: "Oda kur" / "Kodla katıl" düğmeleri alt sayfaya
          // taşındı; ekranda Oda, Nîl (sosyal) rolünde bir mod kartıdır ve
          // dolgulu düğme (Agir) taşımaz.
          for (final key in ['play-hub-room']) {
            final finder = find.byKey(ValueKey(key));
            expect(finder, findsOneWidget, reason: key);
            expect(tester.widget(finder), isA<SahneModeTile>(), reason: key);
            expect(
              (tester.widget(finder) as SahneModeTile).role,
              SahneRole.social,
              reason: '$key Nîl (sosyal) rolünde olmalı',
            );
            expect(
              find.descendant(of: finder, matching: find.byType(FilledButton)),
              findsNothing,
              reason: '$key Agir düğme taşımaz',
            );
            _expectActionSemantics(tester, key);
          }
          for (final key in ['play-hub-create-room', 'play-hub-join-room']) {
            expect(find.byKey(ValueKey(key)), findsNothing, reason: key);
          }
          for (final key in ['play-hub-daily-contest']) {
            final finder = find.byKey(ValueKey(key));
            // Meydan okuma satırı (2026-10-13) günün etkinliğini tembel
            // listenin kurulu bölgesinden çıkardı.
            await tester.scrollUntilVisible(finder, 200);
            expect(finder, findsOneWidget);
            // 2026-10-22 tasarım kurulu: günün turu Boyax mod kartıdır
            // (dolu rol rengi; Agir değil, birincil düğme taşımaz).
            // K5 (2026-10-28 kurul): günün turu standart liste satırı
            // (eski "Boyax dolu mod kartı" kararı DEĞİŞTİ).
            expect(tester.widget(finder), isA<SahneListRow>(), reason: key);
            expect(
              find.descendant(of: finder, matching: find.byType(FilledButton)),
              findsNothing,
              reason: key,
            );
            _expectActionSemantics(tester, key);
          }
          final daily = tester.widget<SahneListRow>(
            find.byKey(const ValueKey('play-hub-daily-contest')),
          );
          expect(daily.role, SahneRole.race);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('play-hub-daily-contest')),
              matching: find.byType(SahneBadge),
            ),
            findsNothing,
          );
          if (!kTournamentEnabled) {
            expect(tester.takeException(), isNull);
            continue;
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('play-hub-tournament')),
          );
          final tournament = find.byKey(const ValueKey('play-hub-tournament'));
          expect(tournament, findsOneWidget);
          expect(
            tester.widget<SahneListRow>(tournament).role,
            SahneRole.gold,
            reason: 'Turnuva prestij/ödül rolünü altınla paylaşmalı.',
          );
          _expectActionSemantics(tester, 'play-hub-tournament');
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  // "Daha fazla" katmanı yalnız turnuva bayrağı açıkken çizilir.
  testWidgets(
    'tournament row keeps button semantics without a nested header role',
    skip: !kTournamentEnabled,
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_playShell(isKu: false, isDark: false));
      await tester.pumpAndSettle();

      final row = find.byKey(const ValueKey('play-hub-tournament'));
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      final data = tester.getSemantics(row).getSemanticsData();
      expect(data.flagsCollection.isHeader, isFalse);
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    },
  );

  testWidgets(
    'öğren kapısı tamamlanan ders sayısını sıfırdan büyükken gösterir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = MockZanKurdRepository();
      await tester.pumpWidget(_homeShell(isKu: false, isDark: false));
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-door-learn')),
          matching: find.byIcon(AppIcons.check),
        ),
        findsNothing,
      );

      await repo.markLessonCompleted('alphabet_1');
      await repo.markLessonCompleted('everyday_1');
      await tester.pumpWidget(
        _homeShell(isKu: false, isDark: true, repository: repo),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('home-door-learn')),
          matching: find.text('Tamamlanan ders: 2'),
        ),
        findsOneWidget,
      );
      // T12: sayı, açıklamasız rozet yerine tamamlanan ders alt metninde.
    },
  );
}
