import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_effects.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/friend_activity_label.dart';

import 'support/widget_test_helpers.dart';

/// SİMÜLATÖR TURU 1 BEKÇİLERİ (2026-10-29, Opus + GPT-6 Astra ortak bulgu).
///
/// Dört simülatörde gerçek oyunla bulunan kusurlar; her biri aşağıda kendi
/// testinde. Hepsinin sessiz kalma nedeni aynıydı: ekran turu ve eski
/// bekçiler TEK karede, tek oyunculu ya da kısa sahte veriyle bakıyordu;
/// seri üç doğrudan sonra, oda dolunca, oyuncu sonuçtan ayrılırken, yarı
/// final bitip final henüz kurulmamışken gibi ARA durumlar hiç kurulmuyordu.
///
///  * E1 — günlük/solo turda 3. doğrudan sonra "×3 Üst üste" rozeti satır
///    açıyor, soru ve şıklar ~20 pt aşağı, seri bozulunca yukarı kayıyordu;
///    "+N" uçuşu da 900 ms yer kaplıyordu.
///  * I3 — oda skor şeridinde ad yoktu (baş harf + 12 pt puan).
///  * I5 — "Çevrimdışı" iddiası: sunucuda varlık yok, `last_active_at` XP
///    ödülünde güncellenir; satır artık son oynamayı söyler.
///  * I6 — dolu 4/4 odada davet eylemleri kartı uzatıp 4. oyuncuyu ilk
///    görünümde "Yarışı başlat" perdesinin arkasına itiyordu.
///  * I7 — cevaptan önce çok oyunculuda kum saatli gri "Bir cevap seç".
///  * I8 — sırayla düello bekleme kahramanında etiketsiz "3/7".
///  * I9 — yarı finali kazanan "Finalist" yerine "Bekliyor" görünüyordu.
///  * I10 — alıştırmada "Zor / Orta / Kolay" açıklamasızdı; boşluk
///    doldurmada doğru cevap üç yerde "Rast" diyordu.
///  * I11 — seviye testinde yalnız ⏭ ikonu, geçince sessiz çıkış.
///  * I12 — cümle sıralamada gövdede "Kontrol et" + altta pasif "Bir cevap
///    seç": aynı anda iki eylem.
///
/// I1/I2 (çok oyunculu açılışta hüküm yazısı) `quiz_server_session_contract_
/// test` içinde; I4 (misafir kayıt sayfası sonucu örtmez)
/// `guest_save_prompt_result_flow_test` içinde.

QuizQuestion _q(int n) => QuizQuestion(
  id: 'tur1-$n',
  category: 'Ziman',
  prompt: 'Pirsa hejmar $n?',
  answers: const ['rast', 'şaş-a', 'şaş-b', 'şaş-c'],
  correctAnswer: 'rast',
  explanation: '',
);

