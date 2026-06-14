import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/main.dart';

class _FakeAuthProvider extends AuthProvider {
  _FakeAuthProvider() : super.test();

  @override
  bool get isAuthenticated => true;

  @override
  bool get isLoading => false;
}

class _GateAuthProvider extends AuthProvider {
  _GateAuthProvider() : super.test();

  bool _authenticated = false;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => false;

  @override
  Future<bool> signInAsGuest() async {
    _authenticated = true;
    notifyListeners();
    return true;
  }
}

class _SignOutTrackingAuthProvider extends AuthProvider {
  _SignOutTrackingAuthProvider() : super.test();

  bool _authenticated = true;
  int signOutCalls = 0;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => false;

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    _authenticated = false;
    notifyListeners();
  }
}

class _EmptyFavoritesRepository extends MockZanKurdRepository {
  @override
  Future<List<QuizQuestion>> loadFavoriteQuestions() async {
    return const [];
  }
}

class _FailingLeaderboardRepository extends MockZanKurdRepository {
  int loadCalls = 0;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50}) {
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
  Future<List<LeaderboardEntry>> loadLeaderboard({int limit = 50}) async {
    return const [];
  }
}

class _DeleteTrackingRepository extends MockZanKurdRepository {
  _DeleteTrackingRepository({this.shouldFail = false});

  final bool shouldFail;
  int deleteCalls = 0;

  @override
  Future<void> deleteMyAccount() async {
    deleteCalls += 1;
    if (shouldFail) {
      throw StateError('delete failed');
    }
  }
}

class _FailingRoomRepository extends MockZanKurdRepository {
  @override
  Future<GameRoom> createOnlineRoom({String category = 'Ziman'}) {
    return Future<GameRoom>.error(StateError('online room unavailable'));
  }
}

class _NeedsNameRepository extends MockZanKurdRepository {
  String savedName = '';

  @override
  Future<String> getProfileName() async => savedName;

  @override
  Future<void> updateProfileName(String name) async {
    savedName = name;
  }
}

LanguageProvider _turkishLang() => LanguageProvider()..setLang('tr');

Widget _testShell({
  required Widget child,
  AuthProvider? authProvider,
  LanguageProvider? languageProvider,
  ThemeProvider? themeProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => languageProvider ?? _turkishLang(),
      ),
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => authProvider ?? _FakeAuthProvider(),
      ),
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => themeProvider ?? ThemeProvider(),
      ),
    ],
    child: Consumer<ThemeProvider>(
      builder: (context, theme, _) => MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: theme.mode,
        home: child,
      ),
    ),
  );
}

