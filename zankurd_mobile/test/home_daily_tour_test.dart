// Bekçi: ana ekranda günün oyunu TEKTİR ve adı "Günün turu"dur.
//
// 2026-10-24 sahibin kararı (ana ekranı gördükten sonra): "Günün soruları ve
// Günün turu nereden bilinsin, teke indir". Kusur: kahraman kart "Günün
// dersi" (süresiz 5–10 soru), Yarış sekmesi "Günün soruları" (süreli 10
// soru) diyordu; ikisi de "günün oyunu" gibi duruyordu. Burada:
//  * oynanmadıysa kart turu açar (ContestScreen),
//  * bugün bittiyse "bitirdin" + geri sayım + ikincil "Pratik yap",
//  * "Günün soruları" adı hiçbir yerde kullanıcıya görünmez,
//  * ilk tab "Ana sayfa" / "Rûpela sereke" der (Öğren değil),
//  * yarış kapısı TEKtir (kısa "Yarış"); düello sonucu hazırsa rozet taşır,
//  * 320 px + yazı ölçeği 2'de iki dilde de taşma yok.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/home/daily_tour_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'support/widget_test_helpers.dart';

class _ReadyDuelRepository extends MockZanKurdRepository {
  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async => [
    AsyncDuelSummary(
      duelId: 'd1',
      status: AsyncDuelStatus.completed,
      role: AsyncDuelRole.creator,
      myCorrect: 5,
      opponentCorrect: 3,
      outcome: AsyncDuelOutcome.win,
      createdAt: DateTime(2026, 10, 24),
      seen: false,
    ),
  ];
}

/// Oyuncuyu "ilk oturum" dışına alır; [tourDone] ise bugünün turunu bitirir.
Future<MockZanKurdRepository> _seed({
  required bool tourDone,
  MockZanKurdRepository? repository,
}) async {
  final repo = repository ?? freshMockRepository();
  SharedPreferences.setMockInitialValues({
    'zankurd.onboarding.seen': true,
    'zankurd.profileName.completed.user': true,
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.achievements.unlocked': ['first_game'],
  });
  AchievementStore.resetInstance();
  if (tourDone) {
    final store = await AchievementStore.load();
    await store.recordQuizResult(
      category: 'Tevlihev',
      totalQuestions: 10,
      correctCount: 7,
      bestStreak: 4,
      dailyStreak: 1,
      userScore: 600,
      dailyQuiz: true,
    );
  }
  return repo;
}

