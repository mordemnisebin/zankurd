import 'dart:async';

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
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_logo.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';
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
  bool _loading = false;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  bool get isLoading => _loading;

  set isLoadingForTest(bool value) {
    _loading = value;
    notifyListeners();
  }

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

class _FailingJoinRoomRepository extends MockZanKurdRepository {
  int joinCalls = 0;

  @override
  Future<GameRoom> joinOnlineRoom(String code) {
    joinCalls += 1;
    return Future<GameRoom>.error(StateError('online room join unavailable'));
  }
}

/// Host-only online lobby for start-gate diagnostics.
class _HostOnlyRoomRepository extends MockZanKurdRepository {
  _HostOnlyRoomRepository()
    : _players = const [
        Player(
          id: 'host',
          name: 'HostOyuncu',
          score: 0,
          state: 'Hazır',
          streak: 0,
        ),
      ];

  final List<Player> _players;

  @override
  String? get currentUserId => 'host-user';

  GameRoom hostLobbyRoom() => GameRoom(
    id: 'room-sync-1',
    name: 'Hevalên Zanînê',
    code: 'ZK-SYNC',
    category: 'Ziman',
    players: List<Player>.of(_players),
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return List<Player>.of(_players);
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(List<Player>.of(_players));
  }
}

/// Emits a second participant shortly after subscribe (sync simulation).
class _GrowingPlayersRoomRepository extends _HostOnlyRoomRepository {
  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) async* {
    yield List<Player>.of(_players);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield [
      ..._players,
      const Player(
        id: 'guest',
        name: 'Misafir',
        score: 0,
        state: 'Bekliyor',
        streak: 0,
      ),
    ];
  }
}

/// Realtime returns stale 1-player list; polling recovers with 2 players.
class _StaleStreamPollRecoveryRepository extends _HostOnlyRoomRepository {
  int pollCalls = 0;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(List<Player>.of(_players));
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    pollCalls += 1;
    return [
      ..._players,
      const Player(
        id: 'guest',
        name: 'Misafir',
        score: 0,
        state: 'Bekliyor',
        streak: 0,
      ),
    ];
  }
}

class _RoomQuizBroadcastRepository extends MockZanKurdRepository {
  final broadcasts = <Map<String, dynamic>>[];
  final controller = StreamController<Map<String, dynamic>>.broadcast();

