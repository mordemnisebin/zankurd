import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

class _RoomExitRepository extends MockZanKurdRepository {
  final StreamController<RoomStatus> _statuses =
      StreamController<RoomStatus>.broadcast(sync: true);

  int leaveCalls = 0;
  int updateReadyCalls = 0;
  int playerSubscriptionCount = 0;
  int statusSubscriptionCount = 0;
  int statusPollCount = 0;
  bool failNextLeave = false;
  bool failReadyUpdate = false;
  bool failQuestionLoad = false;
  bool failSubscriptionCancel = false;
  Completer<void>? pendingLeave;

  @override
  String? get currentUserId => 'guest-user';

  @override
  bool get usesServerHiddenAnswers => true;

  GameRoom onlineLobby() => const GameRoom(
    id: 'room-exit-1',
    name: 'Hevalên Zanînê',
    code: 'ZK-EXIT',
    category: 'Ziman',
    players: [
      Player(
        id: 'host-user',
        name: 'Mêvandar',
        score: 0,
        state: Player.readyState,
      ),
      Player(
        id: 'guest-user',
        name: 'Mêvan',
        score: 0,
        state: Player.readyState,
      ),
    ],
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    playerSubscriptionCount++;
    if (failSubscriptionCancel) {
      late StreamController<List<Player>> controller;
      controller = StreamController<List<Player>>(
        onListen: () => controller.add(room.players),
        onCancel: () =>
            Future<void>.error(StateError('subscription cancellation failed')),
      );
      return controller.stream;
    }
    return Stream<List<Player>>.value(room.players);
  }

  @override
  Stream<RoomStatus> subscribeRoomStatus(GameRoom room) {
    statusSubscriptionCount++;
    return _statuses.stream;
  }

  @override
  Future<void> leaveOnlineRoom(GameRoom room) async {
    leaveCalls++;
    final pending = pendingLeave;
    if (pending != null) {
      await pending.future;
      return;
    }
    if (failNextLeave) {
      failNextLeave = false;
      throw StateError('network details must not reach the player');
    }
  }

  @override
  Future<void> updateReady(GameRoom room, bool isReady) async {
    updateReadyCalls++;
    if (failReadyUpdate) throw StateError('offline mock failure');
  }

  @override
  Future<List<QuizQuestion>> loadRoomQuestions(GameRoom room) async {
    if (failQuestionLoad) throw StateError('question fetch failed');
    return super.loadRoomQuestions(room);
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    statusPollCount++;
    return room.status;
  }

  void emitStatus(RoomStatus status) => _statuses.add(status);

  Future<void> close() => _statuses.close();
}

class _RoomLauncher extends StatelessWidget {
  const _RoomLauncher({required this.repository, required this.room});

  final _RoomExitRepository repository;
  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          key: const ValueKey('open-room'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  RoomScreen(repository: repository, initialRoom: room),
            ),
          ),
          child: const Text('Odayı aç'),
        ),
      ),
    );
  }
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  // Oda işlemleri abonelik iptali / soru yükleme Future'larından sonra
  // rotayı değiştirir; ikinci tur bu devamı ve yeni rota animasyonunu
  // deterministik olarak tamamlar.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _openRoom(
  WidgetTester tester,
  _RoomExitRepository repository,
  GameRoom room,
) async {
  await tester.pumpWidget(
    testShell(
      child: _RoomLauncher(repository: repository, room: room),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-room')));
  // Guest lobisindeki canlı bekleme göstergesi sürekli kare üretir;
  // `pumpAndSettle` bu nedenle doğal olarak hiç tamamlanmaz.
  await _pumpRouteTransition(tester);
  expect(find.byType(RoomScreen), findsOneWidget);
}

void main() {
  testWidgets('online room stays open until server confirms leave', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    final pending = Completer<void>();
    repository.pendingLeave = pending;
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump();

    expect(repository.leaveCalls, 1);
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(find.text('Odadan ayrılıyor…'), findsOneWidget);

    pending.complete();
    await _pumpRouteTransition(tester);

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-room')), findsOneWidget);
  });

  testWidgets('failed online leave restores lobby and allows retry', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failNextLeave = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 1);
    expect(find.byType(RoomScreen), findsOneWidget);
    expect(
      find.text('Odadan ayrılamadın. Lütfen tekrar dene.'),
      findsOneWidget,
    );
    expect(repository.playerSubscriptionCount, 2);
    expect(repository.statusSubscriptionCount, 2);
    expect(find.byTooltip('Odadan ayrıl'), findsOneWidget);

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 2);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('subscription cleanup failure does not block online leave', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failSubscriptionCancel = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 1);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('local room keeps best-effort ready reset and exits safely', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failReadyUpdate = true;
    addTearDown(repository.close);
    final localRoom = GameRoom(
      name: 'Yerel oda',
      code: 'ZK-LOCAL',
      category: 'Ziman',
      players: repository.onlineLobby().players,
      status: RoomStatus.lobby,
      questionCount: 10,
      hostId: 'guest-user',
    );
    await _openRoom(tester, repository, localRoom);

    await tester.tap(find.byTooltip('Odadan ayrıl'));
    await _pumpRouteTransition(tester);

    expect(repository.leaveCalls, 0);
    expect(repository.updateReadyCalls, 1);
    expect(find.byType(RoomScreen), findsNothing);
  });

  testWidgets('disposing a room does not write an unreliable ready state', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await _pumpRouteTransition(tester);

    expect(repository.updateReadyCalls, 0);
  });

  testWidgets('finished lobby returns guest once with a clear message', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    repository.emitStatus(RoomStatus.finished);
    repository.emitStatus(RoomStatus.finished);
    await _pumpRouteTransition(tester);

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.byKey(const ValueKey('open-room')), findsOneWidget);
    expect(find.text('Ev sahibi ayrıldığı için oda kapandı.'), findsOneWidget);
    expect(repository.leaveCalls, 0);
  });

  testWidgets('finished status is ignored after quiz navigation starts', (
    tester,
  ) async {
    final repository = _RoomExitRepository();
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    repository.emitStatus(RoomStatus.active);
    repository.emitStatus(RoomStatus.finished);
    await _pumpRouteTransition(tester);

    // QuizScreen terminal olayı kendi akışında sonuç rotasına
    // çevirebilir. RoomScreen'in yapmaması gereken şey lobi mesajıyla
    // launcher'a geri atmaktır.
    expect(find.byKey(const ValueKey('open-room')), findsNothing);
    expect(find.text('Ev sahibi ayrıldığı için oda kapandı.'), findsNothing);
  });

  testWidgets('question load failure resumes lobby status monitoring', (
    tester,
  ) async {
    final repository = _RoomExitRepository()..failQuestionLoad = true;
    addTearDown(repository.close);
    await _openRoom(tester, repository, repository.onlineLobby());

    repository.emitStatus(RoomStatus.active);
    await _pumpRouteTransition(tester);

    expect(find.byType(QuizScreen), findsNothing);
    expect(find.text('Oyun başlatılamadı. Tekrar dene.'), findsOneWidget);
    expect(repository.statusSubscriptionCount, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(repository.statusPollCount, greaterThan(0));
  });
}
