/// Sunucu puanlı turnuva maçı (istemci) bekçisi.
///
/// ## Kusur
///
/// Lobi "Şampiyon ödülü 200 jeton" diyordu ama sunucu ödemiyordu: maç skoru
/// istemciden geldiği için (hile) ödül 2026-10-02'de kapatılmıştı. 4
/// simülatörlü turda şampiyon "Ödül henüz doğrulanmadı" gördü (2026-10-27).
///
/// ## Niçin sessiz kalırdı
///
/// Ekran ödülün sıfır döndüğünü dürüstçe "doğrulanmadı" diye yazıyordu;
/// hiçbir test lobideki vaatle sunucunun ödemesini yan yana koymadı.
///
/// ## Kural
///
/// * Sunucu puanlı kupada (`serverScored`) maç, sırayla düellonun sunucu
///   sözleşmeli oyun ekranında TURNUVA RPC'leriyle oynanır; düello RPC'si
///   çağrılmaz, istemci skoru gönderilmez.
/// * Ekranda tur adı ve rakip görünür; çıkış diyaloğu "maç" der.
/// * Son cevaptan sonra sonuç ekranı açılmaz, şemaya "tamamlandı" ile
///   dönülür.
/// * Sunucu puanlı olmayan (eski) kupada eski yol sürer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/widget_test_helpers.dart';

QuizQuestion _q(int i) => QuizQuestion.fromServerRow({
  'id': 'q$i',
  'category_name': 'Ziman',
  'prompt': 'Pirs $i',
  'option_a': 'Yek',
  'option_b': 'Du',
  'option_c': 'Sê',
  'option_d': 'Çar',
  'difficulty': 1,
});

/// Sunucunun başlangıçta verdiği yer tutucu: içerik sunumda gelir.
QuizQuestion _stub(int i) => QuizQuestion.fromServerRow({
  'id': 'pending-$i',
  'category_name': 'Ziman',
  'prompt': '',
  'option_a': '',
  'option_b': '',
});

class _ServerScoredRepo extends MockZanKurdRepository {
  _ServerScoredRepo(this.bracket);

  TournamentBracket bracket;
  final List<String> calls = [];
  int submits = 0;
  bool failNextPresent = false;
  bool emptyNextPresent = false;

  @override
  String? get currentUserId => 'me';

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => bracket;

  @override
  Future<TournamentBracket?> joinRealTournament() async => bracket;

  @override
  Future<AsyncDuelStart> startTournamentMatch(String matchId) async {
    calls.add('start:$matchId');
    return AsyncDuelStart(
      duelId: matchId,
      role: AsyncDuelRole.creator,
      opponentName: 'Rojda',
      opponentId: 'p2',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      questions: [for (var i = 0; i < 4; i++) _stub(i)],
    );
  }

  @override
  Future<TournamentPresent> presentTournamentQuestion(
    String matchId,
    int index,
  ) async {
    calls.add('present:$index');
    if (failNextPresent) {
      failNextPresent = false;
      throw StateError('network');
    }
    if (emptyNextPresent) {
      emptyNextPresent = false;
      return const TournamentPresent(elapsedMs: 0);
    }
    return TournamentPresent(elapsedMs: 0, question: _q(index));
  }

  @override
  Future<AsyncDuelAnswer> answerTournamentQuestion({
    required String matchId,
    required int questionIndex,
    required String choice,
  }) async {
    calls.add('answer:$questionIndex:$choice');
    final last = questionIndex == 3;
    return AsyncDuelAnswer(
      correct: choice == 'A',
      correctOption: 'A',
      answered: questionIndex + 1,
      total: 4,
      finished: last,
      result: last
          ? const AsyncDuelResult(waiting: true, myCorrect: 4, myMs: 4000)
          : null,
    );
  }

  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    calls.add('DUEL');
    return super.answerAsyncDuel(
      duelId: duelId,
      questionIndex: questionIndex,
      choice: choice,
      responseMs: responseMs,
    );
  }

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    submits++;
    return super.submitTournamentMatch(
      matchId: matchId,
      playerScore: playerScore,
      opponentScore: opponentScore,
    );
  }
}

class _PaidChampionRepo extends _ServerScoredRepo {
  _PaidChampionRepo(super.bracket);