  @override
  String? get currentUserId => 'user';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return controller.stream;
  }

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    broadcasts.add(payload);
    controller.add(payload);
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
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ChangeNotifierProvider<ReducedMotionProvider>(
        create: (_) => ReducedMotionProvider(),
      ),
      ChangeNotifierProvider<ChildSafetyProvider>(
        create: (_) => ChildSafetyProvider(),
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
  // MockZanKurdRepository _mockName/_mockCoins/_lastSpin gibi değişken durum
  // tutar; tek bir paylaşılan örnek testler arasında sıra bağımlılığı yaratır.
  // Her test için taze bir örnek oluşturup izolasyonu garanti ediyoruz.
  late MockZanKurdRepository repository;

  // SharedPreferences mock'lanmazsa getInstance() widget testinde askıda
  // kalır; tüm testler için deterministik temiz durum kur.
  setUp(() {
    repository = MockZanKurdRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
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

  testWidgets(
    'auth alternative buttons stay readable on their own backgrounds',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(844, 390));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final mode in [ThemeMode.light, ThemeMode.dark]) {
        // KeyedSubtree: provider create'leri her temada yeniden çalışsın.
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey(mode),
            child: _testShell(
              child: const SignInScreen(),
              authProvider: _GateAuthProvider(),
              themeProvider: ThemeProvider(initialMode: mode),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Google butonu: iki temada da beyaz dolgu -> koyu metin.
        final googleLabel = tester.widget<Text>(
          find.text('Google ile giriş yap'),
        );
        expect(googleLabel.style?.color?.computeLuminance(), lessThan(0.3));

        // Misafir butonu context yüzeyi kullanır: light'ta koyu metin,
        // dark'ta beyaz metin.
        final guestLabel = tester.widget<Text>(
          find.text('Misafir olarak devam et'),
        );
        final guestLuminance = guestLabel.style?.color?.computeLuminance() ?? 0;
        if (mode == ThemeMode.light) {
          expect(guestLuminance, lessThan(0.4));
        } else {
          expect(guestLabel.style?.color, equals(Colors.white));
        }
      }
    },
  );

  testWidgets('auth alternative buttons ignore taps while loading', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final authProvider = _GateAuthProvider();
    await tester.pumpWidget(
      _testShell(child: const SignInScreen(), authProvider: authProvider),
    );
    await tester.pumpAndSettle();

    authProvider.isLoadingForTest = true;
    await tester.pump();

    // isLoading true iken onPressed null'a düşer; IgnorePointer bu durumda
    // butonu tamamen hit-test dışı bırakmalı (yalnızca InkWell'in örtük
    // null-onTap davranışına güvenmemeli). Bulunamaması bunun kanıtıdır.
    expect(find.text('Misafir olarak devam et').hitTestable(), findsNothing);

    authProvider.isLoadingForTest = false;
    await tester.pump();

    // Yükleme bitince buton tekrar normal çalışmalı (regresyon önlemi).
    await tester.tap(find.text('Misafir olarak devam et').hitTestable());
    await tester.pumpAndSettle();

    expect(authProvider.isAuthenticated, isTrue);
  });

  testWidgets('auth form text stays readable in light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      // KeyedSubtree: provider create'leri her temada yeniden çalışsın.
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey(mode),
          child: _testShell(
            child: const SignInScreen(),
            authProvider: _GateAuthProvider(),
            themeProvider: ThemeProvider(initialMode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Renkli welcome banner başlığı iki temada da beyaz kalır.
      final title = tester.widget<Text>(find.text('ZanKurd\'a Hoş Geldin'));
      expect(title.style?.color?.computeLuminance(), greaterThan(0.75));

      // Form etiketi temayla birlikte renk değiştirir; sabit beyaz olmamalı.
      final emailLabel = tester.widget<Text>(find.text('E-posta adresi'));
      final labelLuminance = emailLabel.style?.color?.computeLuminance() ?? 0;
      if (mode == ThemeMode.light) {
        expect(labelLuminance, lessThan(0.3));
      } else {
        expect(labelLuminance, greaterThan(0.6));
      }

      expect(find.text('Misafir olarak devam et'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('sign up and name gate stay readable in light and dark themes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      // KeyedSubtree: provider create'leri her temada yeniden çalışsın.
      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('signup-$mode'),
          child: _testShell(
            child: const SignUpScreen(),
            authProvider: _GateAuthProvider(),
            themeProvider: ThemeProvider(initialMode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hesabını oluştur'), findsOneWidget);
      expect(find.text('İleri'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        KeyedSubtree(
          key: ValueKey('name-gate-$mode'),
          child: _testShell(
            child: ProfileNameGateScreen(
              repository: repository,
              onCompleted: () {},
            ),
            themeProvider: ThemeProvider(initialMode: mode),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('player-name-field')), findsOneWidget);
      expect(find.text('Oyuna Başla'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('guest sign in is reachable in the first mobile auth viewport', (
    tester,
  ) async {
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

    final guestButton = find.text('Misafir olarak devam et');
    expect(guestButton, findsOneWidget);
    expect(tester.getBottomRight(guestButton).dy, lessThan(844));
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

    // Marka artık metin yerine logo görseliyle gösteriliyor.
    expect(find.byType(AppLogo), findsOneWidget);
    final logoCenter = tester.getCenter(find.byType(AppLogo));
    expect(logoCenter.dx, closeTo(195, 4));
    expect(find.text('Atla'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Atla'));
    await tester.pumpAndSettle();

    expect(find.text('ZanKurd\'a Hoş Geldin'), findsOneWidget);
    expect(tester.takeException(), isNull);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('zankurd.onboarding.seen'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('onboarding fits a landscape phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      _testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonraki'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Sonraki')).dy,
      lessThanOrEqualTo(390),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding fits a portrait phone viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      _testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sonraki'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Sonraki')).dy,
      lessThanOrEqualTo(844),
    );
    expect(tester.takeException(), isNull);

    // Bubblegum Arcade sözleşmesi: onboarding açık sahnede açılır.
    expect(
      Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
      Brightness.light,
    );
    final surface = tester.widget<Container>(
      find.byKey(const ValueKey('onboarding-surface')),
    );
    final decoration = surface.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.lightBg);
  });

  testWidgets('onboarding fits a tablet and web viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.takeException();

    await tester.pumpWidget(
      _testShell(child: OnboardingScreen(onComplete: () {})),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Sonraki'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Sonraki')).dy,
      lessThanOrEqualTo(800),
    );
    expect(tester.takeException(), isNull);
    expect(
      Theme.of(tester.element(find.byType(OnboardingScreen))).brightness,
      Brightness.light,
    );
  });

  testWidgets('app logo uses high quality image filtering', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AppLogo(width: 160))),
    );

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.filterQuality, FilterQuality.high);
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
    expect(find.text('Hoş geldin, ZanKurd Oyuncusu!'), findsOneWidget);
    expect(find.text('Seviye 5'), findsNothing);
    expect(find.byIcon(Icons.diamond), findsNothing);

    // Pirs-inspired sözleşme: turuncu profil header'ı ve multiplayer hero.
    expect(find.byKey(const ValueKey('home-profile-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-multiplayer-hero')), findsOneWidget);
    expect(find.text('Oda kur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);
    expect(find.text('1vs1 — Hemen oyna'), findsOneWidget);
    expect(find.text('Öğren'), findsOneWidget);
    expect(find.text('Oyna'), findsOneWidget);
    expect(find.text('Topluluk'), findsOneWidget);

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('home-profile-header')),
    );
    final headerDecoration = header.decoration as BoxDecoration;
    final headerGradient = headerDecoration.gradient as LinearGradient;
    expect(headerGradient.colors, [
      AppTheme.brandOrange,
      AppTheme.brandOrangeWarm,
    ]);

    final navTheme = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );
    expect(navTheme.data.height, 68);
    expect(navTheme.data.backgroundColor, AppTheme.lightSurface);
    expect(
      navTheme.data.indicatorColor,
      AppTheme.brandOrange.withValues(alpha: 0.14),
    );

    await tester.tap(find.text('Öğren'));
    await tester.pumpAndSettle();
    expect(find.byType(LearningScreen), findsOneWidget);

    // Bottom nav seçili rengi sekmeyle değişmez; sabit brandOrange kalır.
    final navThemeAfter = tester.widget<NavigationBarTheme>(
      find.byType(NavigationBarTheme),
    );
    expect(
      navThemeAfter.data.indicatorColor,
      AppTheme.brandOrange.withValues(alpha: 0.14),
    );
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

    // Bubblegum Arcade sözleşmesi gereği uygulama açık temayla açılır.
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
    expect(gradient.colors.first, AppTheme.lightBg);

    theme.toggleDarkLight();
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.byType(HomeScreen))).brightness,
      Brightness.dark,
    );
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

  test('network auth error points to connection or DNS', () {
    final provider = AuthProvider.test();

    final message = provider.debugTranslateUnexpectedAuthError(
      Exception('ClientException: Failed host lookup'),
    );

    expect(message, 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.');
  });

  test('network auth exception points to connection or DNS', () {
    final provider = AuthProvider.test();

    final message = provider.debugTranslateAuthError(
      const AuthException('net::ERR_NAME_NOT_RESOLVED'),
    );

    expect(message, 'Bağlantı kurulamadı. İnternet/DNS erişimini kontrol et.');
  });

  testWidgets('landscape auth actions can be scrolled into view', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: const SignInScreen(),
        authProvider: _GateAuthProvider(),
      ),
    );
    await tester.pumpAndSettle();

    final guestButton = find.text('Misafir olarak devam et');
    expect(guestButton, findsOneWidget);

    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -260),
    );
    await tester.pumpAndSettle();

    expect(tester.getBottomRight(guestButton).dy, lessThan(390));
  });

  testWidgets('landscape auth keeps guest action in the first viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: const SignInScreen(),
        authProvider: _GateAuthProvider(),
      ),
    );
    await tester.pumpAndSettle();

    final guestButton = find.text('Misafir olarak devam et');
    expect(guestButton, findsOneWidget);
    expect(tester.getBottomRight(guestButton).dy, lessThan(390));
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
    expect(find.textContaining('Arkadaşlarınla'), findsOneWidget);
    expect(find.text('Oda kur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);
    expect(find.text('Günün Yarışması'), findsOneWidget);

    await tester.ensureVisible(find.text('Oda kur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oda kur'));
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

    await tester.ensureVisible(find.text('Günün Yarışması'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Günün Yarışması'));
    await tester.pumpAndSettle();

    // Mock her gün contest döner → etkinlik lobisi; oradan quiz başlar.
    expect(find.byType(ContestScreen), findsOneWidget);
    expect(find.text('Etkinliğe başla'), findsOneWidget);

    await tester.tap(find.text('Etkinliğe başla'));
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

    await tester.ensureVisible(find.text('Günün Çarkı'));
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

    expect(find.text('Kodê tevlî bibe'), findsOneWidget);
    expect(find.text('Bi Kodê Tevlî Bibe'), findsNothing);
    expect(find.text('Bi Kodê Bikeve'), findsNothing);
  });

  testWidgets('join by code opens the room code sheet from the hero', (
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

    await tester.ensureVisible(find.text('Kodla katıl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kodla katıl'));
    await tester.pumpAndSettle();

    expect(find.text('Odaya Katıl'), findsOneWidget);
    expect(find.text('Oda kodu'), findsOneWidget);
    expect(find.text('Katıl'), findsOneWidget);
    expect(find.byKey(const ValueKey('join-room-code-field')), findsOneWidget);
  });

  testWidgets('join room sheet accepts typed room code text', (tester) async {
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

    await tester.ensureVisible(find.text('Kodla katıl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kodla katıl'));
    await tester.pumpAndSettle();

    const code = 'ZK-ABCD';
    await tester.enterText(
      find.byKey(const ValueKey('join-room-code-field')),
      code,
    );
    await tester.pumpAndSettle();

    expect(find.text(code), findsOneWidget);
  });

  testWidgets('home hero keeps multiplayer actions visible in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ZanKurdApp(
        repository: repository,
        authProvider: _FakeAuthProvider(),
        languageProvider: _turkishLang(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Arkadaşlarınla'), findsOneWidget);
    expect(find.text('Oda kur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);
  });

  testWidgets('room lobby remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Özel Oda'), findsOneWidget);
    expect(find.text('Oyuncular'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Yarışı Başlat'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Yarışı Başlat'), findsOneWidget);
  });

  testWidgets('room lobby keeps start disabled until two players are present', (
    tester,
  ) async {
    final repository = _HostOnlyRoomRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Yarışı başlatmak için en az 2 oyuncu olmalıdır.'),
      findsOneWidget,
    );

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('room lobby enables start after player stream adds a guest', (
    tester,
  ) async {
    final repository = _GrowingPlayersRoomRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Misafir'), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('Misafir'), findsOneWidget);
    expect(
      find.text('Yarışı başlatmak için en az 2 oyuncu olmalıdır.'),
      findsNothing,
    );

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets(
    'room lobby recovers via polling when realtime player list stays stale',
    (tester) async {
      final repository = _StaleStreamPollRecoveryRepository();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: repository.hostLobbyRoom(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Misafir'), findsNothing);
      final disabledButton = tester.widget<GeometricGradientButton>(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      );
      expect(disabledButton.onPressed, isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(repository.pollCalls, greaterThan(0));
      expect(find.text('Misafir'), findsOneWidget);

      final enabledButton = tester.widget<GeometricGradientButton>(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      );
      expect(enabledButton.onPressed, isNotNull);
      expect(find.byType(QuizScreen), findsNothing);
    },
  );

  testWidgets('quiz screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(question.prompt), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-landscape-layout')), findsOneWidget);
    expect(find.text(question.displayAnswers.first), findsWidgets);

    await tester.ensureVisible(find.text(question.displayAnswers.first).first);
    await tester.tap(find.text(question.displayAnswers.first).first);
    await tester.pumpAndSettle();

    expect(find.text('Doğru cevap'), findsOneWidget);
  });

  testWidgets('quiz question panel renders the polished visual accents', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final question = repository.questions.first;
    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quiz-question-icon-badge')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quiz-question-ghost-icon')),
      findsOneWidget,
    );
  });

  testWidgets('online room answer broadcasts readiness outside 1vs1', (
    tester,
  ) async {
    final roomRepository = _RoomQuizBroadcastRepository();
    addTearDown(roomRepository.controller.close);
    final questions = repository.questions.take(2).toList();
    final room = GameRoom(
      id: 'online-room',
      name: 'Oda',
      code: 'ZK-ROOM',
      category: 'Ziman',
      players: const [
        Player(id: 'user', name: 'ZanKurd Oyuncusu', score: 0, state: 'Hazır'),
        Player(id: 'guest', name: 'Misafir', score: 0, state: 'Hazır'),
      ],
      status: RoomStatus.active,
      questionCount: 2,
      hostId: 'user',
    );

    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: roomRepository,
          room: room,
          questions: questions,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text(questions.first.displayAnswers.first).first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      roomRepository.broadcasts.any(
        (payload) =>
            payload['question_index'] == 0 && payload['answered'] == true,
      ),
      isTrue,
    );
  });

  testWidgets(
    'portrait quiz shows question answers jokers and action at once',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const question = QuizQuestion(
        id: 'compact-portrait-fit',
        category: 'Çand',
        prompt: 'Kurmancî kültüründe dengbêjlerin temel görevi hangisidir?',
        answers: [
          'Sözlü kültürü aktarmak',
          'Yalnızca dans etmek',
          'Resmî belge hazırlamak',
          'Spor karşılaşması düzenlemek',
        ],
        correctAnswer: 'Sözlü kültürü aktarmak',
        explanation: 'Dengbêjler sözlü kültürü kuşaktan kuşağa aktarır.',
      );

      await tester.pumpWidget(
        _testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: const [question],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('quiz-fitted-content')), findsOneWidget);
      expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);
      for (final answer in question.displayAnswers) {
        final answerFinder = find.text(answer).first;
        expect(answerFinder, findsOneWidget);
        expect(tester.getBottomRight(answerFinder).dy, lessThan(640));
      }
      expect(
        tester
            .getBottomRight(find.byKey(const ValueKey('quiz-next-button')))
            .dy,
        lessThanOrEqualTo(640),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('visual quiz keeps the first answer visible in landscape', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const question = QuizQuestion(
      id: 'visual-landscape-fit',
      category: 'Çand',
      prompt: 'Görseldeki etkinlik hangi kültürel kategoriyle ilgilidir?',
      answers: ['Coğrafya', 'Ziman', 'Müzik', 'Edebiyat'],
      correctAnswer: 'Müzik',
      explanation: 'Govend kültürel bir dans ve müzik etkinliğidir.',
      type: QuestionType.visual,
      imageUrl: 'asset://assets/zankurd.webp',
    );

    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final answer in question.displayAnswers) {
      final answerFinder = find.text(answer).first;
      expect(answerFinder, findsOneWidget);
      expect(tester.getBottomRight(answerFinder).dy, lessThan(390));
    }
    expect(find.byKey(const ValueKey('quiz-wildcard-row')), findsOneWidget);
    expect(
      tester.getBottomRight(find.byKey(const ValueKey('quiz-next-button'))).dy,
      lessThanOrEqualTo(390),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaderboard screen remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(child: LeaderboardScreen(repository: repository)),
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
      _testShell(child: LeaderboardScreen(repository: repository)),
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
      _testShell(
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
      _testShell(
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
      _testShell(
        child: Scaffold(body: ProfileScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profil'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byIcon(Icons.settings_outlined),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
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

    await tester.ensureVisible(find.text('Topluluk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Topluluk'));
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
            create: (_) => _turkishLang(),
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
    expect(find.text('YARIŞ TAMAMLANDI'), findsOneWidget);
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
      MultiProvider(
        providers: [
          ChangeNotifierProvider<LanguageProvider>(
            create: (_) => _turkishLang(),
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
      _testShell(
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
      _testShell(
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
    expect(find.text('Arkadaşlarım'), findsOneWidget);
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

  testWidgets('profile reloads achievements when refresh signal fires', (
    tester,
  ) async {
    final refresh = ValueNotifier<int>(0);
    addTearDown(refresh.dispose);

    await tester.pumpWidget(
      _testShell(
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
      _testShell(child: LeaderboardScreen(repository: repository)),
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
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: SettingsScreen(repository: _DeleteTrackingRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Hesap İşlemleri'));
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

      await tester.ensureVisible(find.text('Oda kur'));
      await tester.tap(find.text('Oda kur'));
      await tester.pumpAndSettle();

      expect(find.byType(RoomScreen), findsNothing);
      expect(find.text('Rojda'), findsNothing);
      expect(find.text('Baran'), findsNothing);
      expect(
        find.text('Çevrimiçi oda açılamadı. Lütfen tekrar deneyin.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('home does not open a demo room when online room join fails', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(
          body: HomeScreen(repository: _FailingJoinRoomRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kodla katıl'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'ABCD12');
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.text('Rojda'), findsNothing);
    expect(find.text('Baran'), findsNothing);
    expect(
      find.text('Çevrimiçi odaya katılınamadı. Lütfen kodu kontrol edin.'),
      findsOneWidget,
    );
  });

  testWidgets('empty room code is validated locally before online join', (
    tester,
  ) async {
    final repository = _FailingJoinRoomRepository();
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _testShell(
        child: Scaffold(body: HomeScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kodla katıl'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Katıl'));
    await tester.pumpAndSettle();

    expect(repository.joinCalls, 0);
    expect(find.text('Oda kodu gerekli.'), findsOneWidget);
    expect(find.byType(RoomScreen), findsNothing);
  });

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
    await tester.ensureVisible(find.text('Kaydet'));
    await tester.pumpAndSettle();
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

  testWidgets('quiz screen shows circular timer', (tester) async {
    final question = repository.questions.first;
    await tester.pumpWidget(
      _testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [question],
          enableTimer: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quiz-circular-timer')), findsOneWidget);
    expect(find.text('15'), findsOneWidget);
  });

  // testWidgets('explanation box is displayed after 800ms delay', (tester) async {
  //   final question = repository.questions.first;
  //   await tester.pumpWidget(
  //     _testShell(
  //       child: QuizScreen(
  //         repository: repository,
  //         room: repository.createRoom(),
  //         questions: [question],
  //         enableTimer: false,
  //       ),
  //     ),
  //   );
  //   await tester.pumpAndSettle();
  //
  //   final answerText = question.displayAnswers.first;
  //   await tester.ensureVisible(find.text(answerText).first);
  //   await tester.tap(find.text(answerText).first);
  //   await tester.pump();
  //
  //   final shown = question.getLocalizedExplanation(false);
  //   await tester.pump(const Duration(milliseconds: 400));
  //   expect(find.text(shown), findsNothing);
  //
  //   await tester.pump(const Duration(milliseconds: 600));
  //   await tester.pumpAndSettle();
  //
  //   expect(find.text(shown), findsOneWidget);
  // });
}
