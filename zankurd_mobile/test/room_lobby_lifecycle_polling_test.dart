import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

/// Lobi yoklama çağrılarını sayan depo (tek oyunculu ev sahibi lobisi:
/// 60 sn'lik pil kısıtı devreye girmez).
class _CountingLobbyRepository extends MockZanKurdRepository {
  int playerPolls = 0;
  int statusPolls = 0;

  static const _host = Player(
    id: 'host-user',
    name: 'HostOyuncu',
    score: 0,
    state: 'Hazır',
    streak: 0,
  );

  @override
  String? get currentUserId => 'host-user';

  GameRoom lobbyRoom() => const GameRoom(
    id: 'room-lifecycle-1',
    name: 'Hevalên Zanînê',
    code: 'ZK-LIFE',
    category: 'Ziman',
    players: [_host],
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host-user',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    playerPolls++;
    return const [_host];
  }

  @override
  Future<RoomStatus> loadRoomStatus(GameRoom room) async {
    statusPolls++;
    return RoomStatus.lobby;
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(const [_host]);
}

/// Uygulama arka plandayken lobi yoklaması (3 sn) durur; dönüşte bir kez
/// yoklanır ve döngü sürer. Realtime aboneliklerine dokunulmaz.
// Gerçek platform sırası: AppLifecycleListener geçersiz geçişte assert eder.
void _toBackground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.paused);

void _toForeground(WidgetTester tester) => tester.binding
  ..handleAppLifecycleStateChanged(AppLifecycleState.hidden)
  ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
  ..handleAppLifecycleStateChanged(AppLifecycleState.resumed);

void main() {
  setUp(freshMockRepository);

  testWidgets('arka planda lobi yoklaması durur, dönüşte sürer', (
    tester,
  ) async {
    final repository = _CountingLobbyRepository();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.lobbyRoom(),
        ),
      ),
    );
    await tester.pump();

    // Önde: 3 sn'de bir oyuncu ve durum yoklanır.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repository.playerPolls, 1);
    expect(repository.statusPolls, 1);

    // Arka plan: süre geçse de yoklama yok.
    _toBackground(tester);
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(repository.playerPolls, 1);
    expect(repository.statusPolls, 1);

    // Dönüş: hemen bir kez yoklanır, sonra döngü yeniden kurulur.
    _toForeground(tester);
    await tester.pump();
    expect(repository.playerPolls, 2);
    expect(repository.statusPolls, 2);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    expect(repository.playerPolls, 3);
    expect(repository.statusPolls, 3);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 20));
  });
}
