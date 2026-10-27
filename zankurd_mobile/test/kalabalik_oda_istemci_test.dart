// 2026-10-19 sadeleşme (ikinci tur): "Hazırım" anahtarı ayrı kart (SwitchListTile) değil yerel oyuncunun KENDİ satırındaki Switch (anahtar room-ready-switch).
// Kalabalık oda (2–50 kişi) istemci sözleşmesi.
//
// Sunucu 2026-10-16 göçüyle özel odayı kalabalığa açtı; istemci her yerde
// "tam iki oyuncu" varsayıyordu. Bu dosya kalabalığa özgü davranışı tek yerde
// kilitler ve 1v1 yolunun DEĞİŞMEDİĞİNİ aynı kurulumla karşılaştırır:
//
//   * sıralama: eşit skor aynı sırayı paylaşır, ayrılan sıralamaya girmez,
//   * lobi: host >= 2 aktif oyuncuyla başlatır (hazır şartı yok), host
//     devrinde rozet ve başlat düğmesi yeni host'a geçer,
//   * oyun: cevap başına yayın YOK (N oyuncuda N² mesaj), başlık sıra ve
//     ilk üçü taşır, seyrek yoklama, düşen oyuncu bilgilendirilip çıkarılır,
//   * sonuç: sunucunun sıralı yükü; ilk üç madalyalı, ayrılanlar en sonda.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/services/crowd_standings.dart';
import 'package:zankurd_mobile/src/services/room_result_presentation.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';

import 'support/widget_test_helpers.dart';

Player _p(
  String id,
  String name, {
  int score = 0,
  bool left = false,
  int streak = 0,
  int? rank,
  String state = Player.readyState,
  String? tag,
}) => Player(
  id: id,
  name: name,
  score: score,
  streak: streak,
  state: state,
  left: left,
  rank: rank,
  tag: tag,
);