void _surface(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Rect _card(WidgetTester tester) =>
    tester.getRect(find.byKey(const ValueKey('quiz-prompt-card')).first);

List<Rect> _options(WidgetTester tester) => [
  for (final e in find.byKey(const ValueKey('quiz-option-base')).evaluate())
    tester.getRect(find.byElementPredicate((x) => x == e)),
];

void _same(List<Rect> a, List<Rect> b, String why) {
  expect(b.length, a.length, reason: why);
  for (var i = 0; i < a.length; i++) {
    expect((b[i].top - a[i].top).abs(), lessThanOrEqualTo(0.5), reason: why);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
  });

  for (final size in const [Size(375, 667), Size(402, 874)]) {
    testWidgets('E1 seri 0→3→0 ve "+N" uçuşu boyunca soru ve şıklar yerinde '
        '(${size.width.toInt()}x${size.height.toInt()})', (tester) async {
      _surface(tester, size);
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: repository.createRoom(),
            questions: [for (var i = 1; i <= 5; i++) _q(i)],
            enableTimer: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card0 = _card(tester);
      final opts0 = _options(tester);

      Future<void> answer(String text) async {
        await tester.tap(find.text(text));
        // Uçuş (900 ms) sürerken de hiçbir şey kaymaz.
        await tester.pump(const Duration(milliseconds: 100));
        _same(
          [card0, ...opts0],
          [_card(tester), ..._options(tester)],
          'cevaptan hemen sonra (+N uçuşu)',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
        await tester.pumpAndSettle();
      }

      for (var i = 0; i < 3; i++) {
        await answer('rast');
      }
      // 4. soru: seri ×3, rozet görünür — ama yer değiştirmez.
      expect(find.byType(ComboBadge), findsOneWidget);
      expect(find.textContaining('×3'), findsOneWidget);
      _same(
        [card0, ...opts0],
        [_card(tester), ..._options(tester)],
        'seri ×3 rozeti açıkken',
      );
      await answer('şaş-a');
      // 5. soru: seri bozuldu, rozet kalktı — yine yerinde.
      expect(find.textContaining('×3'), findsNothing);
      _same(
        [card0, ...opts0],
        [_card(tester), ..._options(tester)],
        'seri bozulduktan sonra',
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('I3 + I7 oda şeridi adları gösterir; cevaptan önce kum saati '
      'yok', (tester) async {
    _surface(tester, const Size(375, 667));
    const room = GameRoom(
      id: 'tur1-oda',
      name: 'Oda',
      code: 'ZK-T1',
      category: 'Ziman',
      status: RoomStatus.active,
      questionCount: 2,
      players: [
        Player(name: 'Tolhildan Mawal', score: 12345, state: 'Hazır'),
        Player(name: 'Rojda', score: 99999, state: 'Hazır'),
        Player(name: 'Azad', score: 8765, state: 'Hazır'),
        Player(name: 'Dilan', score: 54321, state: 'Hazır'),
      ],
      maxPlayers: 4,
      isCustom: true,
      hostId: 'h',
    );
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: room,
          questions: [_q(1), _q(2)],
          enableTimer: false,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.takeException(), isNull);
    final strip = find.byKey(const ValueKey('quiz-crowd-top3'));
    for (final name in ['Tolhildan', 'Rojda', 'Azad', 'Dilan']) {
      expect(
        find.descendant(of: strip, matching: find.text(name)),
        findsOneWidget,
        reason: '$name şeritte yok',
      );
    }
    // Cevaptan önce hiçbir yerde bekleme ikonu (kum saati) yok: yönerge
    // ("Bir cevap seç") ya da joker dizisi; kum saati yalnız cevaptan sonra.
    expect(find.byIcon(AppIcons.hourglassStart), findsNothing);
  });

  test('I5 arkadaş durumu verinin söylediğini söyler', () {
    final now = DateTime.utc(2026, 10, 29, 12);
    Friend f(DateTime? at) => Friend(
      id: 'f',
      userId: 'u',
      friendId: 'x',
      friendName: 'Rojda',
      createdAt: DateTime.utc(2026),
      lastActiveAt: at,
    );
    expect(f(null).daysSinceActive(now), isNull);
    expect(f(now.subtract(const Duration(hours: 3))).daysSinceActive(now), 0);
    expect(f(now.subtract(const Duration(days: 3))).daysSinceActive(now), 3);
  });

  testWidgets('I5 etiket: "Çevrimdışı" yerine son oynama', (tester) async {
    late String never, days;
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) {
            never = friendActivityLabel(
              context,
              Friend(
                id: 'f',
                userId: 'u',
                friendId: 'x',
                friendName: 'R',
                createdAt: DateTime.utc(2026),
              ),
            );
            days = friendActivityLabel(
              context,
              Friend(
                id: 'f',
                userId: 'u',
                friendId: 'x',
                friendName: 'R',
                createdAt: DateTime.utc(2026),
                lastActiveAt: DateTime.now().toUtc().subtract(
                  const Duration(days: 2, hours: 1),
                ),
              ),
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(never, 'Henüz oynamadı');
    expect(days, '2 gün önce oynadı');
  });

  testWidgets('I6 dolu 4/4 oda: davet yok, 4. oyuncu ilk görünümde perdenin '
      'üstünde', (tester) async {
    _surface(tester, const Size(402, 874));
    const room = GameRoom(
      id: 'tur1-lobi',
      name: 'Grup yarışı',
      code: '526849',
      category: 'Karışık',
      status: RoomStatus.lobby,
      questionCount: 10,
      players: [
        Player(id: 'h', name: 'QaAlı', score: 0, state: 'Hazır'),
        Player(id: 'b', name: 'QaDlan', score: 0, state: 'Hazır'),
        Player(id: 'c', name: 'QaCano', score: 0, state: 'Hazır'),
        Player(id: 'd', name: 'QaBero', score: 0, state: 'Hazır'),
      ],
      maxPlayers: 4,
      isCustom: true,
      hostId: 'h',
    );
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: freshMockRepository(), initialRoom: room),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('room-invite-share')), findsNothing);
    final last = tester.getRect(find.text('QaBero'));
    expect(last.bottom, lessThanOrEqualTo(874 - 120));
  });

  testWidgets('I8 sırayla düello beklemesinde "3/7" etiketli', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: AsyncDuelResultScreen(
          repository: freshMockRepository(),
          view: AsyncDuelResultView.fromAnswer(
            AsyncDuelStart(
              duelId: 'd',
              role: AsyncDuelRole.creator,
              expiresAt: DateTime(2030),
              questions: const [],
            ),
            const AsyncDuelResult(waiting: true, myCorrect: 3, myMs: 1000),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('7 soruda 3 doğru'), findsOneWidget);
  });

  group('I9 turnuva sıralaması', () {
    TournamentMatch m(String id, String a, String b, String winner) =>
        TournamentMatch(
          id: id,
          playerOneId: a,
          playerOneName: a,
          playerTwoId: b,
          playerTwoName: b,
          playerOneScore: winner == a ? 265 : 100,
          playerTwoScore: winner == b ? 265 : 100,
          status: winner.isEmpty ? 'pending' : 'completed',
          winnerId: winner,
        );
    TournamentBracket bracket(List<TournamentRound> rounds) =>
        TournamentBracket(
          tournamentId: 't',
          userId: 'A',
          rounds: rounds,
          currentRound: rounds.length,
          status: 'active',
          totalScore: 0,
          botWinners: const [],
          createdAt: DateTime(2026),
        );
    Map<String, String> statusOf(TournamentBracket b) => {
      for (final s in tournamentStandingsFromBracket(b)) s.playerId: s.status,
    };

    test('final kurulmadan yarı final galibi finalisttir', () {
      final s = statusOf(
        bracket([
          TournamentRound(
            roundNumber: 1,
            matches: [m('1', 'A', 'B', 'B'), m('2', 'C', 'D', '')],
          ),
        ]),
      );
      expect(s['B'], 'finalist');
      expect(s['A'], 'eliminated');
      expect(s['C'], 'active');
    });

    test('final bitince şampiyon ve finalist', () {
      final s = statusOf(
        bracket([
          TournamentRound(
            roundNumber: 1,
            matches: [m('1', 'A', 'B', 'B'), m('2', 'C', 'D', 'C')],
          ),
          TournamentRound(roundNumber: 2, matches: [m('3', 'B', 'C', 'C')]),
        ]),
      );
      expect(s['C'], 'champion');
      expect(s['B'], 'finalist');
      expect(s['A'], 'eliminated');
      expect(s['D'], 'eliminated');
    });
  });

  testWidgets('I10 alıştırmada zorluk düğmelerinin sorusu yazılı', (
    tester,
  ) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: [_q(1), _q(2)],
          enableTimer: false,
          practice: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('rast'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bu soru nasıldı?'), findsOneWidget);
    expect(find.text('Orta'), findsOneWidget);
  });

  testWidgets('I11 seviye testi: yazılı "Şimdilik geç" ve geçince not', (
    tester,
  ) async {
    PlacementStore.resetInstance();
    _surface(tester, const Size(402, 874));
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      testShell(
        child: Navigator(
          key: navKey,
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('ana-sayfa')),
          ),
        ),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => LevelPlacementScreen(repository: freshMockRepository()),
      ),
    );
    await tester.pumpAndSettle();
    final skip = find.byKey(const ValueKey('placement-skip'));
    expect(skip, findsOneWidget, reason: 'yalnız ikon değil, yazılı');
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(find.text('ana-sayfa'), findsOneWidget);
    expect(
      find.text('Seviye testini sonra ana sayfadaki karttan yapabilirsin.'),
      findsOneWidget,
    );
  });

  testWidgets('I12 cümle sıralamada cevaptan önce alt perdede eylem yok', (
    tester,
  ) async {
    final repository = freshMockRepository();
    const q = QuizQuestion(
      id: 'tur1-sira',
      category: 'Ziman',
      type: QuestionType.wordOrdering,
      prompt: 'Hevokê rêz bike',
      answers: ['Ez', 'diçim', 'malê'],
      correctAnswer: 'Ez diçim malê',
      explanation: '',
    );
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [q, q],
          enableTimer: false,
          experience: QuizExperience.learning,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('quiz-next-button')), findsNothing);
    expect(find.text('Bir cevap seç'), findsNothing);
  });
}
