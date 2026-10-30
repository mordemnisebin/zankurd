// 2026-10-29 canlılık katmanı: R2 mod kartı bekçisi lobi kartını sınar.
// 2026-10-28 kurul turu 2 (R2, R4, R7, R8) bekçisi.
//
// Kusur: tur 1 sadeleştirmesi uygulamayı "bankacılık gibi" bıraktı (dört
// model canlılık 4-7). Tur 2 renge kontrollü yüzey tonuyla geri döner ama
// tur 1'in ilkelerini BOZMADAN: ekranda tek turuncu birincil eylem, nötr üst
// çubuk. Bu dosya tur 2'nin dört kararını sabitler; her biri sessizce geri
// alınabilirdi (görsel kararlar testle değil gözle denetlenir, biri
// "sadeleştirirken" tonu siler):
//
// * R2  mod kartları (Öğren/Yarış/Sırayla düello/Oda) rolün hafif tonunda;
// * R4  giriş ve açılış ortası dağ + güneş manzarasıyla dolu, tek satır vaat;
// * R7  mağaza fiyat düğmesi Zêr (altın), turuncu DEĞİL; alınamayan hâlâ
//       ayrı (gri + kilit);
// * R8  ana sayfa sırası görev → Öğren/Yarış → Bugün (≤3 satır) → Konular →
//       Günün sözü (küçük).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart'
    show GateAuthProvider, freshMockRepository, testShell;
import 'support/realistic_device.dart' show loadAppFonts;