void main() {
  final repository = MockZanKurdRepository();

  // SharedPreferences mock'lanmazsa getInstance() widget testinde askıda
  // kalır; tüm testler için deterministik temiz durum kur.
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
    });
    AchievementStore.resetInstance();
    SeenQuestionStore.resetInstance();
    StreakStore.resetInstance();
    MistakeStore.resetInstance();
  });

  test('language provider persists selected language', () async {
    SharedPreferences.setMockInitialValues({});

    final provider = await LanguageProvider.load();
    expect(provider.lang, 'ku');

    provider.setLang('tr');

    final restored = await LanguageProvider.load();
    expect(restored.lang, 'tr');
  });

  testWidgets('shows auth screen before guest sign in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _GateAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default mock auth starts signed out', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(repository: repository, languageProvider: _turkishLang()),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsNothing);
  });

  testWidgets('first launch shows onboarding before auth screen', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _GateAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd'), findsOneWidget);
    expect(find.text('Atla'), findsOneWidget);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('zankurd.onboarding.seen'), isTrue);
  });

  testWidgets('auth screen asks for language before sign in', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _GateAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('KU'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);

    await tester.tap(find.text('KU'));
    await tester.pumpAndSettle();

    expect(find.text('Bi xêr hatî ZanKurdê'), findsOneWidget);
  });

  testWidgets('guest sign in opens the app shell', (tester) async {
    final authProvider = _GateAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: authProvider,
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Misafir olarak devam et'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Misafir olarak devam et'));
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsOneWidget);
  });

  testWidgets('home header exposes language and theme quick controls', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd'), findsOneWidget);
    expect(find.text('Hoş geldin, Oyuncu!'), findsOneWidget);
    expect(find.text('Seviye 5'), findsOneWidget);
  });

  testWidgets('theme toggle changes visible home surface colors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final theme = ThemeProvider();
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
        themeProvider: theme,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.dark,
    );

    theme.toggleDarkLight();
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.light,
    );
    final home = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HomeScreen),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = home.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    expect(gradient.colors.first, isNot(AppTheme.bg));
  });

  testWidgets('auth requires player name before home', (tester) async {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
    final repository = _NeedsNameRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oyundaki adın ne olsun?'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('player-name-field')),
      'Rojda Test',
    );
    await tester.tap(find.text('Oyuna Başla'));
    await tester.pumpAndSettle();

    expect(repository.savedName, 'Rojda Test');
    expect(find.text('Günün Yarışması'), findsOneWidget);
  });

  test('unsupported provider auth error is user friendly', () {
    final provider = AuthProvider.test();

    final message = provider.debugTranslateAuthError(
      const AuthException(
        'validation_failed: Unsupported provider is not enabled',
        statusCode: '400',
      ),
    );

    expect(
      message,
      'Google girişi şu anda etkin değil. Supabase panelinde Google sağlayıcısını aç.',
    );
  });

  testWidgets('language toggle works on the auth screen', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _GateAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('KU'));
    await tester.pumpAndSettle();

    expect(find.text('Bi xêr hatî ZanKurdê'), findsOneWidget);
    expect(find.text('Wek mêvan bidomîne'), findsOneWidget);
  });

  testWidgets('creates a room and opens the quiz flow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd'), findsOneWidget);
    expect(find.textContaining('Kurmancî Yarış'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Oda Kur'), 120);
    await tester.pumpAndSettle();
    expect(find.text('Oda Kur'), findsOneWidget);

    await tester.tap(find.text('Oda Kur'));
    await tester.pumpAndSettle();

    expect(find.text('Hevalên Zanînê'), findsOneWidget);
    expect(find.text('Yarışı Başlat'), findsOneWidget);

    await tester.ensureVisible(find.text('Yarışı Başlat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yarışı Başlat'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('opens the daily quiz from the home screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Günün Yarışması'));
    await tester.pumpAndSettle();

    expect(find.byType(QuizScreen), findsOneWidget);
  });

  testWidgets('opens the spin wheel from the home screen', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Günün Çarkı'), 120);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günün Çarkı'));
    await tester.pumpAndSettle();

    expect(find.text('Çevir!'), findsOneWidget);
  });

  testWidgets('kurdish home room join action uses compact label', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: LanguageProvider(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Bi Kodê Bikeve'), 120);
    await tester.pumpAndSettle();
    expect(find.text('Bi Kodê Bikeve'), findsOneWidget);
    expect(find.text('Bi Kodê Tevlî Bibe'), findsNothing);
  });

  testWidgets('opens the leaderboard from the home screen', (tester) async {
    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Liderlik'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liderlik'));
    await tester.pumpAndSettle();

    expect(find.text('Liderlik Tablosu'), findsOneWidget);
    expect(find.text('Rojda'), findsWidgets);
  });

  testWidgets('opens category levels from the home screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Dil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dil').last);
    await tester.pumpAndSettle();

    expect(find.text('Destpêk'), findsOneWidget);
    expect(find.text('Bingeh'), findsOneWidget);
    expect(find.text('10 soru · Zorluk 1/5'), findsOneWidget);
  });

  testWidgets('finishes a quiz and opens the result screen', (tester) async {
    final room = repository.createRoom();
    final questions = repository.questions.take(3).toList();

    await tester.pumpWidget(
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => _turkishLang(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: questions,
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
      await tester.scrollUntilVisible(
        nextButton,
        120,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      await tester.tap(nextButton.last);
      await tester.pumpAndSettle();
    }

    await answerQuestion(questions[0], last: false);
    await answerQuestion(questions[1], last: false);
    await answerQuestion(questions[2], last: true);

    expect(find.text('Sonuç'), findsOneWidget);
    expect(find.text('Yarış tamamlandı'), findsOneWidget);
    expect(find.text('Doğru'), findsOneWidget);
    expect(find.text('Yanlış'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Cevapları İncele'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cevapları İncele'));
    await tester.pumpAndSettle();

    expect(find.text('Cevaplar'), findsOneWidget);
    expect(find.text('Soru 1'), findsOneWidget);
    expect(find.text('DOĞRU'), findsWidgets);
  });

  testWidgets('result screen compares the player with bot opponents', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testShell(
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
    expect(find.text('Tu'), findsOneWidget);
    expect(find.text('Rojda'), findsOneWidget);
    expect(find.text('Baran'), findsOneWidget);
  });

  testWidgets('result screen announces newly unlocked achievements', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testShell(
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
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => _turkishLang(),
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: QuizScreen(
            repository: repository,
            room: room,
            questions: [question],
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
    expect(find.textContaining(question.explanation), findsOneWidget);
  });

  testWidgets('favorite questions uses the shared empty state', (tester) async {
    await tester.pumpWidget(
      _testShell(
        child: FavoriteQuestionsScreen(repository: _EmptyFavoritesRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Henüz kaydedilmiş soru yok.'), findsOneWidget);
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
      _testShell(
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

  testWidgets('leaderboard error state exposes retry', (tester) async {
    final repository = _FailingLeaderboardRepository();

    await tester.pumpWidget(
      _testShell(child: LeaderboardScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar Dene'), findsOneWidget);
    expect(repository.loadCalls, 1);

    await tester.tap(find.text('Tekrar Dene'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
  });

  testWidgets('leaderboard empty state can start a quick race', (tester) async {
    final repository = _EmptyLeaderboardRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(child: LeaderboardScreen(repository: repository)),
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

  testWidgets('settings does not delete account before final confirmation', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final deleteAction = find
        .byKey(const ValueKey('delete-account-action'))
        .first;
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();

    expect(find.text('Hesabı kalıcı olarak sil?'), findsOneWidget);
    expect(repository.deleteCalls, 0);

    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();

    expect(repository.deleteCalls, 0);
  });

  testWidgets('settings separates dangerous account actions', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: SettingsScreen(repository: _DeleteTrackingRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hesap İşlemleri'), findsOneWidget);
    expect(find.text('Bu alandaki işlemler geri alınamaz.'), findsOneWidget);
    expect(find.text('Hesabımı Sil'), findsOneWidget);
  });

  testWidgets('successful account deletion signs out to the auth gate', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository();
    final authProvider = _SignOutTrackingAuthProvider();
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: SettingsScreen(repository: repository),
        authProvider: authProvider,
      ),
    );
    await tester.pumpAndSettle();

    final deleteAction = find
        .byKey(const ValueKey('delete-account-action'))
        .first;
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı Olarak Sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(authProvider.signOutCalls, 1);
  });

  testWidgets('failed account deletion keeps the user in settings', (
    tester,
  ) async {
    final repository = _DeleteTrackingRepository(shouldFail: true);
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    final deleteAction = find
        .byKey(const ValueKey('delete-account-action'))
        .first;
    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Devam Et'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('delete-confirm-field')),
      'SIL',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalıcı Olarak Sil'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(repository.deleteCalls, 1);
    expect(find.text('Ayarlar'), findsOneWidget);
    expect(
      find.text('Hesap silinemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'home does not open a demo room when online room creation fails',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _testShell(
          child: Scaffold(
            body: HomeScreen(repository: _FailingRoomRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Oda Kur'));
      await tester.tap(find.text('Oda Kur'));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsNothing);
      expect(find.text('Rojda'), findsNothing);
      expect(find.text('Baran'), findsNothing);
      expect(
        find.text('Online oda açılamadı. Lütfen tekrar deneyin.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('settings updates the online player name', (tester) async {
    final repository = _NeedsNameRepository()..savedName = 'Eski Ad';

    await tester.pumpWidget(
      _testShell(child: SettingsScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oyuncu Adı'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('settings-player-name-field')),
      'Yeni Ad',
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();

    expect(repository.savedName, 'Yeni Ad');
    expect(find.text('Oyuncu adı güncellendi.'), findsOneWidget);
  });

  testWidgets('profile shows player name without inline editing', (
    tester,
  ) async {
    final repository = _NeedsNameRepository()..savedName = 'Zana';

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zana'), findsOneWidget);
    expect(find.text('Oyuncu Adı'), findsNothing);
    expect(
      find.byKey(const ValueKey('profile-player-name-field')),
      findsNothing,
    );
  });
}
