// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
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

  /// Değiştirilebilir: sessiz yenileme testleri kontenjanın dolmasını
  /// taklit eder.
  TournamentBracket bracket;

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

  // 2026-10-27: bekleme ekranı doluluğu söyler ve kendini yeniler. Önceden
  // ne kaç kişinin katıldığı görünüyordu ne de kontenjan dolunca ekran
  // kendiliğinden şemaya geçiyordu (4 simülatörlü tur).
  testWidgets('beklerken doluluk görünür, dolunca şema kendiliğinden gelir', (
    tester,
  ) async {
    final repository = _RealTournamentRepository(
      _bracketWith(const []).copyWith(entryCount: 1, size: 4),
    );
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('1/4 oyuncu katıldı'), findsOneWidget);

    repository.bracket = _bracketWith(
      const [],
    ).copyWith(entryCount: 3, size: 4);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.textContaining('3/4 oyuncu katıldı'), findsOneWidget);

    repository.bracket = _bracketWith(const [
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
    ]);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('tournament-waiting')), findsNothing);
    expect(find.text('Rojda'), findsWidgets);
  });

  // 2026-10-27: sunucu ikinci turu ancak kazananlar belli olunca kurar.
  // Tur adı `rounds.length`ten çıkınca 4 kişilik kupanın yarı finali
  // "Final" yazıyordu (4 simülatörlü tur). Oyuncu sayısı esas alınır.
  test('totalRounds oyuncu sayısından çıkar, eksik turları sayar', () {
    final one = _bracketWith(const []);
    expect(one.copyWith(entryCount: 4, size: 4).totalRounds, 2);
    expect(one.copyWith(entryCount: 3, size: 4).totalRounds, 2);
    expect(one.copyWith(entryCount: 2, size: 4).totalRounds, 1);
    expect(one.totalRounds, 1, reason: 'sayı yoksa eldeki turlar');
  });

  testWidgets('ilk turu kurulmuş 4 kişilik kupada tur adı Yarı Final', (
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
      ]).copyWith(entryCount: 4, size: 4),
    );
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Yarı Final'), findsWidgets);
    // Kurulmamış final de şeritte "sırada" görünür.
    expect(find.text('Final'), findsWidgets);
  });

  // 2026-10-27: beklerken açıkça "botlarla" diye adlandırılan, ödülsüz
  // antrenman kupası sunulur; gerçek kupadaki kayıt sürer.
  testWidgets('beklerken antrenman kupası açılır ve öyle adlandırılır', (
    tester,
  ) async {
    final repository = _RealTournamentRepository(_bracketWith(const []));
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Beklerken botlarla antrenman yap'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('tournament-waiting')), findsNothing);
    expect(find.text('Antrenman kupası · botlarla'), findsOneWidget);
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
    // Gerçek kupada "antrenman" etiketi yanlış olurdu (2026-10-27'ye dek
    // her şemada "Yerel turnuva" yazıyordu).
    expect(find.text('Antrenman kupası · botlarla'), findsNothing);
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

  // Codex denetimi 2026-10-29 (hata #6): yarı finalini erken kazanan oyuncunun
  // `_userMatch`i boşalıyordu ve periyodik yenileme sorgu yapmıyordu; diğer
  // yarı final bitip final kurulsa da ekran eski kalıyordu.
  testWidgets('yarı finalini kazanan oyuncuya final kendiliğinden gelir', (
    tester,
  ) async {
    const won = TournamentMatch(
      id: 'm1',
      playerOneId: 'me',
      playerOneName: 'Ben',
      playerTwoId: 'p2',
      playerTwoName: 'Rojda',
      playerOneScore: 640,
      playerTwoScore: 300,
      status: 'completed',
      winnerId: 'me',
    );
    const otherPending = TournamentMatch(
      id: 'm2',
      playerOneId: 'p3',
      playerOneName: 'Bergen',
      playerTwoId: 'p4',
      playerTwoName: 'Berfîn',
      playerOneScore: 0,
      playerTwoScore: 0,
      status: 'pending',
      winnerId: '',
    );
    final repository = _RealTournamentRepository(
      _bracketWith(const [won, otherPending]).copyWith(entryCount: 4, size: 4),
    );
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Zeynep'), findsNothing);

    repository.bracket = _bracketWith(
      const [
        won,
        TournamentMatch(
          id: 'm2',
          playerOneId: 'p3',
          playerOneName: 'Bergen',
          playerTwoId: 'p4',
          playerTwoName: 'Berfîn',
          playerOneScore: 500,
          playerTwoScore: 100,
          status: 'completed',
          winnerId: 'p3',
        ),
      ],
      secondRound: const [
        TournamentMatch(
          id: 'm3',
          playerOneId: 'me',
          playerOneName: 'Ben',
          playerTwoId: 'p3',
          playerTwoName: 'Zeynep',
          playerOneScore: 0,
          playerTwoScore: 0,
          status: 'pending',
          winnerId: '',
        ),
      ],
      currentRound: 1,
    ).copyWith(entryCount: 4, size: 4);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Zeynep'), findsWidgets);
  });

  // Codex denetimi 2026-10-29 (hata #11): 0 puanla bitirilen maçın "gönderildi"
  // bilgisi yalnız bellekteydi; ekran yeniden açılınca "Başlat" geri geliyordu.
  testWidgets('0 puanla gönderilmiş maç yeniden açılınca tekrar oynanmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.navTour.seen': true,
      'zankurd.tournament.submittedMatches': ['m1'],
    });
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
    expect(
      find.byKey(const ValueKey('tournament-awaiting-opponent')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tournament-primary-cta')), findsNothing);
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
    await tester.tap(find.byKey(const ValueKey('tournament-primary-cta')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.text('Antrenman kupası · botlarla'),
      findsOneWidget,
      reason:
          'Bot benzetimi gerçek oyuncu turnuvası gibi görünmemeli; yerel '
          'olduğu şema ekranında açıkça yazılmalı.',
    );
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
    expect(find.textContaining('200 jeton'), findsOneWidget);
    // `TournamentBracket.totalScore` hiçbir yolda doldurulmuyordu —
    // "Final skoru" her zaman 0 gösteriyordu. Skor zaten maçta duruyor
    // (playerOneScore: 900); ekran onu toplayıp göstermeli
    // (2026-08-14 denetimi).
    // Geniş ekranda iki sütunlu düzen aynı metni iki kez çizebilir
    // (bkz. bu dosyadaki diğer testlerdeki `findsWidgets` deseni).
    expect(find.textContaining('Toplam puan: 900'), findsWidgets);
  });

  testWidgets(
    'bitmiş turnuvadan sonra yeni turnuvaya katılma düğmesi görünür',
    (tester) async {
      // `get_tournament_bracket` kullanıcının EN SON kaydını döndürmeye
      // devam eder — biten turnuva sonsuza kadar "en son" kalır. Düzeltme
      // öncesi `_bracket` bu yüzden bir daha hiç null olmuyor, lobideki
      // "Katıl" düğmesi kalıcı olarak kayboluyordu (2026-08-14 denetimi).
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
        ], status: 'eliminated').copyWith(completedAt: DateTime(2026, 7, 27)),
      );

      await tester.pumpWidget(
        testShell(child: TournamentScreen(repository: repository)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final joinAgain = find.byKey(const ValueKey('tournament-join-new-cta'));
      expect(joinAgain, findsOneWidget);

      await tester.tap(joinAgain);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // `_load()` yalnız `loadRealTournamentBracket` çağırır; `Katıl`
      // düğmesine dokununca `joinRealTournament` (ve dolayısıyla
      // sunucudaki `join_tournament`) İLK KEZ çağrılır — bu, yeni bir
      // turnuvaya katılma girişiminin kanıtıdır.
      expect(repository.joinCalls, 1);
    },
  );

  // 2026-10-27 (4 simülatörlü tur): yarı finalde elenen oyuncuya final
  // kurulunca "Final turunda elendin · 2/2" yazıyordu ve kupa sürerken
  // basılınca hiçbir şey yapmayan "Turnuvaya katıl" düğmesi çıkıyordu.
  testWidgets('kupa sürerken elenen: doğru tur, katıl düğmesi yok', (
    tester,
  ) async {
    const semi = [
      TournamentMatch(
        id: 'm1',
        playerOneId: 'p2',
        playerOneName: 'Rojda',
        playerTwoId: 'me',
        playerTwoName: 'Ben',
        playerOneScore: 245,
        playerTwoScore: 0,
        status: 'completed',
        winnerId: 'p2',
      ),
      TournamentMatch(
        id: 'm2',
        playerOneId: 'p3',
        playerOneName: 'Bergen',
        playerTwoId: 'p4',
        playerTwoName: 'Berfîn',
        playerOneScore: 552,
        playerTwoScore: 383,
        status: 'completed',
        winnerId: 'p3',
      ),
    ];
    const finalMatch = [
      TournamentMatch(
        id: 'm3',
        playerOneId: 'p2',
        playerOneName: 'Rojda',
        playerTwoId: 'p3',
        playerTwoName: 'Bergen',
        playerOneScore: 0,
        playerTwoScore: 0,
        status: 'pending',
        winnerId: '',
      ),
    ];
    final repository = _RealTournamentRepository(
      _bracketWith(
        semi,
        secondRound: finalMatch,
        // Sunucu elenen oyuncuya kupanın son turunu verir.
        currentRound: 1,
        status: 'eliminated',
      ).copyWith(entryCount: 4, size: 4),
    );
    await tester.binding.setSurfaceSize(const Size(400, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repository)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Yarı Final'), findsWidgets);
    expect(find.text('Tur 1/2'), findsOneWidget);
    expect(find.text('2/2'), findsNothing);
    expect(find.byKey(const ValueKey('tournament-join-new-cta')), findsNothing);
    expect(
      find.byKey(const ValueKey('tournament-next-after-finish')),
      findsOneWidget,
    );
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
