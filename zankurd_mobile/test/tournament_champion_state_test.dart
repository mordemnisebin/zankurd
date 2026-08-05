import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import 'support/widget_test_helpers.dart';

/// Şampiyonluk ve elenme yüzeylerinin DÜRÜSTLÜK sözleşmesi.
///
/// Kupayı kazanmak, ödülün verildiği anlamına gelmez. Ödülü sunucu verir
/// (`claimTournamentChampionReward`) ve bot benzetiminde bu çağrı hiç
/// yapılmaz. Ekran eskiden her iki durumda da aynı altın "Şampiyon!"
/// bandını gösteriyordu: yerel bir kupada oyuncu hiçbir şey almadığı hâlde
/// kutlanıyor ve bunu hiçbir yerde okuyamıyordu (2026-08-04).
///
/// Lobideki "500 şampiyon" bir VAATTİR. Burada yazılan sayı ise sunucunun
/// bildirdiği gerçek miktardır — ikisi karıştırılamaz.
TournamentBracket _bracket({
  required String status,
  int currentRound = 3,
  int totalScore = 340,
}) {
  final rounds = <TournamentRound>[];
  var per = 8;
  for (var i = 0; i < 4; i++) {
    rounds.add(
      TournamentRound(
        roundNumber: i + 1,
        matches: [
          for (var m = 0; m < per; m++)
            TournamentMatch(
              id: 'r${i}m$m',
              playerOneId: m == 0 ? 'user' : 'bot$m',
              playerOneName: m == 0 ? 'Rojhat' : 'Bot $m',
              playerTwoId: 'rival$m',
              playerTwoName: 'Rakip $m',
              playerOneScore: 340,
              playerTwoScore: 280,
              status: 'completed',
              winnerId: m == 0 ? 'user' : 'bot$m',
            ),
        ],
        status: 'completed',
      ),
    );
    per = per > 1 ? per ~/ 2 : 1;
  }
  return TournamentBracket(
    tournamentId: 'daily',
    userId: 'user',
    rounds: rounds,
    currentRound: currentRound,
    status: status,
    totalScore: totalScore,
    createdAt: DateTime.utc(2026, 8, 4),
  );
}

/// Yerel benzetim: `loadRealTournamentBracket` null döner, yani sunucu
/// tarafı yok ve ödül hiç talep edilmez.
class _LocalRepo extends MockZanKurdRepository {
  _LocalRepo(this.status);

  final String status;

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => null;

  @override
  Future<TournamentBracket?> loadTournamentBracket() async =>
      _bracket(status: status);

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [];
}

/// Sunucu şeması; ödül talebi [rewardAmount] döner.
class _ServerRepo extends MockZanKurdRepository {
  _ServerRepo({this.rewardAmount = 500, this.throws = false});

  final int rewardAmount;
  final bool throws;
  int claims = 0;

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async =>
      _bracket(status: 'won');

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [];

  @override
  Future<int> claimTournamentChampionReward() async {
    claims++;
    if (throws) throw StateError('server down');
    return rewardAmount;
  }
}

Future<void> _pump(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  Size size = const Size(390, 1400),
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      themeProvider: ThemeProvider(initialMode: mode),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: TournamentScreen(repository: repo)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Ödül dürüstlüğü ─────────────────────────────────────────────────────

  testWidgets('yerel kupada ödül verilmediği açıkça yazılır', (tester) async {
    await _pump(tester, _LocalRepo('won'));
    expect(find.byKey(const ValueKey('tournament-champion')), findsOneWidget);
    expect(
      find.text('Bu kupa yerel oynandı — ödül verilmez'),
      findsOneWidget,
      reason: 'yerel kupada kutlama var ama ödül yok; bu söylenmeli',
    );
  });

  testWidgets('yerel kupada ödül jetonu çizilmez', (tester) async {
    await _pump(tester, _LocalRepo('won'));
    // Lobideki "500" bir vaat; burada gerçek miktar yazılır ve yerel
    // kupada gerçek miktar yoktur.
    expect(find.text('500'), findsNothing);
  });

  testWidgets('sunucu ödülü verdiyse gerçek miktar yazılır', (tester) async {
    final repo = _ServerRepo(rewardAmount: 500);
    await _pump(tester, repo);
    expect(repo.claims, greaterThan(0));
    expect(find.text('Ödül verildi'), findsOneWidget);
    expect(find.text('500'), findsWidgets);
  });

  testWidgets('sunucu sıfır döndüyse "verildi" denmez', (tester) async {
    // Sıfır: hak ediş doğrulanmamış ya da aynı kupa zaten talep edilmiş.
    final repo = _ServerRepo(rewardAmount: 0);
    await _pump(tester, repo);
    expect(find.text('Ödül verildi'), findsNothing);
    expect(find.text('Ödül henüz doğrulanmadı'), findsOneWidget);
  });

  testWidgets('ödül çağrısı hata verirse "verildi" denmez', (tester) async {
    final repo = _ServerRepo(throws: true);
    await _pump(tester, repo);
    expect(find.text('Ödül verildi'), findsNothing);
    expect(find.text('Ödül henüz doğrulanmadı'), findsOneWidget);
  });

  // ── Şampiyonluk yalnız gerçek durumda ───────────────────────────────────

  testWidgets('turnuva sürerken şampiyonluk yüzeyi çizilmez', (tester) async {
    await _pump(tester, _LocalRepo('active'));
    expect(find.byKey(const ValueKey('tournament-champion')), findsNothing);
  });

  testWidgets('elenen oyuncuya şampiyonluk gösterilmez', (tester) async {
    await _pump(tester, _LocalRepo('eliminated'));
    expect(find.byKey(const ValueKey('tournament-champion')), findsNothing);
  });

  // ── Elenme ──────────────────────────────────────────────────────────────

  testWidgets('elenen oyuncu hangi turda elendiğini görür', (tester) async {
    await _pump(tester, _LocalRepo('eliminated'));
    expect(find.text('Elendi'), findsOneWidget);
    expect(find.textContaining('turunda elendin'), findsOneWidget);
  });

  testWidgets('elenen oyuncu gerçek skorunu görür', (tester) async {
    await _pump(tester, _LocalRepo('eliminated'));
    expect(find.textContaining('Final skoru: 340'), findsWidgets);
  });

  testWidgets('sahte teselli ödülü üretilmez', (tester) async {
    await _pump(tester, _LocalRepo('eliminated'));
    // Elenme yüzeyinde hiçbir ödül jetonu olmamalı.
    expect(find.text('Ödül verildi'), findsNothing);
    expect(find.text('500'), findsNothing);
  });

  // ── Dayanıklılık ────────────────────────────────────────────────────────

  testWidgets('şampiyonluk %200 yazıda taşmaz', (tester) async {
    await _pump(
      tester,
      _LocalRepo('won'),
      size: const Size(320, 1600),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('elenme %200 yazıda taşmaz', (tester) async {
    await _pump(
      tester,
      _LocalRepo('eliminated'),
      size: const Size(320, 1600),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('karanlık temada çizim hatasız', (tester) async {
    await _pump(tester, _LocalRepo('won'), mode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPad kompozisyonunda çizim hatasız', (tester) async {
    await _pump(tester, _LocalRepo('won'), size: const Size(1194, 1400));
    expect(tester.takeException(), isNull);
  });
}
