import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/main.dart';
import 'support/widget_test_helpers.dart';

class _EmptyFavoritesRepository extends MockZanKurdRepository {
  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    return const [];
  }
}

class _FailingLeaderboardRepository extends MockZanKurdRepository {
  int loadCalls = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) {
    loadCalls += 1;
    if (loadCalls > 1) {
      return Future.value(const []);
    }
    return Future<List<LeaderboardEntry>>.delayed(
      Duration.zero,
      () => throw StateError('leaderboard unavailable'),
    );
  }
}

class _EmptyLeaderboardRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return const [];
  }
}

class _SingleWinnerRepository extends MockZanKurdRepository {
  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return const [
      LeaderboardEntry(
        rank: 1,
        playerId: 'winner',
        displayName: 'Bawer',
        totalScore: 110,
        bestStreak: 4,
        roomsPlayed: 1,
      ),
    ];
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('leaderboard screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Liderlik Tablosu'), findsOneWidget);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('leaderboard podium renders polished ranked slots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('podium-slot-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('podium-slot-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('podium-slot-3')), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);
  });

  testWidgets('leaderboard podium text stays readable on dark panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        // Bu test kasıtlı koyu panel okunabilirliğini doğrular; açık-varsayılan
        // olsa da burada koyu temayı zorlarız.
        themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
        child: LeaderboardScreen(repository: _SingleWinnerRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final nameText = tester.widget<Text>(find.text('Bawer'));

    expect(nameText.style?.color, equals(AppTheme.textPrimary));
  });

  testWidgets('leaderboard single winner does not stretch across landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: LeaderboardScreen(repository: _SingleWinnerRepository()),
      ),
    );
    await tester.pumpAndSettle();

    final slotRect = tester.getRect(
      find.byKey(const ValueKey('podium-slot-1')),
    );
    expect(slotRect.width, lessThan(260));
  });

  testWidgets('profile screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    // Dalga 5: başlıktaki dişli ikon kaldırıldı; ayarlar girişi HESAP
    // menüsündeki 'Ayarlar' satırına tekleştirildi.
    expect(find.byKey(const ValueKey('profile-settings-top')), findsNothing);
  });

  testWidgets('opens the leaderboard from the bottom nav', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: FakeAuthProvider(),
        languageProvider: turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    // Profil > 'Topluluk ve Ligler' kaldırıldı (Rêz sekmesiyle mükerrerdi,
    // 2026-07-18 Faz 9). Ana yol artık doğrudan alt nav'daki Liderlik sekmesi
    // (KU'da 'Rêz', TR'de 'Liderlik').
    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();

    expect(find.text('Liderlik Tablosu'), findsOneWidget);
    expect(find.text('Rojda'), findsWidgets);
  });

  testWidgets('finishes a quiz and opens the result screen', (tester) async {
    final room = repository.createRoom();
    final questions = repository.questions.take(3).toList();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => turkishLang(),
          ),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
          ChangeNotifierProvider<ChildSafetyProvider>(
            create: (_) => ChildSafetyProvider(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: questions,
            enableTimer: false,
          ),
        ),
      ),
    );

    Future<void> answerQuestion(
      QuizQuestion question, {
      required bool last,
    }) async {
      final option = find.ancestor(
        of: find.text(question.correctAnswer),
        matching: find.byType(InkWell),
      );
      await tester.ensureVisible(option.first);
      await tester.pumpAndSettle();
      await tester.tap(option.first);
      await tester.pumpAndSettle();

      final nextButton = last
          ? find.byIcon(Icons.flag_outlined)
          : find.byIcon(Icons.arrow_forward_rounded);
      // Açıklama paneli yarışma modunda artık gösterilmediği için içerik
      // ekrana sığar; kaydırılabilir alan olmayabilir.
      await tester.ensureVisible(nextButton.last);
      await tester.pumpAndSettle();
      await tester.tap(nextButton.last);
      await tester.pumpAndSettle();
    }

    await answerQuestion(questions[0], last: false);
    await answerQuestion(questions[1], last: false);
    await answerQuestion(questions[2], last: true);

    expect(find.text('Sonuç'), findsOneWidget);
    expect(find.text('YARIŞ TAMAMLANDI'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);

    // Dalga 5: "İncele" ikon butona indi (tooltip'li); anahtarla bulunur.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('result-review-button')),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('result-review-button')));
    await tester.pumpAndSettle();

    expect(find.text('Cevaplar'), findsOneWidget);
    expect(find.text('Soru 1'), findsOneWidget);
    expect(find.text('DOĞRU'), findsWidgets);
  });

  testWidgets('result screen compares the player with bot opponents', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 230,
          correctCount: 2,
          wrongCount: 1,
          totalQuestions: 3,
          bestStreak: 2,
          answerRecords: const [],
          coinsAwarded: 0,
          opponents: const [
            Player(name: 'Rojda', score: 320, state: 'Bot', streak: 3),
            Player(name: 'Baran', score: 100, state: 'Bot', streak: 1),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rakiplerle Karşılaştırma'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Rakiplerle Karşılaştırma'), findsOneWidget);
    expect(find.text('Sen'), findsOneWidget);
    expect(find.text('Rojda'), findsOneWidget);
    expect(find.text('Baran'), findsOneWidget);
  });

  testWidgets('result screen announces newly unlocked achievements', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repository,
          room: repository.createRoom(),
          score: 1200,
          correctCount: 10,
          wrongCount: 0,
          totalQuestions: 10,
          bestStreak: 10,
          answerRecords: const [],
          coinsAwarded: 0,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Yeni Rozet'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Yeni Rozet'), findsOneWidget);
    expect(find.text('İlk Oyun'), findsOneWidget);
    expect(find.text('10 Doğru Üst Üste'), findsOneWidget);
  });

  testWidgets('quiz answer feedback labels the correct answer', (tester) async {
    final room = repository.createRoom();
    final question = repository.questions.first;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => turkishLang(),
          ),
          ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: [question],
            enableTimer: false,
            // Tur içi açıklama yalnız Öğrenme Bölgesi'nde gösterilir.
            experience: QuizExperience.learning,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final option = find.ancestor(
      of: find.text(question.correctAnswer),
      matching: find.byType(InkWell),
    );
    await tester.tap(option.first);
    await tester.pumpAndSettle();

    expect(find.text('Doğru cevap'), findsOneWidget);
    // UI override haritasını kullanır (şablon explanation değil).
    expect(
      find.textContaining(question.getLocalizedExplanation(false)),
      findsOneWidget,
    );
  });

  testWidgets('favorite questions uses the shared empty state', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: FavoriteQuestionsScreen(repository: _EmptyFavoritesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Henüz kaydedilmiş soru yok.'), findsOneWidget);
  });

  testWidgets('profil mobil düzende 6 menü öğesinin tamamını gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    // pumpAndSettle bazen sonsuz progress indicator animasyonunda takılır;
    // profil async yüklemesini sabit karelerle bekle.
    await tester.pump();
    for (var i = 0; i < 30 && find.text('Mağaza').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Kaydedilen Sorular'), findsOneWidget);
    expect(find.text('Yanlışlarım'), findsOneWidget);
    expect(find.text('ÖĞRENME'), findsOneWidget);
    expect(find.text('HESAP'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Mağaza'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Mağaza'), findsOneWidget);
    // Arkadaşlar ekranı donduruldu; menüde görünmez.
    expect(find.text('Arkadaşlarım'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Çıkış Yap'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Çıkış Yap'), findsOneWidget);
    expect(find.text('Ayarlar'), findsOneWidget);
  });

  testWidgets('profile screen shows unlocked achievement showcase', (
    tester,
  ) async {
    final store = await AchievementStore.load();
    await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 3,
      correctCount: 2,
      bestStreak: 2,
      dailyStreak: 1,
      userScore: 230,
    );

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Rozetler'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Rozetler'), findsOneWidget);
    expect(find.text('İlk Oyun'), findsOneWidget);
  });

  testWidgets('profile reloads achievements when refresh signal fires', (
    tester,
  ) async {
    final refresh = ValueNotifier<int>(0);
    addTearDown(refresh.dispose);

    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: ProfileScreen(repository: repository, refreshSignal: refresh),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Profil açıldığında henüz rozet yok.
    expect(find.text('İlk Oyun'), findsNothing);

    // Profil tabı dışındayken bir quiz tamamlanıp rozet açılmış gibi yap.
    final store = await AchievementStore.load();
    await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 3,
      correctCount: 2,
      bestStreak: 2,
      dailyStreak: 1,
      userScore: 230,
    );

    // Profil tabına geri dönüş sinyali tetikleyince veriler tazelenmeli.
    refresh.value++;
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('İlk Oyun'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('İlk Oyun'), findsOneWidget);
  });

  testWidgets('leaderboard error state exposes retry', (tester) async {
    final repository = _FailingLeaderboardRepository();

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(repository.loadCalls, 1);

    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
  });

  testWidgets('leaderboard empty state can start a quick race', (tester) async {
    final repository = _EmptyLeaderboardRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Yarışa Başla'), findsOneWidget);

    await tester.ensureVisible(find.text('Yarışa Başla'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarışa Başla'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });
}