Widget _wrap(Widget child, {bool dark = false, String lang = 'tr'}) =>
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang(lang),
        ),
        ChangeNotifierProvider(create: (_) => AuthProvider.test()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<PremiumService>(
          create: (_) => PremiumService.fallback(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUpAll(loadAppFonts);
  setUp(() {
    freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.achievements.unlocked': ['first_game'],
    });
    AchievementStore.resetInstance();
  });

  group('R8 ana sayfa sırası', () {
    testWidgets('görev → Öğren/Yarış → Bugün (≤3 satır) → Konular → söz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 2600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Depo ayarı SON adımdır: `freshMockRepository` tercihleri sıfırlar.
      final repo = freshMockRepository();
      SharedPreferences.setMockInitialValues({
        'zankurd.achievements.unlocked': ['first_game'],
      });
      AchievementStore.resetInstance();
      await (await StreakStore.load()).recordPlay();
      await (await DailyMissionStore.load()).reportQuizCompleted(
        correctAnswers: 6,
        category: 'Ziman',
        streakAlive: true,
      );
      await tester.pumpWidget(
        _wrap(
          HomeScreen(
            repository: repo,
            onOpenLearning: () async {},
            onOpenPlay: () {},
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump(const Duration(milliseconds: 200));
      }

      double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
      final task = top('home-daily-task');
      final learn = top('home-door-learn');
      final today = top('home-missions-compact-section');
      final topics = top('home-topic-grid');
      expect(task, lessThan(learn), reason: 'görev önce');
      expect(learn, lessThan(today), reason: 'Öğren/Yarış sonra, Bugün öncesi');
      expect(today, lessThan(topics), reason: 'Bugün Konular\'ın ÜSTÜNDE');
      final quote = find.byKey(const ValueKey('home-daily-quote'));
      if (quote.evaluate().isNotEmpty) {
        expect(tester.getTopLeft(quote).dy, greaterThan(topics));
        // Küçük söz: gövde boyunda yazı (başlık boyu değil).
        final ku = tester.widget<Text>(
          find.byKey(const ValueKey('home-daily-quote-ku')),
        );
        expect(ku.style?.fontSize, SahneType.bodyStrong.fontSize);
      }
      // Bugün paneli en çok 3 görev satırı.
      final rows = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('home-mission-row-'),
      );
      expect(rows.evaluate().length, lessThanOrEqualTo(3));
      expect(rows.evaluate().length, greaterThan(0));
    });
  });

  group('R2 mod kartları tonlu', () {
    for (final dark in [false, true]) {
      testWidgets('Öğren ve Yarış rolün hafif tonunda (dark=$dark)', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(390, 1800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _wrap(
            HomeScreen(
              repository: freshMockRepository(),
              onOpenLearning: () async {},
              onOpenPlay: () {},
            ),
            dark: dark,
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        final t = dark ? SahneTokens.night : SahneTokens.day;
        for (final (key, role) in [
          ('home-door-learn', SahneRole.learn),
          ('home-door-play', SahneRole.race),
        ]) {
          // 2026-10-29 canlılık katmanı: ana sayfa kapıları da doygun lobi
          // kartı (rolün degradesi); eski "rolün hafif tonu" kararı
          // geçersiz. Hâlâ turuncu değil.
          final lobby = tester.widget<Ink>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byKey(const ValueKey('mode-tile-lobby')),
            ),
          );
          final g =
              (lobby.decoration! as ShapeDecoration).gradient!
                  as LinearGradient;
          // 2026-10-29 vay 2A: lobi kartı İKİ temada da rolün doygun GÜNDÜZ
          // rengidir (gecede kararmış renkler "kirli" okunuyordu, Astra).
          const vivid = SahneTokens.day;
          expect(
            g.colors.first,
            role == SahneRole.learn ? vivid.learnFill : vivid.raceFill,
            reason: key,
          );
          expect(g.colors.first, isNot(t.act), reason: key);
        }
        // Birincil turuncu hâlâ tek: kartlar turuncu değil.
        expect(
          find.byType(FilledButton).evaluate().length,
          lessThanOrEqualTo(1),
        );
      });
    }
  });

  group('R4 giriş ve açılış sahnesi', () {
    testWidgets(
      'T4 kompakt manzara ve vaat, giriş yollarını ilk karede bırakır',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(375, 667);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          testShell(
            child: const MediaQuery(
              data: MediaQueryData(
                size: Size(375, 667),
                padding: EdgeInsets.only(top: 20),
              ),
              child: SignInScreen(),
            ),
            authProvider: GateAuthProvider(),
          ),
        );
        await tester.pumpAndSettle();
        final hero = find.byKey(const ValueKey('sign-in-hero-banner'));
        expect(hero, findsOneWidget);
        expect(
          find.descendant(
            of: hero,
            matching: find.byKey(const ValueKey('entry-scene-vista')),
          ),
          findsOneWidget,
        );
        // T4: 176 px manzara sosyal yolları aşağı itiyordu. Manzara korunur;
        // 72 px kompakt düzen, dört yolu kaydırmadan erişilebilir tutar.
        expect(tester.getSize(hero).height, 72);
        expect(find.text('Kurmancî öğren, bilgini yarıştır.'), findsOneWidget);
        for (final label in [
          'Misafir olarak devam et',
          'Apple ile devam et',
          'Google ile devam et',
          'E-posta ile giriş',
        ]) {
          expect(find.text(label).hitTestable(), findsOneWidget, reason: label);
        }
        // Flutter invariant kontrolü addTearDown'dan önce çalışır.
        debugDefaultTargetPlatformOverride = null;
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('açılış her adımda manzara taşır; dil adımında vaat var', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_wrap(OnboardingScreen(onComplete: () {})));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('onboarding-scene')), findsOneWidget);
      expect(find.text('Kurmancî öğren, bilgini yarıştır.'), findsOneWidget);
    });

    test('vaat dizesi TR ve KU tanımlı', () {
      expect(
        Tr.forKu(K.entryPromise, false),
        'Kurmancî öğren, bilgini yarıştır.',
      );
      expect(
        Tr.forKu(K.entryPromise, true),
        'Kurmancî hîn bibe, zanîna xwe bi pêşbirkê biceribîne.',
      );
    });
  });
}
