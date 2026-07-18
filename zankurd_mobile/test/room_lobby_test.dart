import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/widgets/styled_button.dart';
import 'support/widget_test_helpers.dart';

/// Host-only online lobby for start-gate diagnostics.
class _HostOnlyRoomRepository extends MockZanKurdRepository {
  _HostOnlyRoomRepository()
    : _players = const [
        Player(
          id: 'host',
          name: 'HostOyuncu',
          score: 0,
          state: 'Hazır',
          streak: 0,
        ),
      ];

  final List<Player> _players;

  @override
  String? get currentUserId => 'host-user';

  GameRoom hostLobbyRoom() => GameRoom(
    id: 'room-sync-1',
    name: 'Hevalên Zanînê',
    code: 'ZK-SYNC',
    category: 'Ziman',
    players: List<Player>.of(_players),
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    return List<Player>.of(_players);
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(List<Player>.of(_players));
  }
}

/// Emits a second participant shortly after subscribe (sync simulation).
class _GrowingPlayersRoomRepository extends _HostOnlyRoomRepository {
  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) async* {
    yield List<Player>.of(_players);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield [
      ..._players,
      const Player(
        id: 'guest',
        name: 'Misafir',
        score: 0,
        state: 'Bekliyor',
        streak: 0,
      ),
    ];
  }
}

/// Realtime returns stale 1-player list; polling recovers with 2 players.
class _StaleStreamPollRecoveryRepository extends _HostOnlyRoomRepository {
  int pollCalls = 0;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) {
    return Stream.value(List<Player>.of(_players));
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    pollCalls += 1;
    return [
      ..._players,
      const Player(
        id: 'guest',
        name: 'Misafir',
        score: 0,
        state: 'Bekliyor',
        streak: 0,
      ),
    ];
  }
}

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  testWidgets('room lobby remains usable in landscape', (tester) async {
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Özel Oda'), findsOneWidget);
    expect(find.text('Oyuncular'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Yarışı Başlat'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Yarışı Başlat'), findsOneWidget);
  });

  testWidgets('room lobby keeps start disabled until two players are present', (
    tester,
  ) async {
    final repository = _HostOnlyRoomRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Yarışı başlatmak için en az 2 oyuncu olmalıdır.'),
      findsOneWidget,
    );

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNull);
  });

  testWidgets('room lobby enables start after player stream adds a guest', (
    tester,
  ) async {
    final repository = _GrowingPlayersRoomRepository();

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.hostLobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Misafir'), findsNothing);

    await tester.pump(const Duration(milliseconds: 60));

    expect(find.text('Misafir'), findsOneWidget);
    expect(
      find.text('Yarışı başlatmak için en az 2 oyuncu olmalıdır.'),
      findsNothing,
    );

    final startButton = tester.widget<GeometricGradientButton>(
      find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
    );
    expect(startButton.onPressed, isNotNull);
  });

  testWidgets(
    'room lobby recovers via polling when realtime player list stays stale',
    (tester) async {
      final repository = _StaleStreamPollRecoveryRepository();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        testShell(
          child: RoomScreen(
            repository: repository,
            initialRoom: repository.hostLobbyRoom(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Misafir'), findsNothing);
      final disabledButton = tester.widget<GeometricGradientButton>(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      );
      expect(disabledButton.onPressed, isNull);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(repository.pollCalls, greaterThan(0));
      expect(find.text('Misafir'), findsOneWidget);

      final enabledButton = tester.widget<GeometricGradientButton>(
        find.widgetWithText(GeometricGradientButton, 'Yarışı Başlat'),
      );
      expect(enabledButton.onPressed, isNotNull);
      expect(find.byType(QuizScreen), findsNothing);
    },
  );
}
