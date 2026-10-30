// T10: çevrimdışı üretim ekranları; Supabase başlatılmaz, kimlik servisi yok.
// Web: ?screen=signup|forfeit|final|async-result|story|loss&lang=tr|ku
// Native: --dart-define=T10_SCREEN=menu --dart-define=T10_LANG=tr
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart' show ZanKurdApp;
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import '../test/support/t8_visual_fixtures.dart';
import '../test/support/t10_room_visual_fixture.dart';

class _CupRepo extends T8CupRepo {
  _CupRepo(bool forfeit) : super(_bracket(forfeit));
  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [
    TournamentStandings(
      rank: 1,
      playerId: 'rival',
      playerName: 'QaAlı',
      totalScore: 510,
      hasSubmitted: true,
      status: 'champion',
    ),
    TournamentStandings(
      rank: 2,
      playerId: 'user',
      playerName: 'QaBero',
      totalScore: 245,
      hasSubmitted: true,
      status: 'finalist',
    ),
    TournamentStandings(
      rank: 3,
      playerId: 'absent',
      playerName: 'Test ZK',
      hasSubmitted: false,
      status: 'eliminated',
    ),
  ];
}

TournamentBracket _bracket(bool forfeit) => TournamentBracket(
  tournamentId: 't10-cup',
  userId: 'user',
  currentRound: 1,
  status: 'eliminated',
  totalScore: forfeit ? 0 : 245,
  createdAt: DateTime.utc(2026, 10, 30),
  completedAt: DateTime.utc(2026, 10, 30, 12),
  rounds: [
    const TournamentRound(
      roundNumber: 1,
      matches: [
        TournamentMatch(
          id: 'semi-a',
          playerOneId: 'user',
          playerOneName: 'QaBero',
          playerTwoId: 'absent',
          playerTwoName: 'Test ZK',
          playerOneScore: 150,
          playerTwoScore: 0,
          playerOneSubmitted: true,
          playerTwoSubmitted: false,
          status: 'completed',
          winnerId: 'user',
        ),
        TournamentMatch(
          id: 'semi-b',
          playerOneId: 'rival',
          playerOneName: 'QaAlı',
          playerTwoId: 'other',
          playerTwoName: 'QaDlan',
          playerOneScore: 230,
          playerTwoScore: 100,
          playerOneSubmitted: true,
          playerTwoSubmitted: true,
          status: 'completed',
          winnerId: 'rival',
        ),
      ],
    ),
    TournamentRound(
      roundNumber: 2,
      matches: [t8TournamentMatch(submitted: !forfeit)],
    ),
  ],
);

Widget t10PreviewScreen(String screen, T8VisualRepo repo) => switch (screen) {
  'signup' => const SignUpScreen(),
  'room' => const T10RoomVisualFixture(),
  'forfeit' ||
  'final' => TournamentScreen(repository: _CupRepo(screen == 'forfeit')),
  'story' => StoryScreen(story: cayxaneStory, guide: cayxaneGuide),
  'async-result' => AsyncDuelResultScreen(
    repository: repo,
    view: AsyncDuelResultView.fromSummary(
      AsyncDuelSummary(
        duelId: 't10-async',
        status: AsyncDuelStatus.completed,
        role: AsyncDuelRole.creator,
        myCorrect: 3,
        opponentCorrect: 5,
        opponentName: 'QaAlı',
        outcome: AsyncDuelOutcome.loss,
        createdAt: DateTime.utc(2026, 10, 30),
        seen: true,
      ),
    ),
  ),
  'loss' => QuizResultScreen(
    repository: repo,
    room: const GameRoom(
      id: 't10-duel',
      name: 'T10',
      code: 'T10',
      category: 'Ziman',
      status: RoomStatus.finished,
      questionCount: 7,
      players: [
        Player(id: 'user', name: 'QaBero', score: 0, state: ''),
        Player(id: 'rival', name: 'QaAlı', score: 375, state: ''),
      ],
    ),
    score: 0,
    correctCount: 0,
    wrongCount: 7,
    totalQuestions: 7,
    bestStreak: 0,
    coinsAwarded: 0,
    answerRecords: const [],
    opponents: const [
      Player(id: 'rival', name: 'QaAlı', score: 375, state: ''),
    ],
  ),
  _ => _Menu(repo: repo),
};

class _Menu extends StatelessWidget {
  const _Menu({required this.repo});
  final T8VisualRepo repo;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('T10 · Offline QA')),
    body: ListView(
      children: [
        for (final lang in ['tr', 'ku'])
          for (final screen in [
            'signup',
            'forfeit',
            'final',
            'async-result',
            'story',
            'loss',
            'room',
          ])
            ListTile(
              title: Text('$lang · $screen'),
              onTap: () {
                context.read<LanguageProvider>().setLang(lang);
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => t10PreviewScreen(screen, repo),
                  ),
                );
              },
            ),
      ],
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  final query = Uri.base.queryParameters;
  final screen =
      query['screen'] ??
      const String.fromEnvironment('T10_SCREEN', defaultValue: 'menu');
  final language =
      query['lang'] ??
      const String.fromEnvironment('T10_LANG', defaultValue: 'tr');
  final repo = T8VisualRepo();
  runApp(
    ZanKurdApp(
      repository: repo,
      authProvider: T8VisualAuthProvider(),
      languageProvider: LanguageProvider(initialLang: language),
      themeProvider: ThemeProvider(initialMode: ThemeMode.dark),
      home: Builder(
        builder: (context) => Theme(
          data: Theme.of(context).copyWith(platform: TargetPlatform.iOS),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                double.tryParse(query['scale'] ?? '') ?? 1,
              ),
            ),
            child: t10PreviewScreen(screen, repo),
          ),
        ),
      ),
    ),
  );
}
