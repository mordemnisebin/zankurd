import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/widget_test_helpers.dart';

/// Turnuvanın gerçek oyunculara çevrilmesinin bekçisi.
///
/// 2026-07-26'ya kadar turnuva tümüyle istemci tarafında bir bot
/// benzetimiydi: `joinTournament` Supabase deposunda bile sahte depoya
/// yöneliyordu ve oyuncular hiç karşılaşmıyordu. Artık eşleştirmeyi,
/// kazananı ve ilerlemeyi sunucu belirler.
///
/// Sunucu tarafının kullanılabilir olup olmadığı **dönüş değeriyle**
/// söylenir (`joinRealTournament` → `null`), bayrakla ya da şema kimliğine
/// bakarak değil. İlk denemede kimliğe bakılıyordu ve sahte depo sunucu
/// sanılıyordu; bu testler o ayrımı sabitler.
class _RealTournamentRepository extends MockZanKurdRepository {
  _RealTournamentRepository(this.bracket);

  final TournamentBracket bracket;

  /// Şemadaki oyuncu kimliğiyle aynı olmalı: ekran "benim maçım"ı buna
  /// bakarak bulur.
  @override
  String? get currentUserId => 'me';
  int joinCalls = 0;
  int championClaims = 0;
  int championReward = 200;
  int submitCalls = 0;
  String? submittedMatchId;
  int? submittedScore;
  int? submittedOpponentScore;

  @override
  Future<TournamentBracket?> joinRealTournament() async {
    joinCalls++;
    return bracket;
  }

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => bracket;

  @override
  Future<int> claimTournamentChampionReward() async {
    championClaims++;
    return championReward;
  }

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    submitCalls++;
    submittedMatchId = matchId;
    submittedScore = playerScore;
    submittedOpponentScore = opponentScore;
    return const TournamentMatch(
      id: 'm1',
      playerOneId: 'me',
      playerOneName: 'Ben',
      playerTwoId: 'p2',
      playerTwoName: 'Rojda',
      playerOneScore: 0,
      playerTwoScore: 0,
      status: 'pending',
      winnerId: '',
    );
  }
}

