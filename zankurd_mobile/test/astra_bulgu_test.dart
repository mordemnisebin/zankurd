import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/widget_test_helpers.dart';

/// 2026-10-29 GPT-6 Astra denetimi (iPhone 17 Pro simülatör turu).
///
/// ## A: alt perde içeriğin sonunu örtüyor muydu?
///
/// Ekran görüntülerinde son oyuncu satırı / "Format" kartı perdenin
/// arkasında yarım görünüyordu. Gerçek neden iskelet değil: `Scaffold`
/// gövdeyi perdenin ÜSTÜNDE bitirir ve kaydırma sonunda son öğe tamamen
/// görünür. Yarım görünüm yalnız ilk karedeki kaydırma kesimiydi. Bu bekçi,
/// iskeletin sözünü sabitler: sonuna kaydırınca son öğenin alt kenarı perdenin
/// üst kenarından aşağıda KALMAZ. Perde gövdeyi örterse (ör. `extendBody`
/// tek başına, alt boşluk yok) bu test kırılır.
///
/// ## B-D: turnuva ve sonuç metinleri
///
/// Her biri niçin yanlış okunduğu testin adında/yorumunda.
class _Repo extends MockZanKurdRepository {
  _Repo({this.current, this.standings = const []});

  TournamentBracket? current;
  List<TournamentStandings> standings;

  @override
  String? get currentUserId => 'me';

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => current;

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => standings;
}

class _RoomRepo extends MockZanKurdRepository {
  _RoomRepo(this.players);
  final List<Player> players;

  @override
  String? get currentUserId => 'p0';

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => players;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(players);
}

TournamentMatch _m(
  String id,
  String a,
  String b, {
  int sa = 0,
  int sb = 0,
  String status = 'pending',
  String winner = '',
}) => TournamentMatch(
  id: id,
  playerOneId: a,
  playerOneName: a == 'me' ? 'Ben' : a.toUpperCase(),
  playerTwoId: b,
  playerTwoName: b.toUpperCase(),
  playerOneScore: sa,
  playerTwoScore: sb,
  status: status,
  winnerId: winner,
);

const _sizes = [
  (375.0, 667.0, 1.0),
  (375.0, 667.0, 1.3),
  (402.0, 874.0, 1.0),
  (402.0, 874.0, 1.3),
];

Future<void> _setView(WidgetTester tester, double w, double h) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(w, h);
  addTearDown(tester.view.reset);
}

