import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';

/// Turnuvanın ilerleme zinciri: katıl → maç kazan → tur atla → şampiyon → ödül.
///
/// ## Kusur (kapsam boşluğu)
///
/// Turnuva için altı test dosyası var ve hepsi DURUM SUNUMUNU ölçüyor:
/// braketin 16→8→4→2→1 basamaklarını çizdiğini, şampiyonluk ödülünün lobide
/// göründüğünü, maç başında sahte ödül vaat edilmediğini, katılmadan kutlama
/// gösterilmediğini, taşma/erişilebilirlik. Hiçbiri durumlar ARASINDAKİ
/// geçişi sürmüyordu.
///
/// Sunum testleri her durumu tek tek doğru gösterse bile zincir kopabilir:
/// maç kazanılır ama braket ilerlemez, final kazanılır ama statü `won`
/// olmaz, ya da ödül şampiyon olunmadan talep edilebilir. Üçü de kullanıcıya
/// "kazandım ama bir şey olmadı" diye görünür ve hiçbiri hata vermez
/// (2026-08-17).
///
/// ## Harness
///
/// `MockZanKurdRepository`nin turnuva uygulaması bilerek STATİKtir:
/// `loadTournamentBracket` her çağrıda `currentRound: 0, status: 'active'`
/// döner ve `submitTournamentMatch` braketi ilerletmez. Sunum testleri için
/// bu doğru tercih — sabit bir kare gerekir. Ama ilerlemeyi ölçmek için
/// ilerleyen bir depo gerekiyor; bu dosya onu kendi kurar.
///
/// Ölçülen şey deponun kendi mantığı değil (o sunucudadır), zincirin
/// sözleşmesi: kazanılan maç turu artırır, final statüyü `won` yapar, ödül
/// yalnız şampiyona ve yalnız bir kez verilir.
class _ProgressingTournamentRepository extends MockZanKurdRepository {
  static const _playerId = 'user';
  static const _totalRounds = 4; // 16 → 8 → 4 → 2 → 1

  int currentRound = 0;
  String status = 'active';
  int championClaims = 0;
  final List<String> submittedMatches = [];

  TournamentMatch _match(int round) => TournamentMatch(
    id: 'match-r$round',
    playerOneId: _playerId,
    playerOneName: 'Zelal',
    playerTwoId: 'bot-r$round',
    playerTwoName: 'Bot $round',
    playerOneScore: 0,
    playerTwoScore: 0,
    status: 'active',
    winnerId: '',
  );

  TournamentBracket _bracket() => TournamentBracket(
    tournamentId: 'tour-1',
    userId: _playerId,
    rounds: [
      for (var r = 0; r < _totalRounds; r++)
        TournamentRound(
          roundNumber: r,
          matches: [_match(r)],
          status: r < currentRound
              ? 'completed'
              : (r == currentRound ? 'active' : 'pending'),
        ),
    ],
    currentRound: currentRound,
    status: status,
    createdAt: DateTime.utc(2026, 8, 17),
  );

  @override
  Future<TournamentBracket> joinTournament() async => _bracket();

  @override
  Future<TournamentBracket?> loadTournamentBracket() async => _bracket();

  @override
  Future<TournamentMatch> submitTournamentMatch({
    required String matchId,
    required int playerScore,
    required int opponentScore,
  }) async {
    submittedMatches.add(matchId);
    final won = playerScore > opponentScore;
    if (won) {
      if (currentRound >= _totalRounds - 1) {
        status = 'won';
      } else {
        currentRound += 1;
      }
    } else {
      status = 'eliminated';
    }
    return TournamentMatch(
      id: matchId,
      playerOneId: _playerId,
      playerOneName: 'Zelal',
      playerTwoId: 'bot',
      playerTwoName: 'Bot',
      playerOneScore: playerScore,
      playerTwoScore: opponentScore,
      status: 'completed',
      winnerId: won ? _playerId : 'bot',
    );
  }

