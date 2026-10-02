// 2026-09-30 canlı: canlı sunucu denetiminin oyun/oda kusurlarının bekçisi.
//
// Hepsinin ortak sessizlik nedeni: testlerdeki sahte depo gerçek sunucu
// davranışını taklit etmiyordu.
//
// * Bot düellosunda yerel "ben" satırı kimliksizdi; sahte depo
//   `currentUserId`yi 'user' verse de test odaları kimliksiz oyuncuyla
//   kurulduğu için `_isMe` hep ad yedeğine düşüyordu. Gerçek misafirin oturum
//   kimliği dolu olduğundan ad yedeği hiç devreye girmiyor, "ben" satırı
//   rakip sayılıyordu.
// * Lobi listesi sahte depoda hep tekil geliyordu; gerçek realtime `stream()`
//   tohumu ile INSERT olayı aynı satırı iki kez getirebiliyor.
// * Sahte depo hiçbir zaman Türkçe varsayılan adı ("ZanKurd Oyuncusu")
//   Kurmancî bir ekrana taşımıyordu.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/fill_in_blank_widget.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const _question = QuizQuestion(
  id: 'live-defects-q1',
  category: 'Ziman',
  prompt: 'Kîjan peyv "mirov" e?',
  answers: ['mirov', 'ajal', 'dar', 'av'],
  correctAnswer: 'mirov',
  explanation: 'Açıklama.',
);

