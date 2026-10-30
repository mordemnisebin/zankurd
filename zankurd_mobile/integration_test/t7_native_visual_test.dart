import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/auth_social_buttons.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import '../test/support/widget_test_helpers.dart';
import '../test/t7_readability_test.dart' show t7Question, t7Room;

// Canlı istemci kurulmaz. Tüm ekranların verisi bellek içi depodan gelir.
class _VisualRepo extends MockZanKurdRepository {
  _VisualRepo({this.bracket});
  final TournamentBracket? bracket;

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => bracket;

  QuizQuestion timerQuestion(int index) => QuizQuestion.fromServerRow({
    'id': 't7-timer-$index',
    'category_name': 'Ziman',
    'prompt': 'Yek + yek?',
    'option_a': 'Du',
    'option_b': 'Sê',
    'option_c': 'Çar',
    'option_d': 'Pênc',
    'difficulty': 1,
  });

  @override
  Future<AsyncDuelStart> startTournamentMatch(String matchId) async =>
      AsyncDuelStart(
        duelId: matchId,
        role: AsyncDuelRole.creator,
        opponentName: 'Bero',
        opponentId: 'other',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        questions: [timerQuestion(0), timerQuestion(1)],
      );

  @override
  Future<TournamentPresent> presentTournamentQuestion(
    String matchId,
    int index,
  ) async => TournamentPresent(elapsedMs: 0, question: timerQuestion(index));

  @override
  Future<AsyncDuelAnswer> answerTournamentQuestion({
    required String matchId,
    required int questionIndex,
    required String choice,
  }) async => AsyncDuelAnswer(
    correct: choice == 'A',
    correctOption: 'A',
    answered: questionIndex + 1,
    total: 2,
    finished: false,
  );

  @override
  String? get currentUserId => 'ali';

  final lobbyPlayers = [
    for (final pair in [('dlan', 3), ('cano', 1), ('ali', 0), ('bero', 1)])
      Player(
        id: pair.$1,
        joinedAt: DateTime.utc(2026, 10, 30, 12, 0, pair.$2),
        name: '${pair.$1[0].toUpperCase()}${pair.$1.substring(1)}',
        score: 0,
        state: Player.readyState,
      ),
  ];

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => lobbyPlayers;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(lobbyPlayers);

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async => RoomStatus.lobby;

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) =>
      Stream.value(RoomStatus.lobby);

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async => const LeaderboardEntry(
    rank: 1202,
    playerId: 'ali',
    displayName: 'Ali',
    totalScore: 4404,
    bestStreak: 5,
    roomsPlayed: 1436,
  );
}