Widget _scaled(double scale, Widget child) => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child,
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
  });

  for (final (w, h, scale) in _sizes) {
    testWidgets('A: turnuva katılım ekranı sonuna kaydırınca perdenin üstünde '
        '($w×$h, x$scale)', (tester) async {
      await _setView(tester, w, h);
      await tester.pumpWidget(
        testShell(child: _scaled(scale, TournamentScreen(repository: _Repo()))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final cta = find.byKey(const ValueKey('tournament-primary-cta'));
      expect(cta, findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump(const Duration(milliseconds: 600));
      final dockTop = tester.getRect(cta).top;
      final last = find.byKey(const ValueKey('tournament-rules-panel'));
      expect(last, findsOneWidget);
      expect(
        tester.getRect(last).bottom,
        lessThanOrEqualTo(dockTop),
        reason: 'son kart perdenin arkasında kaldı',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('A: oda lobisi sonuna kaydırınca son oyuncu perdenin üstünde '
        '($w×$h, x$scale)', (tester) async {
      await _setView(tester, w, h);
      final players = [
        for (var i = 0; i < 6; i++)
          Player(
            id: 'p$i',
            name: 'Oyuncu$i',
            score: 0,
            state: 'Hazır',
            streak: 0,
          ),
      ];
      final repo = _RoomRepo(players);
      await tester.pumpWidget(
        testShell(
          child: _scaled(
            scale,
            RoomScreen(
              repository: repo,
              initialRoom: GameRoom(
                id: 'room-dock',
                name: 'Grup yarışı',
                code: '325657',
                category: 'Karışık',
                players: players,
                status: RoomStatus.lobby,
                questionCount: 10,
                hostId: 'p0',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
      await tester.pump(const Duration(milliseconds: 600));
      final lastRow = find.byKey(const ValueKey('room-player-tile-6'));
      expect(lastRow, findsOneWidget);
      // Perde `bottomNavigationBar` yuvasındadır: gövde onun üstünde biter.
      final startButton = find.text('Yarışı başlat');
      expect(startButton, findsOneWidget);
      expect(
        tester.getRect(lastRow).bottom,
        lessThanOrEqualTo(tester.getRect(startButton).top),
        reason: 'son oyuncu satırı perdenin arkasında kaldı',
      );
    });
  }

  for (final (w, scale) in [(320.0, 2.0), (402.0, 1.3)]) {
    testWidgets('A: turnuva lobisi taşmaz ($w, x$scale)', (tester) async {
      await _setView(tester, w, 700);
      await tester.pumpWidget(
        testShell(child: _scaled(scale, TournamentScreen(repository: _Repo()))),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('B: katılmadan şemada "Sen" yok, önizleme olduğu yazılı; '
      'başlama kuralı en az 2 oyuncuyu söyler', (tester) async {
    await _setView(tester, 402, 874);
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: _Repo())),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final preview = find.byKey(const ValueKey('tournament-bracket-preview'));
    expect(preview, findsOneWidget);
    expect(
      find.descendant(of: preview, matching: find.text('Sen')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('tournament-ladder-preview-note')),
      findsOneWidget,
    );
    expect(find.textContaining('en az 2 oyuncuyla'), findsWidgets);
  });

  testWidgets('B: bekleme ekranı kalan süreyi, "Yenile"yi ve antrenmanın '
      'kaydı koruduğunu söyler', (tester) async {
    await _setView(tester, 402, 874);
    final opened = DateTime.now().subtract(const Duration(hours: 4));
    final repo = _Repo(
      current: TournamentBracket(
        tournamentId: 't',
        userId: 'me',
        size: 4,
        entryCount: 2,
        rounds: const [],
        createdAt: opened,
      ),
    );
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repo)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('Başlamasına 19 sa'), findsOneWidget);
    final refresh = find.byKey(const ValueKey('tournament-waiting-refresh'));
    expect(
      find.descendant(of: refresh, matching: find.text('Yenile')),
      findsOneWidget,
    );
    expect(find.text('Tekrar dene'), findsNothing);
    expect(
      find.byKey(const ValueKey('tournament-practice-note')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('C: sıralama durum etiketi ve ölçüt taşır; elenen kart skor ve '
      'rakibi, kazanan kart sıradaki adımı yazar', (tester) async {
    await _setView(tester, 402, 1800);
    final eliminated = TournamentBracket(
      tournamentId: 't',
      userId: 'me',
      size: 4,
      entryCount: 4,
      status: 'eliminated',
      rounds: [
        TournamentRound(
          roundNumber: 1,
          status: 'completed',
          matches: [
            _m(
              'm1',
              'me',
              'qali',
              sa: 100,
              sb: 640,
              status: 'completed',
              winner: 'qali',
            ),
            _m(
              'm2',
              'qabero',
              'qacano',
              sa: 265,
              sb: 122,
              status: 'completed',
              winner: 'qabero',
            ),
          ],
        ),
      ],
      createdAt: DateTime(2026, 10, 29),
    );
    final standings = [
      const TournamentStandings(
        rank: 1,
        playerId: 'qali',
        playerName: 'QALI',
        totalScore: 640,
        status: 'active',
      ),
      const TournamentStandings(
        rank: 2,
        playerId: 'qabero',
        playerName: 'QABERO',
        totalScore: 265,
        status: 'active',
      ),
      const TournamentStandings(
        rank: 3,
        playerId: 'qacano',
        playerName: 'QACANO',
        totalScore: 122,
        status: 'eliminated',
      ),
    ];
    await tester.pumpWidget(
      testShell(
        child: TournamentScreen(
          repository: _Repo(current: eliminated, standings: standings),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('tournament-standings-note')),
      findsOneWidget,
    );
    expect(find.text('Bekliyor'), findsNWidgets(2));
    expect(find.text('Elendi'), findsWidgets);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('tournament-eliminated-vs')))
          .data,
      'QALI karşısında 100 – 640',
    );
    expect(find.text('Tur 1/2'), findsOneWidget);
    expect(find.text('1/2'), findsNothing);
  });

  testWidgets('C: yarı finali kazanan üstte sonuç ve sıradaki adımı görür', (
    tester,
  ) async {
    await _setView(tester, 402, 1800);
    final won = TournamentBracket(
      tournamentId: 't',
      userId: 'me',
      size: 4,
      entryCount: 4,
      rounds: [
        TournamentRound(
          roundNumber: 1,
          status: 'completed',
          matches: [
            _m(
              'm1',
              'me',
              'qali',
              sa: 640,
              sb: 100,
              status: 'completed',
              winner: 'me',
            ),
            _m('m2', 'qabero', 'qacano', sa: 265, sb: 122, status: 'active'),
          ],
        ),
      ],
      createdAt: DateTime(2026, 10, 29),
    );
    await tester.pumpWidget(
      testShell(
        child: TournamentScreen(repository: _Repo(current: won)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final card = find.byKey(const ValueKey('tournament-match-won'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.textContaining('640 – 100')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.textContaining('açılır')),
      findsOneWidget,
    );
  });

  testWidgets('bekçi: kurulmamış Final kartı dokunulamaz ve buton değil', (
    tester,
  ) async {
    await _setView(tester, 402, 1800);
    var taps = 0;
    final bracket = TournamentBracket(
      tournamentId: 't',
      userId: 'me',
      size: 4,
      entryCount: 4,
      rounds: [
        TournamentRound(
          roundNumber: 1,
          status: 'active',
          matches: [
            _m('m1', 'me', 'qali', status: 'active'),
            _m('m2', 'qabero', 'qacano', status: 'active'),
          ],
        ),
      ],
      createdAt: DateTime(2026, 10, 29),
    );
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SingleChildScrollView(
            child: TournamentBracketWidget(
              bracket: bracket,
              userId: 'me',
              ku: false,
              onTapMatch: (_, _) => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final cards = find.byType(GestureDetector);
    // Son kart: boş Final.
    await tester.tap(cards.last, warnIfMissed: false);
    expect(taps, 0);
    // Gerçek (oyunculu) kart hâlâ dokunulur.
    await tester.tap(find.text('Ben'));
    expect(taps, 1);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('bekçi: kısa ekranda dört sayım çipi okunur boyutta kalır '
        '(x$scale)', (tester) async {
      await _setView(tester, 375, 667);
      await tester.pumpWidget(
        testShell(
          child: _scaled(
            scale,
            const Scaffold(
              body: SahneResultStats(
                compact: true,
                oneRow: true,
                stats: [
                  SahneResultStat(
                    leading: Icon(Icons.check),
                    value: 4,
                    label: 'Doğru',
                    showWhenZero: true,
                    tint: Colors.green,
                  ),
                  SahneResultStat(
                    leading: Icon(Icons.close),
                    value: 6,
                    label: 'Yanlış',
                    showWhenZero: true,
                    tint: Colors.red,
                  ),
                  SahneResultStat(
                    leading: Icon(Icons.hourglass_empty),
                    value: 1,
                    label: 'Boş',
                    tint: Colors.grey,
                  ),
                  SahneResultStat(
                    leading: Icon(Icons.local_fire_department),
                    value: 2,
                    label: 'En uzun seri',
                    tint: Colors.amber,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Tek satır düzeninde seri çipi (en az önemli) düşebilir; ızgarada
      // dördü de var. Görünen her etiket ekranın içinde ve en az 12 punto.
      for (final label in ['Doğru', 'Yanlış', 'Boş', 'En uzun seri']) {
        final f = find.text(label);
        if (f.evaluate().isEmpty) {
          expect(label, 'En uzun seri', reason: 'yalnız seri çipi düşebilir');
          continue;
        }
        expect(tester.getRect(f).right, lessThanOrEqualTo(375), reason: label);
        final style = tester.widget<Text>(f).style;
        expect(
          (style?.fontSize ?? 14) * scale,
          greaterThanOrEqualTo(12),
          reason: '$label okunmaz küçüklükte',
        );
      }
    });
  }
}