  @override
  Future<ChampionRewardClaim> claimChampionRewardStatus() async =>
      const ChampionRewardClaim(amount: 0, alreadyPaid: 200);
}

TournamentBracket _bracket({required bool serverScored}) => TournamentBracket(
  tournamentId: 't1',
  userId: 'me',
  rounds: const [
    TournamentRound(
      roundNumber: 1,
      matches: [
        TournamentMatch(
          id: 'm1',
          playerOneId: 'me',
          playerOneName: 'Ben',
          playerTwoId: 'p2',
          playerTwoName: 'Rojda',
          playerOneScore: 0,
          playerTwoScore: 0,
          status: 'pending',
          winnerId: '',
        ),
        TournamentMatch(
          id: 'm2',
          playerOneId: 'p3',
          playerOneName: 'Bergen',
          playerTwoId: 'p4',
          playerTwoName: 'Berfîn',
          playerOneScore: 0,
          playerTwoScore: 0,
          status: 'pending',
          winnerId: '',
        ),
      ],
    ),
  ],
  createdAt: DateTime(2026, 10, 27),
  entryCount: 4,
  size: 4,
  serverScored: serverScored,
);

Future<void> _openTournament(
  WidgetTester tester,
  _ServerScoredRepo repo,
) async {
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(testShell(child: TournamentScreen(repository: repo)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  testWidgets('sunucu puanlı kupa: maç turnuva RPC\'leriyle oynanır, '
      'bitince şemaya dönülür', (tester) async {
    final repo = _ServerScoredRepo(_bracket(serverScored: true));
    await _openTournament(tester, repo);

    await tester.tap(find.text('Maçı başlat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
    expect(find.byType(QuizScreen), findsNothing);
    expect(
      find.byKey(const ValueKey('tournament-match-round')),
      findsOneWidget,
    );
    expect(find.text('Yarı Final'), findsWidgets);
    expect(find.text('Sen vs'), findsOneWidget);
    expect(repo.calls.first, 'start:m1');

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Yek'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(repo.calls, contains('answer:3:A'));
    expect(repo.calls, isNot(contains('DUEL')));
    expect(repo.submits, 0, reason: 'istemci skoru gönderilmez');
    expect(find.byType(AsyncDuelPlayScreen), findsNothing);
    expect(find.byType(TournamentScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tournament-awaiting-opponent')),
      findsOneWidget,
      reason: 'şemaya dönülür, rakip bekleniyor',
    );
  });

  testWidgets('soru içeriği sunumdan gelir; sunum düşerse soru gösterilmez, '
      'yeniden dene', (tester) async {
    final repo = _ServerScoredRepo(_bracket(serverScored: true))
      ..failNextPresent = true;
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelPlayScreen(
          repository: repo,
          entry: const AsyncDuelEntry.tournament('m1', roundLabel: 'Final'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pirs 0'), findsNothing);
    expect(find.text('Yek'), findsNothing);
    final retry = find.byKey(const ValueKey('tournament-present-retry'));
    expect(retry, findsOneWidget);

    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pirs 0'), findsOneWidget);
    expect(find.text('Yek'), findsOneWidget);
    expect(retry, findsNothing);
    expect(repo.calls.where((c) => c == 'present:0'), hasLength(2));
  });

  testWidgets(
    'T5: turnuvada yanlış şık 1,2 sn sonra kaybolurdu; doğru yanıt akışı gizledi',
    (tester) async {
      final repo = _ServerScoredRepo(_bracket(serverScored: true));
      await _openTournament(tester, repo);
      await tester.tap(find.text('Maçı başlat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Du'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2999));
      expect(find.text('Pirs 0'), findsOneWidget);
      expect(repo.calls, isNot(contains('present:1')));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(repo.calls, contains('present:1'));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rakip bekleniyor kartı rakip bitirince kendiliğinden kalkar', (
    tester,
  ) async {
    final repo = _ServerScoredRepo(_bracket(serverScored: true));
    await _openTournament(tester, repo);
    await tester.tap(find.text('Maçı başlat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Yek'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
    }
    await tester.pump(const Duration(milliseconds: 400));
    final awaiting = find.byKey(const ValueKey('tournament-awaiting-opponent'));
    expect(awaiting, findsOneWidget);

    // Rakip oynadı: maç kapandı, final kuruldu.
    repo.bracket = repo.bracket.copyWith(
      currentRound: 1,
      rounds: [
        repo.bracket.rounds.first.copyWith(
          matches: [
            repo.bracket.rounds.first.matches.first.copyWith(
              status: 'completed',
              playerOneScore: 541,
              playerTwoScore: 144,
              winnerId: 'me',
            ),
            repo.bracket.rounds.first.matches.last,
          ],
        ),
        const TournamentRound(
          roundNumber: 2,
          matches: [
            TournamentMatch(
              id: 'm3',
              playerOneId: 'me',
              playerOneName: 'Ben',
              playerTwoId: 'p4',
              playerTwoName: 'Berfîn',
              playerOneScore: 0,
              playerTwoScore: 0,
              status: 'pending',
              winnerId: '',
            ),
          ],
        ),
      ],
    );
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(awaiting, findsNothing);
    expect(find.text('Maçı başlat'), findsOneWidget, reason: 'final maçı');
  });

  // GPT-6 Sol incelemesi (2026-10-28): sunum içeriksiz gelirse yer tutucu
  // soru açılıp sayaç başlıyordu.
  testWidgets('sunum içeriksiz gelirse soru açılmaz, yeniden dene çıkar', (
    tester,
  ) async {
    final repo = _ServerScoredRepo(_bracket(serverScored: true))
      ..emptyNextPresent = true;
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelPlayScreen(
          repository: repo,
          entry: const AsyncDuelEntry.tournament('m1', roundLabel: 'Final'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final retry = find.byKey(const ValueKey('tournament-present-retry'));
    expect(retry, findsOneWidget);
    expect(find.text('Yek'), findsNothing);
    await tester.tap(retry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pirs 0'), findsOneWidget);
  });

  testWidgets('turnuva maçında çıkış diyaloğu "maç" der', (tester) async {
    final repo = _ServerScoredRepo(_bracket(serverScored: true));
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelPlayScreen(
          repository: repo,
          entry: const AsyncDuelEntry.tournament('m1', roundLabel: 'Final'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byKey(const ValueKey('async-duel-quit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Maçtan çıkılsın mı?'), findsOneWidget);
    expect(find.text('Düellodan çıkılsın mı?'), findsNothing);
  });

  testWidgets('sunucu puanlı olmayan eski kupa eski yolda kalır', (
    tester,
  ) async {
    final repo = _ServerScoredRepo(_bracket(serverScored: false));
    await _openTournament(tester, repo);
    await tester.tap(find.text('Maçı başlat'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AsyncDuelPlayScreen), findsNothing);
    expect(repo.calls, isEmpty);
  });

  // 2026-10-27 (dış inceleme 3. tur): ödülü bir kez alan şampiyon ekranı
  // yeniden açınca sunucu "talep edilmedi, 0" diyordu; ekran "Ödül henüz
  // doğrulanmadı" yazıyordu. Artık "zaten alındı" → "Ödül verildi", kutlama
  // bildirimi tekrarlanmaz.
  testWidgets('zaten ödenmiş şampiyonluk "Ödül verildi" der, kutlamaz', (
    tester,
  ) async {
    final repo = _PaidChampionRepo(
      _bracket(serverScored: true).copyWith(status: 'won'),
    );
    await _openTournament(tester, repo);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ödül verildi'), findsOneWidget);
    expect(find.text('Ödül henüz doğrulanmadı'), findsNothing);
    expect(find.textContaining('Şampiyonluk ödülün'), findsNothing);
  });

  test('şema yanıtındaki serverScored ayrıştırılır', () {
    final parsed = TournamentBracket.fromJson(const {
      'tournamentId': 't',
      'userId': 'me',
      'rounds': <Object>[],
      'serverScored': true,
    });
    expect(parsed.serverScored, isTrue);
    expect(
      TournamentBracket.fromJson(const {
        'tournamentId': 't',
        'userId': 'me',
        'rounds': <Object>[],
      }).serverScored,
      isFalse,
      reason: 'eski sunucu: eski yol',
    );
  });
}