Future<void> _pumpHome(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  bool ku = false,
  Size size = const Size(390, 844),
  double textScale = 1.0,
}) async {
  tester.view.devicePixelRatio = 3.0;
  tester.view.physicalSize = size * 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(
          body: HomeScreen(
            repository: repo,
            onOpenLearning: () async {},
            onOpenPlay: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Günün turu kahraman kartı', () {
    testWidgets('oynanmadı: tek ad "Günün turu", Başla turu açar', (
      tester,
    ) async {
      final repo = await _seed(tourDone: false);
      await _pumpHome(tester, repo);

      expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
      expect(find.text('Günün turu'), findsOneWidget);
      expect(find.textContaining('10 soru'), findsOneWidget);
      expect(find.text('Günün soruları'), findsNothing);
      expect(find.text('Günün dersi'), findsNothing);
      expect(
        find.byKey(const ValueKey('home-daily-task-practice')),
        findsNothing,
      );

      await tester.tap(find.byKey(const ValueKey('home-daily-task-start')));
      await tester.pumpAndSettle();
      expect(find.byType(ContestScreen), findsOneWidget);
    });

    testWidgets('bugün bitti: sonuç + geri sayım + ikincil Pratik yap', (
      tester,
    ) async {
      final repo = await _seed(tourDone: true);
      await _pumpHome(tester, repo);

      expect(find.text('Bugünkü turu bitirdin'), findsOneWidget);
      expect(find.textContaining('Yeni tur'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-daily-task-start')), findsNothing);
      expect(find.text('Pratik yap'), findsOneWidget);
    });

    testWidgets('Pratik yap süresiz açıklamalı oturumu açar, tur sayılmaz', (
      tester,
    ) async {
      final repo = await _seed(tourDone: true);
      await _pumpHome(tester, repo);

      await tester.tap(find.byKey(const ValueKey('home-daily-task-practice')));
      await tester.pumpAndSettle();

      final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
      expect(quiz.room.name, 'Pratik');
      expect(quiz.dailyQuiz, isFalse, reason: 'pratik günün turu sayılmaz');
      expect(quiz.enableTimer, isFalse);
      expect(quiz.experience, QuizExperience.learning);
    });

    testWidgets('geri sayım bir sonraki yerel gün başına göredir', (
      tester,
    ) async {
      expect(
        DailyTourCard.untilNextTour(DateTime(2026, 10, 24, 20, 48)),
        const Duration(hours: 3, minutes: 12),
      );
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: DailyTourCard(
              isKu: false,
              loading: false,
              doneToday: true,
              onStart: () {},
              onPractice: () {},
              now: DateTime(2026, 10, 24, 20, 48),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Yeni tur 3 sa 12 dk sonra'), findsOneWidget);
    });

    testWidgets('Kurmancî: ad ve geri sayım', (tester) async {
      final repo = await _seed(tourDone: true);
      await _pumpHome(tester, repo, ku: true);
      expect(find.text('Te dora îro qedand'), findsOneWidget);
      expect(find.textContaining('Dora nû piştî'), findsOneWidget);
      expect(find.text('Pratîk bike'), findsOneWidget);
      expect(find.text('Pirsên rojê'), findsNothing);
    });
  });

  group('Sekme adı ve yarış kapısı', () {
    testWidgets('ilk sekme Ana sayfa / Rûpela sereke der', (tester) async {
      final repo = await _seed(tourDone: false);
      for (final ku in [false, true]) {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        await tester.pumpWidget(
          ZanKurdApp(
            repository: repo,
            authProvider: FakeAuthProvider(),
            languageProvider: ku ? kurmanciLang() : turkishLang(),
          ),
        );
        await tester.pumpAndSettle();
        final tab = find.byKey(const ValueKey('nav-learn'));
        expect(
          find.descendant(
            of: tab,
            matching: find.text(ku ? 'Rûpela sereke' : 'Ana sayfa'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: tab,
            matching: find.text(ku ? 'Hîn bibe' : 'Öğren'),
          ),
          findsNothing,
        );
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets('ana ekranda tek yarış kapısı var, kısa adı "Yarış"', (
      tester,
    ) async {
      final repo = await _seed(tourDone: false);
      await _pumpHome(tester, repo);
      final door = find.byKey(const ValueKey('home-door-play'));
      expect(door, findsOneWidget);
      expect(
        find.descendant(of: door, matching: find.text('Yarış')),
        findsOneWidget,
      );
      expect(find.text('Arkadaşınla yarış'), findsNothing);
      expect(find.textContaining('Sırayla düello'), findsNothing);
      expect(find.text('Sonuç hazır'), findsNothing);
    });

    testWidgets('düello sonucu hazırsa kapıda rozet, ayrı satır yok', (
      tester,
    ) async {
      final repo = await _seed(
        tourDone: false,
        repository: _ReadyDuelRepository(),
      );
      await _pumpHome(tester, repo);
      final door = find.byKey(const ValueKey('home-door-play'));
      expect(
        find.descendant(of: door, matching: find.text('Sonuç hazır')),
        findsOneWidget,
      );
      expect(find.textContaining('Sırayla düello'), findsNothing);
    });
  });

  group('Taşma 320 px, yazı ölçeği 2', () {
    for (final ku in [false, true]) {
      for (final done in [false, true]) {
        testWidgets(
          'ana ekran ${ku ? 'KU' : 'TR'} ${done ? 'bitti' : 'oynanmadı'}',
          (tester) async {
            final repo = await _seed(
              tourDone: done,
              repository: _ReadyDuelRepository(),
            );
            await _pumpHome(
              tester,
              repo,
              ku: ku,
              size: const Size(320, 640),
              textScale: 2.0,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets('alt sekme çubuğu KU 320 px büyük yazıda taşmaz', (
      tester,
    ) async {
      final repo = await _seed(tourDone: false);
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(320, 640) * 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: ZanKurdApp(
            repository: repo,
            authProvider: FakeAuthProvider(),
            languageProvider: kurmanciLang(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