TournamentBracket _bracketWith(
  List<TournamentMatch> matches, {
  List<TournamentMatch>? secondRound,
  int currentRound = 0,
  String status = 'active',
}) => TournamentBracket(
  tournamentId: 't1',
  userId: 'me',
  currentRound: currentRound,
  status: status,
  rounds: [
    TournamentRound(roundNumber: 1, matches: matches),
    if (secondRound != null)
      TournamentRound(roundNumber: 2, matches: secondRound),
  ],
  createdAt: DateTime(2026, 7, 26),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
  });

  testWidgets('kontenjan dolmadıysa bot uydurulmaz, beklenir', (tester) async {
    // Boş şema = turnuva henüz kurulmadı. Eski davranış burada 16 bot
    // üretiyordu; gerçek oyunculu turnuvada doğru olan beklemektir.
    final repository = _RealTournamentRepository(_bracketWith(const []));

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('tournament-waiting')),
      findsOneWidget,
      reason: 'bekleme durumu gösterilmedi',
    );
    expect(find.textContaining('Bot'), findsNothing);
  });

  testWidgets('sunucudan gelen şemada gerçek rakip adı görünür', (
    tester,
  ) async {
    final repository = _RealTournamentRepository(
      _bracketWith(const [
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
      ]),
    );

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Rojda'), findsWidgets);
  });

  testWidgets('skorunu bildirip rakibi bekleyen oyuncuya durum söylenir', (
    tester,
  ) async {
    // Kendi skorumuz yazılmış ama maç kapanmamış: rakip henüz oynamamış.
    // Söylenmezse oyuncu bir şeyin bozulduğunu sanır.
    final repository = _RealTournamentRepository(
      _bracketWith(const [
        TournamentMatch(
          id: 'm1',
          playerOneId: 'me',
          playerOneName: 'Ben',
          playerTwoId: 'p2',
          playerTwoName: 'Rojda',
          playerOneScore: 640,
          playerTwoScore: 0,
          status: 'pending',
          winnerId: '',
        ),
      ]),
    );

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('tournament-awaiting-opponent')),
      findsOneWidget,
    );
  });

  testWidgets('sunucu yoksa ekran bot benzetimine düşer', (tester) async {
    // Karşı taraf: migration uygulanmamış ya da cihaz çevrimdışıyken
    // turnuva ekranı boş kalmamalı. Sahte depo `null` döndürür.
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: MockZanKurdRepository())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('tournament-waiting')), findsNothing);
  });

  testWidgets('ikinci turdaki oyuncunun maçı doğru turda aranır', (
    tester,
  ) async {
    // `currentRound` sunucudan gelmezse 0'a düşer: ikinci turdaki oyuncu
    // birinci turda aranır, maçı bulunamaz ve ekran yanlış tur adını
    // yazar. Sunucu bu alanı gönderdiği için burada da gelmeli.
    final repository = _RealTournamentRepository(
      _bracketWith(
        const [
          TournamentMatch(
            id: 'm1',
            playerOneId: 'me',
            playerOneName: 'Ben',
            playerTwoId: 'p2',
            playerTwoName: 'Rojda',
            playerOneScore: 700,
            playerTwoScore: 400,
            status: 'completed',
            winnerId: 'me',
          ),
        ],
        secondRound: const [
          TournamentMatch(
            id: 'm2',
            playerOneId: 'me',
            playerOneName: 'Ben',
            playerTwoId: 'p3',
            playerTwoName: 'Baran',
            playerOneScore: 0,
            playerTwoScore: 0,
            status: 'pending',
            winnerId: '',
          ),
        ],
        currentRound: 1,
      ),
    );

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Baran'), findsWidgets);
  });

  testWidgets('elenen oyuncuya yeni maç gösterilmez', (tester) async {
    // Birinci turda kaybeden oyuncu, kupa sürerken "maçın var" görüyordu:
    // elenme turnuvanın bitmesine bağlanmıştı. Sunucu artık açık maçı
    // olmayan ve kaybetmiş oyuncuyu 'eliminated' bildiriyor.
    final repository = _RealTournamentRepository(
      _bracketWith(const [
        TournamentMatch(
          id: 'm1',
          playerOneId: 'me',
          playerOneName: 'Ben',
          playerTwoId: 'p2',
          playerTwoName: 'Rojda',
          playerOneScore: 300,
          playerTwoScore: 900,
          status: 'completed',
          winnerId: 'p2',
        ),
      ], status: 'eliminated'),
    );

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('tournament-awaiting-opponent')),
      findsNothing,
    );
  });

  testWidgets('şampiyon ödülü talep edilir ve bildirilir', (tester) async {
    // Bu çağrıyı hiçbir ekran yapmıyordu: kupayı kazanan oyuncu ödülünü
    // hiç almıyordu. Hak edişi ve miktarı sunucu belirler; istemcinin işi
    // yalnız istemek ve sonucu göstermek.
    final repository = _RealTournamentRepository(
      _bracketWith(const [
        TournamentMatch(
          id: 'm1',
          playerOneId: 'me',
          playerOneName: 'Ben',
          playerTwoId: 'p2',
          playerTwoName: 'Rojda',
          playerOneScore: 900,
          playerTwoScore: 300,
          status: 'completed',
          winnerId: 'me',
        ),
      ], status: 'won'),
    );

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.championClaims, 1);
    expect(find.textContaining('200 coin'), findsOneWidget);
  });

  testWidgets('şampiyon olmayan oyuncu ödül istemez', (tester) async {
    // Karşı taraf: her açılışta istemek, sunucunun "şampiyon değilsin"
    // yanıtını gürültüye çevirir ve ekranda yanlış bir kutlama riski
    // doğurur.
    final repository = _RealTournamentRepository(
      _bracketWith(const [
        TournamentMatch(
          id: 'm1',
          playerOneId: 'me',
          playerOneName: 'Ben',
          playerTwoId: 'p2',
          playerTwoName: 'Rojda',
          playerOneScore: 300,
          playerTwoScore: 900,
          status: 'completed',
          winnerId: 'p2',
        ),
      ], status: 'eliminated'),
    );

    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.championClaims, 0);
  });
}
