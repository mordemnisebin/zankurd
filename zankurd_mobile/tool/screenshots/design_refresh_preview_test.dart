// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  // Görsel alınmadan önce giriş/ölçek animasyonları ve gecikmeli asset
  // çözümlemeleri tamamlansın. Sonsuz animasyonlar olabildiği için
  // pumpAndSettle yerine sabit, ölçülü bir bekleme kullanılır.
  await tester.pump(const Duration(milliseconds: 1200));
  await tester.pump();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    print('SHOT: ${file.absolute.path}');
  });
}

Widget _wrap({
  required Widget child,
  required ThemeMode mode,
  required String lang,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: lang),
      ),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider(initialMode: mode)),
      ChangeNotifierProvider(create: (_) => ReducedMotionProvider()),
      ChangeNotifierProvider(create: (_) => SoundProvider()),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      home: child,
    ),
  );
}

void main() {
  const out = 'docs/screenshots/design_refresh';

  testWidgets('home light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: HomeScreen(
              repository: MockZanKurdRepository(),
              displayName: 'Zelal',
              scrollController: ScrollController(),
              onOpenPlay: () {},
              onOpenCategories: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/home_light.png');
  }, tags: ['preview']);

  testWidgets('home dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.dark,
        lang: 'ku',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: HomeScreen(
              repository: MockZanKurdRepository(),
              displayName: 'Zelal',
              scrollController: ScrollController(),
              onOpenPlay: () {},
              onOpenCategories: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/home_dark.png');
  }, tags: ['preview']);

  testWidgets('categories light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: CategoriesTab(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/categories_light.png');
  }, tags: ['preview']);

  testWidgets('play hub light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: PlayHubScreen(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/play_hub_light.png');
  }, tags: ['preview']);

  testWidgets('splash', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(
          key: key,
          child: const SplashScreen(
            next: SizedBox.shrink(),
            duration: Duration(days: 1),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await _capture(tester, key, '$out/splash.png');
  }, tags: ['preview']);

  testWidgets('onboarding', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(
          key: key,
          child: OnboardingScreen(onComplete: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/onboarding.png');
  }, tags: ['preview']);

  testWidgets('result', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: QuizResultScreen(
              repository: repo,
              room: repo.createRoom(),
              score: 850,
              correctCount: 8,
              wrongCount: 2,
              totalQuestions: 10,
              bestStreak: 5,
              answerRecords: const <AnswerRecord>[],
              coinsAwarded: 40,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/result_light.png');
  }, tags: ['preview']);

  testWidgets('leaderboard light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: LeaderboardScreen(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/leaderboard_light.png');
  }, tags: ['preview']);

  testWidgets('matchmaking light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: MatchmakingScreen(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await _capture(tester, key, '$out/matchmaking_light.png');
  }, tags: ['preview']);

  testWidgets('quiz options light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 420));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(
          backgroundColor: AppTheme.lightBg,
          body: RepaintBoundary(
            key: key,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  for (var i = 0; i < 4; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: QuizOptionTile(
                        index: i,
                        answer: const [
                          'Newroz',
                          'Govend',
                          'Dengbêj',
                          'Kilam',
                        ][i],
                        selected: false,
                        correct: false,
                        disabled: false,
                        onTap: () {},
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/quiz_options_light.png');
  }, tags: ['preview']);

  testWidgets('quiz screen light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    final repo = MockZanKurdRepository();
    final questions = repo.questions.take(10).toList();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(
          key: key,
          child: QuizScreen(
            repository: repo,
            room: repo.createRoom(),
            questions: questions,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, '$out/quiz_light.png');
  }, tags: ['preview']);

  testWidgets('profile light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: ProfileScreen(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/profile_light.png');
  }, tags: ['preview']);

  testWidgets('settings light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(
          key: key,
          child: SettingsScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/settings_light.png');
  }, tags: ['preview']);

  testWidgets('shop light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(
          key: key,
          child: ShopScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/shop_light.png');
  }, tags: ['preview']);

  testWidgets('learning light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: LearningScreen(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/learning_light.png');
  }, tags: ['preview']);

  testWidgets('room light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(
          key: key,
          child: RoomScreen(repository: repo, initialRoom: repo.createRoom()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/room_light.png');
  }, tags: ['preview']);

  testWidgets('tournament light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(
          key: key,
          child: TournamentScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await _capture(tester, key, '$out/tournament_light.png');
  }, tags: ['preview']);

  testWidgets('sign in light', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.light,
        lang: 'tr',
        child: RepaintBoundary(key: key, child: const SignInScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await _capture(tester, key, '$out/signin_light.png');
  }, tags: ['preview']);

  testWidgets('play hub dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.dark,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: PlayHubScreen(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/play_hub_dark.png');
  }, tags: ['preview']);

  testWidgets('categories dark', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final key = GlobalKey();
    await tester.pumpWidget(
      _wrap(
        mode: ThemeMode.dark,
        lang: 'tr',
        child: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: CategoriesTab(repository: MockZanKurdRepository()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _capture(tester, key, '$out/categories_dark.png');
  }, tags: ['preview']);
}