class _ReadyDuelRepo extends MockZanKurdRepository {
  @override
  String? get currentUserId => 'user';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      Stream.value({'sender': 'Bero', 'sender_id': 'other', 'ready': true});
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('T7 çevrimdışı native görsel kanıt', (tester) async {
    Future<void> show(Widget child, {bool ku = false, double scale = 1}) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        testShell(
          reducedMotion: true,
          languageProvider: ku ? kurmanciLang() : turkishLang(),
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.takeException(), isNull);
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull);
      // ignore: avoid_print
      print('CAPTURE_SCREENSHOT: $name');
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    for (final ku in [false, true]) {
      freshMockRepository();
      final repo = _ReadyDuelRepo();
      await show(
        QuizScreen(
          repository: repo,
          room: t7Room(),
          questions: const [t7Question, t7Question],
          is1v1: true,
          enableTimer: false,
        ),
        ku: ku,
        scale: 1.3,
      );
      expect(find.byType(QuizScreen), findsOneWidget);
      expect(find.text('Rakip bekleniyor...'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byKey(const ValueKey('duel-self-score')), findsOneWidget);
      expect(find.text('99.999'), findsOneWidget);
      expect(find.text('12.345'), findsOneWidget);
      expect(find.text('×5'), findsNWidgets(2));
      expect(find.text(ku ? 'Yek + yek?' : 'Bir + bir?'), findsOneWidget);
      await capture('t7_duel_${ku ? 'ku' : 'tr'}_scale13');
    }

    freshMockRepository();
    final bracket = TournamentBracket(
      tournamentId: 't7-final',
      userId: 'ali',
      rounds: const [
        TournamentRound(
          roundNumber: 1,
          status: 'active',
          matches: [
            TournamentMatch(
              id: 't7-final-match',
              playerOneId: 'other',
              playerOneName: 'Bero',
              playerTwoId: 'ali',
              playerTwoName: 'Ali',
              playerOneScore: 888,
              playerTwoScore: 0,
              playerTwoSubmitted: false,
              status: 'active',
              winnerId: '',
            ),
          ],
        ),
      ],
      currentRound: 0,
      status: 'active',
      createdAt: DateTime.utc(2026, 10, 30),
    );
    await show(TournamentScreen(repository: _VisualRepo(bracket: bracket)));
    expect(find.byType(TournamentScreen), findsOneWidget);
    final selfMark = find.byKey(const ValueKey('tournament-match-self-mark'));
    expect(selfMark, findsOneWidget);
    final matchCard = find
        .ancestor(of: selfMark, matching: find.byType(SahneStageCard))
        .first;
    await tester.ensureVisible(matchCard);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Final'), findsWidgets);
    expect(find.text('Sen'), findsWidgets);
    await capture('t7_tournament_final_self');

    await show(
      AsyncDuelPlayScreen(
        repository: _VisualRepo(),
        entry: const AsyncDuelEntry.tournament('t7-timer', roundLabel: 'Final'),
      ),
    );
    expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
    expect(
      tester.widget<SahneStageTimer>(find.byType(SahneStageTimer)).pending,
      isFalse,
    );
    await tester.tap(find.text('Du'));
    await tester.pump(const Duration(milliseconds: 150));
    // Native compositorun yeni kareyi göstermesi için kısa gerçek bekleme.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(
      tester.widget<SahneStageTimer>(find.byType(SahneStageTimer)).pending,
      isTrue,
    );
    expect(find.text('–'), findsOneWidget);
    // Doğru cevap açılışı yalnız 1,2 sn. Kare komutu hemen verilir;
    // 500 ms sonra hâlâ aynı evrede olduğumuz ayrıca doğrulanır.
    // ignore: avoid_print
    print('CAPTURE_SCREENSHOT: t7_tournament_reveal_timer');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(
      tester.widget<SahneStageTimer>(find.byType(SahneStageTimer)).pending,
      isTrue,
    );
    expect(find.text('–'), findsOneWidget);

    await show(
      Scaffold(
        appBar: AppBar(title: const Text('Hesabını kaydet')),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: AuthSocialButtons(
            linking: true,
            showApple: true,
            onApple: () {},
            onGoogle: () {},
          ),
        ),
      ),
    );
    expect(find.byType(AuthSocialButtons), findsOneWidget);
    expect(find.text('Apple ile devam et'), findsOneWidget);
    expect(find.text('Google ile devam et'), findsOneWidget);
    await capture('t7_auth_linking');

    final lobbyRepo = _VisualRepo();
    await show(
      RoomScreen(
        repository: lobbyRepo,
        initialRoom: GameRoom(
          id: 't7-offline-lobby',
          name: 'T7',
          code: 'ZK-T7',
          category: 'Ziman',
          players: lobbyRepo.lobbyPlayers,
          hostId: 'dlan', // Host sonradan başa taşınamaz.
          status: RoomStatus.lobby,
        ),
      ),
    );
    expect(find.byType(RoomScreen), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.byKey(ValueKey('room-player-tile-$i')), findsOneWidget);
    }
    final names = ['Ali', 'Bero', 'Cano', 'Dlan'];
    for (var i = 0; i < names.length; i++) {
      expect(
        find.descendant(
          of: find.byKey(ValueKey('room-player-tile-${i + 1}')),
          matching: find.textContaining(names[i]),
        ),
        findsWidgets,
      );
    }
    await capture('t7_lobby_server_order');

    await show(
      const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SahneResultRewards(
              coins: 1202,
              xp: 1202,
              progress: SahneResultLevelProgress(
                levelLabel: '12',
                xpInLevel: 1436,
                xpNeeded: 2500,
                progress: 1436 / 2500,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(SahneResultRewards), findsOneWidget);
    expect(find.text('+1.202 XP'), findsOneWidget);
    expect(find.text('1.436 / 2.500 XP'), findsOneWidget);
    await capture('t7_rewards_xp');

    final resultRepo = freshMockRepository();
    await show(
      QuizResultScreen(
        repository: resultRepo,
        room: resultRepo.createRoom(),
        score: 1202,
        correctCount: 8,
        wrongCount: 2,
        totalQuestions: 10,
        bestStreak: 5,
        coinsAwarded: 1202,
        answerRecords: const [],
        opponents: const [
          Player(id: 'opp', name: 'Bero', score: 888, state: 'Bot'),
        ],
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(QuizResultScreen), findsOneWidget);
    expect(find.textContaining('1.202 – 888'), findsOneWidget);
    await capture('t7_result_scores');

    await show(PlayHubScreen(repository: _VisualRepo()));
    final weekly = find.byKey(const ValueKey('play-hub-this-week'));
    await tester.ensureVisible(weekly);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(PlayHubScreen), findsOneWidget);
    expect(
      find.descendant(of: weekly, matching: find.text('4.404')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: weekly, matching: find.text('#1.202')),
      findsOneWidget,
    );
    await capture('t7_play_weekly');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