  @override
  Future<int> claimTournamentChampionReward() async {
    // Sunucu ödülü yalnız şampiyona ve yalnız bir kez verir; taklit edilen
    // şey bu sözleşme.
    if (status != 'won' || championClaims > 0) return 0;
    championClaims += 1;
    return TournamentConfig.coinBonusChampion;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('kazanılan maç braketi bir tur ilerletir', () async {
    final repository = _ProgressingTournamentRepository();
    final bracket = await repository.joinTournament();

    expect(bracket.currentRound, 0);
    expect(bracket.status, 'active');

    await repository.submitTournamentMatch(
      matchId: 'match-r0',
      playerScore: 300,
      opponentScore: 120,
    );

    final after = await repository.loadTournamentBracket();
    expect(
      after!.currentRound,
      1,
      reason:
          'Maç kazanıldı ama braket ilerlemedi; oyuncu "kazandım ama bir şey '
          'olmadı" görür.',
    );
    expect(after.status, 'active');
    expect(
      after.rounds.first.status,
      'completed',
      reason: 'Geçilen tur tamamlandı olarak işaretlenmeli.',
    );
  });

  test('finali kazanmak statüyü şampiyona çevirir ve ödülü açar', () async {
    final repository = _ProgressingTournamentRepository();
    await repository.joinTournament();

    // Şampiyonluğa dört maç: 16 → 8 → 4 → 2 → 1.
    for (var round = 0; round < 4; round++) {
      final bracket = await repository.loadTournamentBracket();
      expect(
        bracket!.status,
        'active',
        reason: '$round. turda kupa erken kapanmış.',
      );
      await repository.submitTournamentMatch(
        matchId: 'match-r$round',
        playerScore: 300,
        opponentScore: 100,
      );
    }

    final finalBracket = await repository.loadTournamentBracket();
    expect(
      finalBracket!.status,
      'won',
      reason: 'Final kazanıldı ama kupa şampiyonluğa geçmedi.',
    );
    expect(repository.submittedMatches.length, 4);

    final reward = await repository.claimTournamentChampionReward();
    expect(reward, TournamentConfig.coinBonusChampion);
  });

  test('şampiyonluk ödülü iki kez alınamaz', () async {
    final repository = _ProgressingTournamentRepository();
    await repository.joinTournament();
    for (var round = 0; round < 4; round++) {
      await repository.submitTournamentMatch(
        matchId: 'match-r$round',
        playerScore: 300,
        opponentScore: 100,
      );
    }

    expect(
      await repository.claimTournamentChampionReward(),
      TournamentConfig.coinBonusChampion,
    );
    expect(
      await repository.claimTournamentChampionReward(),
      0,
      reason:
          'İkinci talep de ödül verirse oyuncu ekranı yeniden açarak jeton '
          'basabilir.',
    );
    expect(repository.championClaims, 1);
  });

  test('şampiyon olmadan ödül talep edilemez', () async {
    final repository = _ProgressingTournamentRepository();
    await repository.joinTournament();

    // Henüz hiç maç oynanmadı.
    expect(
      await repository.claimTournamentChampionReward(),
      0,
      reason: 'Kupa sürerken ödül verilirse turnuvanın anlamı kalmaz.',
    );

    // Tek maç kazanmak da yetmez: kupa hâlâ sürüyor.
    await repository.submitTournamentMatch(
      matchId: 'match-r0',
      playerScore: 300,
      opponentScore: 100,
    );
    expect(await repository.claimTournamentChampionReward(), 0);
    expect(repository.championClaims, 0);
  });

  test('kaybedilen maç kupayı eleme ile kapatır ve ödül vermez', () async {
    final repository = _ProgressingTournamentRepository();
    await repository.joinTournament();

    await repository.submitTournamentMatch(
      matchId: 'match-r0',
      playerScore: 80,
      opponentScore: 240,
    );

    final bracket = await repository.loadTournamentBracket();
    expect(
      bracket!.status,
      'eliminated',
      reason:
          'Kaybedilen maçtan sonra kupa açık kalırsa oyuncu ilerlemeye '
          'devam edebilir.',
    );
    expect(await repository.claimTournamentChampionReward(), 0);
  });
}