GameRoom _crowdRoom({
  List<Player> players = const [],
  String hostId = 'host-user',
  RoomStatus status = RoomStatus.lobby,
  int maxPlayers = 8,
}) => GameRoom(
  id: 'crowd-room',
  name: 'crowd',
  code: 'ZK-ABCDEF0123',
  category: 'Ziman',
  players: players,
  status: status,
  questionCount: 2,
  secondsPerQuestion: 30,
  hostId: hostId,
  maxPlayers: maxPlayers,
  isCustom: true,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  group('GameRoom.isCrowd', () {
    test('yalnız özel oda ve kapasite > 2 kalabalıktır', () {
      expect(_crowdRoom().isCrowd, isTrue);
      expect(_crowdRoom(maxPlayers: 2).isCrowd, isFalse);
      // Hızlı eşleşme odası: özel değil, kapasite 2.
      expect(_crowdRoom().copyWith(isCustom: false).isCrowd, isFalse);
      // Varsayılan GameRoom eski 1v1 odasıdır.
      expect(
        const GameRoom(
          name: 'x',
          code: 'ZK-X',
          category: 'Ziman',
          players: [],
          status: RoomStatus.lobby,
        ).isCrowd,
        isFalse,
      );
    });

    test('izinli kapasiteler sunucudakiyle aynı kümedir', () {
      expect(GameRoom.allowedMaxPlayers, [2, 4, 8, 16, 30, 50]);
      expect(
        GameRoom.allowedMaxPlayers,
        contains(GameRoom.defaultCrowdCapacity),
      );
    });
  });

  group('crowdStandings', () {
    test('eşit skor aynı sırayı paylaşır (1, 1, 3)', () {
      final standings = crowdStandings([
        _p('a', 'A', score: 100),
        _p('b', 'B', score: 300),
        _p('c', 'C', score: 300),
      ]);

      expect(standings.map((s) => s.player.id), ['b', 'c', 'a']);
      expect(standings.map((s) => s.rank), [1, 1, 3]);
    });

    test('ayrılan oyuncu sıralamaya girmez ve kimseyi geride bırakmaz', () {
      final standings = crowdStandings([
        _p('a', 'A', score: 100),
        _p('gone', 'Gitti', score: 900, left: true),
        _p('b', 'B', score: 50),
      ]);

      expect(standings.map((s) => s.player.id), ['a', 'b']);
      expect(standings.map((s) => s.rank), [1, 2]);
    });

    test('eşitlikte giriş sırası korunur (kararlı)', () {
      final standings = crowdStandings([
        for (var i = 0; i < 12; i++) _p('p$i', 'P$i', score: 10),
      ]);

      expect(standings.map((s) => s.player.id), [
        for (var i = 0; i < 12; i++) 'p$i',
      ]);
      expect(standings.every((s) => s.rank == 1), isTrue);
    });
  });

  group('sonuç teslim doğrulaması', () {
    RoomResultSnapshot crowdSnapshot({
      required List<Player> players,
      int maxPlayers = 8,
      List<ResumedAnswer> answers = const [],
    }) => RoomResultSnapshot(
      room: _crowdRoom(
        players: players,
        status: RoomStatus.finished,
        maxPlayers: maxPlayers,
      ),
      ownPlayerId: 'me',
      questionIds: const ['q1', 'q2'],
      answers: answers,
      winnerId: null,
      endedReason: 'completed',
      forfeitedBy: null,
      finishedAt: DateTime.utc(2026, 10, 16),
    );

    test('kalabalıkta 2..kapasite ayrı oyuncu kabul edilir', () {
      final players = [
        _p('me', 'Ez', score: 10, rank: 1),
        for (var i = 0; i < 5; i++) _p('o$i', 'O$i', score: 5, rank: 2),
      ];
      final snapshot = crowdSnapshot(players: players);

      expect(roomResultHasValidPlayers(snapshot, 'me'), isTrue);
      expect(
        () => validateRoomResultDeliveryContext(
          snapshot,
          expectedUserId: 'me',
          expectedRoomId: 'crowd-room',
        ),
        returnsNormally,
      );
    });

    test('kapasiteyi aşan, tekrarlı ya da sahipsiz liste reddedilir', () {
      expect(
        roomResultHasValidPlayers(
          crowdSnapshot(
            maxPlayers: 4,
            players: [
              for (var i = 0; i < 5; i++) _p(i == 0 ? 'me' : 'o$i', 'X'),
            ],
          ),
          'me',
        ),
        isFalse,
      );
      expect(
        roomResultHasValidPlayers(
          crowdSnapshot(players: [_p('me', 'A'), _p('me', 'B')]),
          'me',
        ),
        isFalse,
      );
      expect(
        roomResultHasValidPlayers(
          crowdSnapshot(players: [_p('x', 'A'), _p('y', 'B')]),
          'me',
        ),
        isFalse,
      );
    });

    test('1v1 sonucu hâlâ TAM iki oyuncu ister', () {
      final base = crowdSnapshot(players: [_p('me', 'A'), _p('o', 'B')]);
      final legacy = RoomResultSnapshot(
        room: base.room.copyWith(
          maxPlayers: 2,
          isCustom: false,
          players: [_p('me', 'A'), _p('o', 'B'), _p('t', 'C')],
        ),
        ownPlayerId: 'me',
        questionIds: base.questionIds,
        answers: base.answers,
        winnerId: null,
        endedReason: 'completed',
        forfeitedBy: null,
        finishedAt: base.finishedAt,
      );

      expect(roomResultHasValidPlayers(legacy, 'me'), isFalse);
    });
  });

  group('lobi', () {
    Future<void> mountLobby(
      WidgetTester tester,
      _LobbyRepo repository, {
      GameRoom? room,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: room ?? repository.room(),
          ),
        ),
      );
      await tester.pump();
    }

    Finder startButton() =>
        find.widgetWithText(GeometricGradientButton, 'Yarışı başlat');

    testWidgets('host iki oyuncuyla, kimse hazır olmadan başlatabilir', (
      tester,
    ) async {
      final repository = _LobbyRepo(
        me: 'host-user',
        players: [
          _p('host-user', 'Mêvandar'),
          _p('guest-1', 'Rojda', state: 'Bekliyor'),
        ],
      );
      await mountLobby(tester, repository);

      final button = tester.widget<GeometricGradientButton>(startButton());
      expect(button.onPressed, isNotNull);
      // "Hazırım" anahtarı kalabalık odada yoktur.
      expect(find.text('Hazırım'), findsNothing);
      expect(find.byKey(const ValueKey("room-ready-switch")), findsNothing);
      // x/max sayacı.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('room-player-count')),
          matching: find.text('2/8'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('room-crowd-start-hint')),
        findsOneWidget,
      );
    });

    testWidgets('host tek başına başlatamaz', (tester) async {
      final repository = _LobbyRepo(
        me: 'host-user',
        players: [_p('host-user', 'Mêvandar')],
      );
      await mountLobby(tester, repository);

      final button = tester.widget<GeometricGradientButton>(startButton());
      expect(button.onPressed, isNull);
      expect(
        find.text('Yarışı başlatmak için en az 2 oyuncu olmalı.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('room-crowd-start-hint')), findsNothing);
    });

    testWidgets('başlatınca kalabalık oda 1v1 yoluna girmez', (tester) async {
      final repository = _LobbyRepo(
        me: 'host-user',
        players: [
          _p('host-user', 'Mêvandar'),
          _p('guest-1', 'Rojda', state: 'Bekliyor'),
        ],
      );
      await mountLobby(tester, repository);

      await tester.tap(startButton());
      await tester.pumpAndSettle();

      expect(repository.startCalls, 1);
      final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
      // İki oyuncu bile olsa: 1v1 düello başlığı değil kalabalık yolu.
      expect(quiz.is1v1, isFalse);
      expect(quiz.room.isCrowd, isTrue);
    });

    testWidgets('misafir başlatamaz; "sahip başlatınca başlar" okur', (
      tester,
    ) async {
      final repository = _LobbyRepo(
        me: 'guest-1',
        players: [_p('host-user', 'Mêvandar'), _p('guest-1', 'Rojda')],
      );
      await mountLobby(tester, repository);

      expect(startButton(), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('room-waiting-host')))
            .data,
        'Oda sahibi başlatınca yarış başlar.',
      );
    });

    testWidgets('lobi başlığı kalabalık odayı tanıtır, oda kodu görünür', (
      tester,
    ) async {
      final repository = _LobbyRepo(
        me: 'host-user',
        players: [_p('host-user', 'Mêvandar')],
      );
      await mountLobby(tester, repository);

      expect(find.text('Grup yarışı'), findsOneWidget);
      expect(find.text('1vs1'), findsNothing);
      expect(find.byKey(const ValueKey('room-code')), findsOneWidget);
      expect(find.byKey(const ValueKey('room-invite-share')), findsOneWidget);
    });

    testWidgets('lobide katılış sırası korunur, puana göre karışmaz', (
      tester,
    ) async {
      final repository = _LobbyRepo(
        me: 'host-user',
        players: [
          _p('host-user', 'Mêvandar'),
          _p('g1', 'Zeynep'),
          _p('g2', 'Ahmet'),
        ],
      );
      await mountLobby(tester, repository);

      for (final (i, name) in ['Mêvandar', 'Zeynep', 'Ahmet'].indexed) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('room-player-tile-${i + 1}')),
            matching: find.text(name),
          ),
          findsOneWidget,
          reason: '${i + 1}. satır $name olmalı',
        );
      }
    });

    testWidgets(
      'host ayrılınca yeni host başlat düğmesini ve bildirimi görür',
      (tester) async {
        final repository = _LobbyRepo(
          me: 'guest-1',
          players: [_p('host-user', 'Mêvandar'), _p('guest-1', 'Rojda')],
        );
        await mountLobby(tester, repository);
        expect(startButton(), findsNothing);

        // Sunucu host'u devretti: eski host'un satırı silindi.
        repository
          ..snapshotHostId = 'guest-1'
          ..players = [_p('guest-1', 'Rojda')];
        repository.playersController.add(repository.players);
        await tester.pump();
        await tester.pump();

        expect(repository.snapshotLoads, 1);
        expect(startButton(), findsOneWidget);
        expect(
          find.text('Oda sahibi ayrıldı; artık oda sahibi sensin.'),
          findsOne,
        );
      },
    );

    testWidgets('host satırı listede durdukça oda yeniden okunmaz', (
      tester,
    ) async {
      final repository = _LobbyRepo(
        me: 'guest-1',
        players: [_p('host-user', 'Mêvandar'), _p('guest-1', 'Rojda')],
      );
      await mountLobby(tester, repository);

      repository.playersController.add([
        _p('host-user', 'Mêvandar'),
        _p('guest-1', 'Rojda'),
        _p('guest-2', 'Azad'),
      ]);
      await tester.pump();
      await tester.pump();

      expect(repository.snapshotLoads, 0);
    });

    testWidgets('2 kişilik özel oda eski lobiyle aynı: hazır anahtarı var', (
      tester,
    ) async {
      final repository = _LobbyRepo(
        me: 'host-user',
        players: [_p('host-user', 'Mêvandar'), _p('guest-1', 'Rojda')],
      );
      await mountLobby(
        tester,
        repository,
        room: repository.room().copyWith(maxPlayers: 2, name: '1vs1'),
      );

      expect(find.text('Hazırım'), findsOneWidget);
      expect(find.byKey(const ValueKey("room-ready-switch")), findsOneWidget);
      expect(find.text('1vs1'), findsOneWidget);
      // Sayaç "2" — kapasite yalnız kalabalık odada yazılır.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('room-player-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
    });
  });

  group('oyun içi', () {
    final questions = <QuizQuestion>[
      const QuizQuestion(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Pirs 1',
        answers: ['A1', 'B1', 'C1', 'D1'],
        correctAnswer: '',
        explanation: '',
      ),
      const QuizQuestion(
        id: 'q2',
        category: 'Ziman',
        prompt: 'Pirs 2',
        answers: ['A2', 'B2', 'C2', 'D2'],
        correctAnswer: '',
        explanation: '',
      ),
    ];

    final standingsPlayers = [
      _p('me', 'Ez', score: 300),
      _p('a', 'Ayşe', score: 500),
      _p('b', 'Berat', score: 300),
      _p('c', 'Ceren', score: 100),
      _p('gone', 'Gitti', score: 900, left: true),
    ];

    Future<void> pumpFrames(WidgetTester tester, [int count = 4]) async {
      for (var i = 0; i < count; i++) {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
      }
    }

    Future<_QuizRepo> mount(
      WidgetTester tester, {
      GameRoom? room,
      bool is1v1 = false,
      List<Player>? players,
      Object? markError,
      bool resumed = true,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final theRoom =
          room ??
          _crowdRoom(
            players: players ?? standingsPlayers,
            status: RoomStatus.active,
          );
      final repository = _QuizRepo(
        players: players ?? theRoom.players,
        room: theRoom,
      )..markError = markError;
      addTearDown(repository.close);
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repository,
            room: theRoom,
            questions: questions,
            is1v1: is1v1,
            resumeSnapshot: resumed ? repository.snapshot : null,
          ),
        ),
      );
      await pumpFrames(tester);
      return repository;
    }

    testWidgets('başlık kendi puanını, sırasını ve ilk üçü gösterir', (
      tester,
    ) async {
      await mount(tester);

      expect(find.byKey(const ValueKey('quiz-crowd-header')), findsOneWidget);
      // Ayşe 500 → 1; Ez ve Berat 300 → ortak 2; Ceren 100 → 4. Ayrılan
      // (900 puanlı) sıralamaya ve toplama girmez: 4 oyuncu.
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('quiz-crowd-rank'))).data,
        '#2/4',
      );
      final top = find.byKey(const ValueKey('quiz-crowd-top3'));
      expect(
        find.descendant(of: top, matching: find.text('Ayşe')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: top, matching: find.text('Gitti')),
        findsNothing,
      );
      expect(find.text('300 puan'), findsOneWidget);
      // Düello kartı ve dört satırlık canlı tablo kalabalıkta yoktur.
      expect(find.text('VS'), findsNothing);
    });

    testWidgets('skor akışı sırayı canlı günceller', (tester) async {
      final repository = await mount(tester);

      repository.playersController.add([
        _p('me', 'Ez', score: 700),
        _p('a', 'Ayşe', score: 500),
        _p('b', 'Berat', score: 300),
        _p('c', 'Ceren', score: 100),
      ]);
      await pumpFrames(tester);

      expect(
        tester.widget<Text>(find.byKey(const ValueKey('quiz-crowd-rank'))).data,
        '#1/4',
      );
    });

    testWidgets('cevap verince kalabalıkta hiçbir yayın gitmez', (
      tester,
    ) async {
      final repository = await mount(tester);

      await tester.tap(find.text('B1').first);
      await pumpFrames(tester);

      expect(repository.submitCalls, 1);
      // N oyuncuda cevap başına yayın N² mesaj demek: ne cevaplandı bilgisi,
      // ne hazır sinyali, ne seçilen şık.
      expect(
        repository.sent.where(
          (p) =>
              p.containsKey('answered') ||
              p.containsKey('ready') ||
              p.containsKey('selected_answer'),
        ),
        isEmpty,
      );
      expect(find.text('Diğer oyuncular bekleniyor…'), findsOneWidget);
    });

    testWidgets('kontrol: 1v1 odasında aynı cevap hâlâ yayınlanır', (
      tester,
    ) async {
      final room = _crowdRoom(
        players: [_p('me', 'Ez'), _p('a', 'Ayşe')],
        status: RoomStatus.active,
        maxPlayers: 2,
      );
      final repository = await mount(tester, room: room, is1v1: true);

      await tester.tap(find.text('B1').first);
      await pumpFrames(tester);

      expect(
        repository.sent.any((p) => p['answered'] == true),
        isTrue,
        reason: '1v1 yolu bugünkü gibi cevap yayınlar',
      );
      expect(find.byKey(const ValueKey('quiz-crowd-header')), findsNothing);
    });

    testWidgets('yedek yoklama kalabalıkta 6 sn, 1v1 odasında 4 sn', (
      tester,
    ) async {
      final crowd = await mount(tester);
      final base = crowd.resumeCalls;
      await tester.pump(const Duration(milliseconds: 4500));
      expect(
        crowd.resumeCalls,
        base,
        reason: 'kalabalıkta 4,5 sn içinde yoklama olmamalı',
      );
      await tester.pump(const Duration(milliseconds: 2000));
      expect(crowd.resumeCalls, greaterThan(base));

      // Ekranı sök: ilk testin zamanlayıcıları ikincisini etkilemesin.
      await tester.pumpWidget(const SizedBox());
      final room = _crowdRoom(
        players: [_p('me', 'Ez'), _p('a', 'Ayşe')],
        status: RoomStatus.active,
        maxPlayers: 2,
      );
      final duel = await mount(tester, room: room, is1v1: true);
      final duelBase = duel.resumeCalls;
      await tester.pump(const Duration(milliseconds: 4500));
      expect(duel.resumeCalls, greaterThan(duelBase));
    });

    testWidgets('cevapladıktan sonra skor akışı gelirse açıklama aranır', (
      tester,
    ) async {
      final repository = await mount(tester);
      await tester.tap(find.text('B1').first);
      await pumpFrames(tester);
      final before = repository.resumeCalls;

      // Skorlar yalnız soru AÇIKLANINCA yazılır: cevabını vermiş oyuncu için
      // `room_players` değişimi "açıklandı" işaretidir.
      repository.playersController.add([
        _p('me', 'Ez', score: 400),
        _p('a', 'Ayşe', score: 600),
        _p('b', 'Berat', score: 300),
        _p('c', 'Ceren', score: 100),
      ]);
      await tester.pump(const Duration(milliseconds: 800));
      await pumpFrames(tester);

      expect(repository.resumeCalls, greaterThan(before));
    });

    testWidgets('cevap sayısı "x/N cevapladı" olarak başlıkta ve beklemede', (
      tester,
    ) async {
      final repository = await mount(tester);
      repository.answerProgress = const RoomAnswerProgress(
        questionIndex: 0,
        answered: 3,
        active: 4,
      );

      await tester.tap(find.text('B1').first);
      await pumpFrames(tester);

      // Cevaptan hemen sonra sorulur (6 sn yoklamayı beklemeden).
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('quiz-crowd-progress')))
            .data,
        '3/4 cevapladı',
      );
      // Bekleme kartı da aynı sayıyı söyler; genel metin kalkar.
      expect(find.text('3/4 cevapladı'), findsNWidgets(2));
      expect(find.text('Diğer oyuncular bekleniyor…'), findsNothing);
    });

    testWidgets('sayı yoklamayla güncellenir (6 sn)', (tester) async {
      final repository = await mount(tester);
      repository.answerProgress = const RoomAnswerProgress(
        questionIndex: 0,
        answered: 1,
        active: 4,
      );
      await tester.pump(const Duration(milliseconds: 6500));
      await pumpFrames(tester);
      expect(find.text('1/4 cevapladı'), findsOneWidget);

      repository.answerProgress = const RoomAnswerProgress(
        questionIndex: 0,
        answered: 2,
        active: 4,
      );
      await tester.pump(const Duration(milliseconds: 6500));
      await pumpFrames(tester);
      expect(find.text('2/4 cevapladı'), findsOneWidget);
    });

    testWidgets('başka soruya ait sayı yok sayılır, bekleme metni kalır', (
      tester,
    ) async {
      final repository = await mount(tester);
      repository.answerProgress = const RoomAnswerProgress(
        questionIndex: 5,
        answered: 3,
        active: 4,
      );

      await tester.tap(find.text('B1').first);
      await pumpFrames(tester);

      expect(find.byKey(const ValueKey('quiz-crowd-progress')), findsNothing);
      expect(find.text('Diğer oyuncular bekleniyor…'), findsOneWidget);
    });

    testWidgets('sunucuda RPC yoksa bugünkü bekleme metni gösterilir', (
      tester,
    ) async {
      final repository = await mount(tester);
      expect(repository.answerProgress, isNull);

      await tester.tap(find.text('B1').first);
      await pumpFrames(tester);

      expect(find.byKey(const ValueKey('quiz-crowd-progress')), findsNothing);
      expect(find.text('Diğer oyuncular bekleniyor…'), findsOneWidget);
    });

    testWidgets('hazır süresi dolup düşen oyuncu bilgilendirilir', (
      tester,
    ) async {
      final repository = await mount(
        tester,
        markError: const RoomMemberLeftException(),
        resumed: false,
      );
      await pumpFrames(tester, 6);

      expect(repository.markCalls, 1, reason: 'düşen oyuncu yeniden denemez');
      expect(
        find.text(
          'Zamanında hazır olmadığın için yarıştan çıkarıldın. '
          'Yarış diğer oyuncularla devam ediyor.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('oyuncu satırı left_at ile düşerse çıkarılır', (tester) async {
      final repository = await mount(tester);

      repository.playersController.add([
        _p('me', 'Ez', left: true),
        _p('a', 'Ayşe', score: 500),
        _p('b', 'Berat', score: 300),
      ]);
      await pumpFrames(tester, 6);

      expect(find.text('Yarıştan çıkarıldın'), findsNothing);
      expect(
        find.textContaining('Zamanında hazır olmadığın için'),
        findsOneWidget,
      );
    });

    testWidgets('çıkış penceresi "oyun sürer" der ve sonuç akışı başlatmaz', (
      tester,
    ) async {
      final repository = await mount(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(
        find.text(
          'Ayrılırsan yarış diğer oyuncularla devam eder; geri dönemezsin '
          've sıralamaya girmezsin.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Maçtan ayrılırsan hükmen yenilmiş sayılırsın.'),
        findsNothing,
      );

      await tester.tap(find.text('Çık'));
      await pumpFrames(tester, 6);

      expect(repository.leaveCalls, 1);
      // Kalan aktif < 2 olup oda "completed" bitse de ayrılana sonuç
      // sunulmaz (sunucu yalnız aktif üyelere verir); sonuç yolu açılmaz.
      expect(repository.finishCalls, 0);
      expect(repository.resultCalls, 0);
    });

    // 2026-10-22 iki simülatör turu: kendi isteğiyle çıkan oyuncunun
    // `left_at` satırı ekran kapanırken realtime ile geliyordu; çıkış
    // bayrağı `finally`'de sıfırlandığı için ana ekranda "Zamanında hazır
    // olmadığın için çıkarıldın" penceresi açılıyordu.
    testWidgets('kendi isteğiyle çıkan "düşürüldün" penceresi görmez', (
      tester,
    ) async {
      final repository = await mount(tester);

      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.tap(find.text('Çık'));
      await tester.pump();
      repository.playersController.add([
        _p('me', 'Ez', left: true),
        _p('a', 'Ayşe', score: 500),
        _p('b', 'Berat', score: 300),
      ]);
      await pumpFrames(tester, 6);

      expect(repository.leaveCalls, 1);
      expect(
        find.textContaining('Zamanında hazır olmadığın için'),
        findsNothing,
      );
    });
  });

  group('sonuç ekranı', () {
    Future<void> mountResult(
      WidgetTester tester, {
      required List<Player> players,
      String ownId = 'me',
      bool ku = false,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : null,
          child: QuizResultScreen(
            repository: repository,
            room: _crowdRoom(players: players, status: RoomStatus.finished),
            score: players.firstWhere((p) => p.id == ownId).score,
            correctCount: 1,
            wrongCount: 1,
            totalQuestions: 2,
            bestStreak: 1,
            coinsAwarded: 0,
            answerRecords: const [],
            opponents: players.where((p) => p.id != ownId).toList(),
            resultOwnerUserId: ownId,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    final players = [
      _p('me', 'Ez', score: 250, rank: 1),
      _p('guest', 'Rojda', score: 250, rank: 1),
      _p('third', 'Azad', score: 100, rank: 3),
      _p('fourth', 'Berfîn', score: 40, rank: 4),
      _p('gone', 'Şêro', score: 400, left: true),
    ];

    testWidgets('eşit birincilik, ilk üç madalya, ayrılan en sonda', (
      tester,
    ) async {
      await mountResult(tester, players: players);

      expect(find.text('Kazandın!'), findsOneWidget);
      // 2026-10-27: birincilik paylaşılıyorsa bu söylenir.
      expect(
        find.text('4 oyuncu arasında 1. sırayı 2 kişi paylaştınız.'),
        findsOneWidget,
      );
      // Eşit skor → ikisi de 1.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crowd-standing-me-1')),
          matching: find.text('1'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crowd-standing-guest')),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crowd-standing-third')),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      // Madalya yalnız ilk üçte (1, 1, 3); 4. sırada yok.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crowd-standing-fourth')),
          matching: find.byIcon(AppIcons.medal),
        ),
        findsNothing,
      );
      expect(find.byIcon(AppIcons.medal), findsNWidgets(3));

      // Ayrılan listenin sonunda, sıra yerine tire ve "Ayrıldı" ile.
      final left = find.byKey(const ValueKey('crowd-left-gone'));
      expect(left, findsOneWidget);
      expect(
        find.descendant(of: left, matching: find.text('Ayrıldı')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: left, matching: find.text('–')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(left).dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('crowd-standing-fourth')))
              .dy,
        ),
      );
      // Düello dili yok.
      expect(find.text('Kaybettin…'), findsNothing);
      expect(find.text('Berabere!'), findsNothing);
    });

    // Simülatör denemesi (2026-10-16): herkes 0 puanla berabere bitince ev
    // sahibi "Kazandın!" görüyordu. Tam beraberlik beraberliktir.
    // 2026-10-22: adsız ve ayrılmış oyuncu da sonuç listesinde lobideki
    // gibi "Oyuncu ZK-XXXX" görünür (kod sonuç yükünde yok, profilden gelir).
    testWidgets('ayrılan adsız oyuncu kodla görünür', (tester) async {
      await mountResult(
        tester,
        players: [
          _p('me', 'Ez', score: 250, rank: 1),
          _p('guest', 'Rojda', score: 100, rank: 2),
          _p('gone', '', score: 50, left: true, tag: 'R5C4'),
        ],
      );
      expect(find.text('Oyuncu ZK-R5C4'), findsOneWidget);
    });

    testWidgets('herkes birinciyse "Kazandın" değil "Berabere" yazar', (
      tester,
    ) async {
      await mountResult(
        tester,
        players: [
          _p('me', 'Ez', score: 0, rank: 1),
          _p('a', 'Rojda', score: 0, rank: 1),
          _p('b', 'Azad', score: 0, rank: 1),
        ],
      );

      expect(find.text('Kazandın!'), findsNothing);
      expect(find.text('Berabere!'), findsOneWidget);
      // 2026-10-27: eşitlikte "1. sırada tamamladın" değil, paylaşıldığı
      // söylenir (başlık "Berabere!" ile çelişmesin).
      expect(
        find.text('3 oyuncu arasında 1. sırayı 3 kişi paylaştınız.'),
        findsOneWidget,
      );
      expect(find.textContaining('sırada tamamladın'), findsNothing);
    });

    testWidgets('birinci olmayan oyuncu "Kazandın" görmez, sırasını okur', (
      tester,
    ) async {
      await mountResult(
        tester,
        ownId: 'third',
        players: [
          _p('top', 'Rojda', score: 250, rank: 1),
          _p('third', 'Azad', score: 100, rank: 2),
          _p('x', 'Berfîn', score: 40, rank: 3),
        ],
      );

      expect(find.text('Kazandın!'), findsNothing);
      expect(find.text('Yarış tamamlandı'), findsOneWidget);
      expect(
        find.text('3 oyuncu arasında yarışı 2. sırada tamamladın.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('crowd-standing-me-2')), findsOneWidget);
    });

    testWidgets('ayrılan çağıran: "Sen" satırı Ayrıldı rozetiyle, son sıralama '
        'görünür, kazandı/sıra metni yok', (tester) async {
      // Sonuç, oyundan ayrılan oyuncuya da sunulur (sunucu 2026-10-16).
      await mountResult(
        tester,
        ownId: 'me',
        players: [
          _p('top', 'Rojda', score: 250, rank: 1),
          _p('third', 'Azad', score: 100, rank: 2),
          _p('me', 'Ez', score: 60, left: true),
        ],
      );

      expect(find.text('Kazandın!'), findsNothing);
      expect(find.text('Yarış tamamlandı'), findsOneWidget);
      // Sıralamada olmadığım için "x. sırada tamamladın" cümlesi yok.
      expect(
        find.byKey(const ValueKey('crowd-standings-summary')),
        findsNothing,
      );
      // Kendi satırım ayrılanlar grubunda, "Sen" ve "Ayrıldı" ile.
      final mine = find.byKey(const ValueKey('crowd-left-me'));
      expect(mine, findsOneWidget);
      expect(
        find.descendant(of: mine, matching: find.text('Sen')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mine, matching: find.text('Ayrıldı')),
        findsOneWidget,
      );
      // Son sıralama: aktif oyuncular sıralı ve madalyalı.
      expect(find.byKey(const ValueKey('crowd-standing-top')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('crowd-standing-third')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('crowd-standing-me-1')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Kurmancî sonuç başlığı ve ayrılan etiketi', (tester) async {
      await mountResult(tester, players: players, ku: true);

      expect(find.text('Rêzkirina pêşbirkê'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('crowd-left-gone')),
          matching: find.text('Derket'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('50 oyunculu sıralama taşmadan çizilir', (tester) async {
      final many = [
        _p('me', 'Ez', score: 900, rank: 1),
        for (var i = 1; i < 50; i++)
          _p('p$i', 'Oyuncu $i', score: 900 - i * 10, rank: i + 1),
      ];
      await mountResult(tester, players: many);

      expect(tester.takeException(), isNull);
      expect(
        find.text('50 oyuncu arasında yarışı 1. sırada tamamladın.'),
        findsOneWidget,
      );
    });
  });
}

/// Kalabalık lobi için sahte depo: oyuncu listesi akışı, oda satırı okuma
/// sayacı ve başlat çağrısı sayacı.
class _LobbyRepo extends MockZanKurdRepository {
  _LobbyRepo({required this.me, required this.players});

  final String me;
  List<Player> players;
  String snapshotHostId = 'host-user';
  int snapshotLoads = 0;
  int startCalls = 0;
  final StreamController<List<Player>> playersController =
      StreamController<List<Player>>.broadcast();

  GameRoom room() => _crowdRoom(players: players, hostId: 'host-user');

  @override
  String? get currentUserId => me;

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async =>
      List<Player>.of(players);

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) async* {
    yield List<Player>.of(players);
    yield* playersController.stream;
  }

  @override
  Future<GameRoom> loadRoomSnapshot(String roomId) async {
    snapshotLoads++;
    return _crowdRoom(players: players, hostId: snapshotHostId);
  }

  @override
  Future<void> startGame(GameRoom room) async {
    startCalls++;
  }
}

/// Sunucu-gizli cevaplı kalabalık oyun için sahte depo.
class _QuizRepo extends MockZanKurdRepository {
  _QuizRepo({required this.players, required GameRoom room})
    : snapshot = _snapshotFor(room);

  List<Player> players;
  final RoomResumeSnapshot snapshot;
  Object? markError;
  int resumeCalls = 0;
  int markCalls = 0;
  int submitCalls = 0;
  int leaveCalls = 0;
  int finishCalls = 0;
  int resultCalls = 0;
  final List<Map<String, dynamic>> sent = [];
  final StreamController<List<Player>> playersController =
      StreamController<List<Player>>.broadcast();
  final StreamController<Map<String, dynamic>> broadcasts =
      StreamController<Map<String, dynamic>>.broadcast();

  static RoomResumeSnapshot _snapshotFor(GameRoom room) {
    final now = DateTime.utc(2026, 10, 16, 12);
    return RoomResumeSnapshot(
      room: room,
      currentQuestionIndex: 0,
      ownScore: 0,
      streak: 0,
      bestStreak: 0,
      correctCount: 0,
      wrongCount: 0,
      answers: const [],
      serverNow: now,
      questionStartedAt: now,
      deadline: now.add(const Duration(seconds: 25)),
      remainingMs: 25000,
    );
  }

  @override
  String? get currentUserId => 'me';

  @override
  bool get usesServerHiddenAnswers => true;

  @override
  Future<String> getProfileName() async => 'Ez';

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) =>
      broadcasts.stream;

  @override
  Future<void> sendRoomBroadcast(
    String roomId,
    Map<String, dynamic> payload,
  ) async {
    sent.add(payload);
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) async* {
    yield List<Player>.of(players);
    yield* playersController.stream;
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async =>
      List<Player>.of(players);

  @override
  Future<RoomResumeSnapshot?> loadMyResumableRoom() async {
    resumeCalls++;
    return snapshot;
  }

  @override
  Future<RoomResumeSnapshot?> markRoomClientReady(GameRoom room) async {
    markCalls++;
    final error = markError;
    if (error != null) throw error;
    return snapshot;
  }

  @override
  Future<RoomResumeSnapshot?> advanceRoomQuestion(
    GameRoom room, {
    required int expectedQuestionIndex,
  }) async => snapshot;

  @override
  Future<RoomEndState> loadRoomEndState(GameRoom room) async =>
      const RoomEndState(
        status: RoomStatus.active,
        endedReason: null,
        forfeitedBy: null,
      );

  @override
  Future<Map<String, dynamic>> submitAnswer({
    required GameRoom room,
    required QuizQuestion question,
    required String selectedOptionOptionKey,
    required int responseMs,
  }) async {
    submitCalls++;
    return {'accepted': true, 'pending': true};
  }

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    leaveCalls++;
    // Kalabalıkta ayrılma kalan aktifi 2'nin altına indirip odayı bitirebilir.
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'completed',
      forfeitedBy: null,
    );
  }

  @override
  Future<void> finishGame(GameRoom room) async {
    finishCalls++;
  }

  @override
  Future<RoomResultSnapshot?> loadRoomResult(GameRoom room) async {
    resultCalls++;
    return null;
  }

  Future<void> close() async {
    await playersController.close();
    await broadcasts.close();
  }
}