Future<void> _pumpDuel(
  WidgetTester tester, {
  required MockZanKurdRepository repository,
  required GameRoom room,
  bool ku = true,
}) async {
  SharedPreferences.setMockInitialValues({'zankurd.quiz_tutorial.seen': true});
  await tester.binding.setSurfaceSize(kPhoneSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: withDeviceInsets(
        QuizScreen(
          repository: repository,
          room: room,
          questions: const [_question],
          enableTimer: false,
          is1v1: true,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

class _GuestRepository extends MockZanKurdRepository {
  @override
  String? get currentUserId => 'guest-user';

  @override
  Future<String> getProfileName() async => 'ZanKurd Oyuncusu';
}

class _LeaveRecordingRepository extends MockZanKurdRepository {
  _LeaveRecordingRepository({required this.userId});

  final String userId;
  int leaveCalls = 0;

  @override
  String? get currentUserId => userId;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      const Stream.empty();

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) => const Stream.empty();

  @override
  Future<RoomLeaveOutcome> leaveOnlineRoom(GameRoom room) async {
    leaveCalls++;
    return const RoomLeaveOutcome(
      status: 'finished',
      reason: 'host_left',
      forfeitedBy: null,
    );
  }
}

class _DuplicatingLobbyRepository extends MockZanKurdRepository {
  @override
  String? get currentUserId => 'host-user';

  static const _host = Player(
    id: 'host-user',
    name: 'ZanKurd Oyuncusu',
    score: 0,
    state: Player.readyState,
  );

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(const [_host, _host]);

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => const [
    _host,
    _host,
  ];

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) => const Stream.empty();
}

void main() {
  group('bot düellosu: üst puan kartı', () {
    const botRoom = GameRoom(
      name: '1vs1',
      code: 'ZK-BOT',
      category: 'Ziman',
      players: [
        Player(name: 'ZanKurd Oyuncusu', score: 0, state: Player.readyState),
        Player(name: 'Zana', score: 0, state: Player.readyState),
      ],
      status: RoomStatus.active,
      questionCount: 1,
    );

    testWidgets('oturum kimliği dolu misafirde rakip tarafı rakibi gösterir, '
        'benim satırımı değil', (tester) async {
      await _pumpDuel(tester, repository: _GuestRepository(), room: botRoom);
      // Doğru cevap: benim puanım artar, botun puanı (soru bitmeden) 0/az
      // kalır. Kusurlu sürümde artan puan rakip tarafına da yazılıyordu.
      await tester.tap(find.text('mirov').first);
      await tester.pump(const Duration(milliseconds: 600));

      // Üst kart + canlı liste: "Tu" ve "Zana" ikişer kez. Kusurlu
      // sürümde "Tu" üç, "Zana" bir kez görünüyordu.
      expect(find.text('Tu'), findsNWidgets(2));
      expect(find.text('Zana'), findsNWidgets(2));
      expect(find.text('ZanKurd Oyuncusu'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('puan kartında İngilizce "pts" yok, sözlükteki "pûan" var', (
      tester,
    ) async {
      await _pumpDuel(tester, repository: _GuestRepository(), room: botRoom);
      expect(find.textContaining('pts'), findsNothing);
      expect(find.textContaining('pûan'), findsNWidgets(2));
    });

    testWidgets('Türkçede de "puan"', (tester) async {
      await _pumpDuel(
        tester,
        repository: _GuestRepository(),
        room: botRoom,
        ku: false,
      );
      expect(find.textContaining('pts'), findsNothing);
      expect(find.text('0 puan'), findsNWidgets(2));
    });
  });

  group('gerçek rakipli oda', () {
    testWidgets(
      'rakip tarafı rakibin adını ve puanını gösterir; yer tutucu ad çözülür',
      (tester) async {
        const room = GameRoom(
          id: 'real-room',
          name: '1vs1',
          code: 'ZK-REAL',
          category: 'Ziman',
          players: [
            Player(
              id: 'guest-user',
              name: 'ZanKurd Oyuncusu',
              score: 0,
              state: Player.readyState,
            ),
            Player(
              id: 'rival-id',
              name: 'Berfin',
              score: 230,
              state: Player.readyState,
            ),
          ],
          status: RoomStatus.active,
          questionCount: 1,
          hostId: 'guest-user',
        );
        await _pumpDuel(tester, repository: _GuestRepository(), room: room);

        // Üst kart + canlı liste.
        expect(find.text('Berfin'), findsNWidgets(2));
        expect(find.text('Lîstikvan'), findsNWidgets(2));
        expect(find.text('ZanKurd Oyuncusu'), findsNothing);
        expect(find.text('230 pûan'), findsOneWidget);
      },
    );
  });

  group('oda lobisi', () {
    test('dedupeRoomPlayers aynı kimliği tek satıra indirir', () {
      const a = Player(id: 'a', name: 'A', score: 0, state: 'Bekliyor');
      const aReady = Player(id: 'a', name: 'A', score: 0, state: 'Hazır');
      const b = Player(id: 'b', name: 'B', score: 0, state: 'Hazır');
      const local1 = Player(name: 'Tu', score: 0, state: 'Hazır');
      const local2 = Player(name: 'Tu', score: 0, state: 'Hazır');

      final result = dedupeRoomPlayers([a, b, aReady]);
      expect(result.map((p) => p.id), ['a', 'b']);
      expect(result.first.state, 'Hazır', reason: 'son gelen veri kazanır');
      expect(
        dedupeRoomPlayers([local1, local2]),
        hasLength(2),
        reason: 'kimliksiz yerel satırlara dokunulmaz',
      );
    });

    testWidgets(
      'aynı kimliğin çift gelen kaydı tek satır; "2 oyuncu gerekli" kalır; '
      'Kurmancî ekranda yer tutucu ad dile göre',
      (tester) async {
        final repository = _DuplicatingLobbyRepository();
        const room = GameRoom(
          id: 'dup-room',
          name: '1vs1',
          code: 'ZK-DUP',
          category: 'Ziman',
          players: [
            Player(
              id: 'host-user',
              name: 'ZanKurd Oyuncusu',
              score: 0,
              state: Player.readyState,
            ),
            Player(
              id: 'host-user',
              name: 'ZanKurd Oyuncusu',
              score: 0,
              state: Player.readyState,
            ),
          ],
          status: RoomStatus.lobby,
          questionCount: 10,
          hostId: 'host-user',
        );
        await tester.binding.setSurfaceSize(kPhoneSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          testShell(
            languageProvider: kurmanciLang(),
            child: RoomScreen(repository: repository, initialRoom: room),
          ),
        );
        // İlk kare: kullanıcı ilk 1-2 saniyede tam olarak bunu görüyordu.
        // "Lîstikvan" iki yerde: bölüm başlığı (oyuncular) + TEK oyuncu
        // satırı. Çift kayıt üçüncüsünü çizerdi.
        expect(find.text('Lîstikvan'), findsNWidgets(2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Lîstikvan'), findsNWidgets(2));
        expect(find.text('ZanKurd Oyuncusu'), findsNothing);
        expect(
          find.text(Tr.forKu(K.needTwoPlayers, true)),
          findsOneWidget,
          reason: 'tek oyuncu iki sayılıp başlatma kapısı açılmamalı',
        );
      },
    );

    for (final userId in ['host-user', 'guest-user']) {
      testWidgets('geri: ${userId == "host-user" ? "ev sahibi" : "konuk"} '
          'sunucuda odadan ayrılır (leave çağrılır)', (tester) async {
        final repository = _LeaveRecordingRepository(userId: userId);
        const room = GameRoom(
          id: 'leave-room',
          name: '1vs1',
          code: 'ZK-LEAVE',
          category: 'Ziman',
          players: [
            Player(
              id: 'host-user',
              name: 'Ev',
              score: 0,
              state: Player.readyState,
            ),
            Player(
              id: 'guest-user',
              name: 'Konuk',
              score: 0,
              state: Player.readyState,
            ),
          ],
          status: RoomStatus.lobby,
          questionCount: 10,
          hostId: 'host-user',
        );
        await tester.pumpWidget(
          testShell(
            child: RoomScreen(repository: repository, initialRoom: room),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.binding.handlePopRoute();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(repository.leaveCalls, 1);
      });
    }
  });

  group('yazmalı soru: süre dolunca cevap tek satır', () {
    testWidgets('sonuç kutusu zaman aşımında çizilmez (bildirim yazıyor)', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: Scaffold(
            body: FillInBlankWidget(
              question: const QuizQuestion(
                id: 'fib-timeout',
                category: 'Ziman',
                prompt: 'Mirov ___ e.',
                answers: ['mirovekî'],
                correctAnswer: 'mirovekî',
                explanation: '',
                type: QuestionType.fillInBlank,
              ),
              disabled: true,
              showResult: true,
              selectedAnswer: 'TIMEOUT',
              onAnswerSubmitted: (_) {},
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('fill-in-blank-result')), findsNothing);
    });

    testWidgets('yanlış cevapta kutu yine çizilir', (tester) async {
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: Scaffold(
            body: FillInBlankWidget(
              question: const QuizQuestion(
                id: 'fib-wrong',
                category: 'Ziman',
                prompt: 'Mirov ___ e.',
                answers: ['mirovekî'],
                correctAnswer: 'mirovekî',
                explanation: '',
                type: QuestionType.fillInBlank,
              ),
              disabled: true,
              showResult: true,
              selectedAnswer: 'xelet',
              onAnswerSubmitted: (_) {},
            ),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey('fill-in-blank-result')),
        findsOneWidget,
      );
    });
  });

  group('düello: uzun soruda dördüncü şık', () {
    const longQuestion = QuizQuestion(
      id: 'long-duel-q',
      category: 'Dîrok',
      prompt:
          'Kîjan têgeh bi vê ravekirinê tê nasîn: "xanedaniya kurdî ya '
          'serdema navîn ku navenda wê Amed û doralên wê bûn"?',
      answers: ['Şerefname', 'Mîrgeha Erdelanê', 'Mîrgeha Botan', 'Merwanî'],
      correctAnswer: 'Mîrgeha Botan',
      explanation: '',
    );

    testWidgets('402×874: son şık kaydırılınca alt perdenin ÜSTÜNDE biter, '
        'çubuğun arkasında kalmaz', (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
      });
      await tester.binding.setSurfaceSize(kPhoneSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = _GuestRepository();
      const room = GameRoom(
        name: '1vs1',
        code: 'ZK-LONG',
        category: 'Dîrok',
        players: [
          Player(name: 'A', score: 0, state: Player.readyState),
          Player(name: 'Zana', score: 0, state: Player.readyState),
        ],
        status: RoomStatus.active,
        questionCount: 1,
      );
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: withDeviceInsets(
            QuizScreen(
              repository: repository,
              room: room,
              questions: const [longQuestion],
              enableTimer: false,
              is1v1: true,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final tiles = find.byType(QuizOptionTile);
      expect(tiles, findsNWidgets(4));
      await tester.drag(
        find.byKey(const ValueKey('quiz-portrait-scroll')),
        const Offset(0, -800),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final dockTop = tester.getRect(find.byType(SahneBottomDock)).top;
      final lastBottom = [
        for (var i = 0; i < 4; i++) tester.getRect(tiles.at(i)).bottom,
      ].reduce((a, b) => a > b ? a : b);
      expect(
        lastBottom,
        lessThanOrEqualTo(dockTop),
        reason: 'D şıkkı alt perdenin arkasında kalıyor',
      );
    });
  });

  test('arayüz metinlerinde ASCII üç nokta yok (tek karakter "…")', () {
    // 2026-09-30 canlı: "Te winda kir…" ekranda üç nokta gibi göründü;
    // kaynakta zaten tek karakterdi (U+2026). Bekçi, kaynağa ASCII "..."
    // girmesini yakalar.
    final source = File('lib/src/l10n/strings.dart').readAsStringSync();
    final offenders = <String>[];
    for (final line in source.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;
      if (!trimmed.contains("'")) continue;
      // Dart yayılım işleci (`...RegExp`) metin değildir.
      if (trimmed.startsWith('...')) continue;
      if (RegExp(r"'[^']*\.\.\.[^']*'").hasMatch(trimmed)) {
        offenders.add(trimmed);
      }
    }
    expect(offenders, isEmpty, reason: offenders.take(3).join(' | '));
    expect(Tr.forKu(K.youLost, true), endsWith('…'));
    expect(Tr.forKu(K.youLost, false), endsWith('…'));
  });
}
