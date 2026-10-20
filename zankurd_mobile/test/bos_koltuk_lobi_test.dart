// Tur 11 bekçisi — oda lobisinde boş koltuklar.
//
// KUSUR: oyuncu listesinin altı ölü alandı; 8 kişilik
// odada kaç kişi daha gelebileceği hiçbir yerde görünmüyordu.
// NİÇİN SESSİZDİ: lobi testleri yalnız mevcut oyuncuları sayıyordu; "olmayan
// bir şey" için assert yazılmaz. Burası kapasiteden türeyen boş koltukları
// (en çok 4 satır + "+N") sabitler.
//
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'support/widget_test_helpers.dart';

class _Repo extends MockZanKurdRepository {
  @override
  String? get currentUserId => 'host-user';
  static const host = Player(
    id: 'host-user',
    name: 'Host',
    score: 0,
    state: 'Hazır',
    streak: 0,
  );
  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => [host];
  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value([host]);
}

Future<void> _lobby(WidgetTester tester, int max) async {
  final repo = _Repo();
  await tester.binding.setSurfaceSize(const Size(390, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: RoomScreen(
        repository: repo,
        initialRoom: GameRoom(
          id: 'r',
          name: 'Grup',
          code: 'ZK-1',
          category: 'Ziman',
          players: const [_Repo.host],
          status: RoomStatus.lobby,
          hostId: 'host-user',
          maxPlayers: max,
          isCustom: true,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('8 kişilik odada 4 boş satır + "+3"', (tester) async {
    await _lobby(tester, 8);
    for (var i = 1; i <= 4; i++) {
      expect(find.byKey(ValueKey('room-empty-seat-$i')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('room-empty-seat-more')), findsOneWidget);
    expect(find.text('+3'), findsOneWidget);
  });

  testWidgets('3 kişilik odada 2 boş satır, "+N" yok', (tester) async {
    await _lobby(tester, 3);
    expect(find.byKey(const ValueKey('room-empty-seat-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-empty-seat-3')), findsNothing);
    expect(find.byKey(const ValueKey('room-empty-seat-more')), findsNothing);
  });

  testWidgets('2 kişilik odada tek yuva: "Rakip bekleniyor", çift yok', (
    tester,
  ) async {
    await _lobby(tester, 2);
    expect(find.byKey(const ValueKey('room-waiting-slot')), findsOneWidget);
    expect(find.byKey(const ValueKey('room-empty-seat-1')), findsNothing);
  });
}
