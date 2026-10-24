/// Oda sahibinin lobiden oyuncu çıkarması (2026-10-22).
///
/// ## Neyi korur, niçin sessiz kalırdı
///
/// * Oda sahibi başka bir oyuncunun menüsünde "Odadan çıkar"ı görür, onay
///   penceresinden sonra `kickRoomPlayer` çağrılır ve satır listeden düşer.
///   Eskiden istenmeyen birini çıkarmanın tek yolu odayı kapatıp kodu
///   yeniden dağıtmaktı.
/// * Misafir menüsünde bu satır YOKTUR (sunucu da reddeder, ama düğme
///   görünürse misafir işe yaramayan bir eylem dener).
/// * Çıkarılan misafirin kendi satırı listeden düşünce lobi kapanır ve
///   "Oda sahibi seni odadan çıkardı." der. Sessiz kalsaydı hazır anahtarı
///   artık üyesi olmadığı bir odaya yazmaya çalışırdı.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

const _host = Player(id: 'host', name: 'Rojda', score: 0, state: 'Hazır');
const _guest = Player(id: 'guest', name: 'Berat', score: 0, state: 'Bekliyor');

class _LobbyRepository extends MockZanKurdRepository {
  _LobbyRepository(this.me);

  final String me;
  final players = StreamController<List<Player>>.broadcast();

  @override
  String? get currentUserId => me;

  GameRoom lobby() => const GameRoom(
    id: 'room-kick',
    name: 'Oda',
    code: '123456',
    category: 'Ziman',
    players: [_host, _guest],
    status: RoomStatus.lobby,
    questionCount: 10,
    hostId: 'host',
  );

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => const [
    _host,
    _guest,
  ];

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) => players.stream;
}

Future<void> _open(WidgetTester tester, _LobbyRepository repository) async {
  await tester.binding.setSurfaceSize(const Size(390, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    testShell(
      child: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const ValueKey('open-lobby'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RoomScreen(
                    repository: repository,
                    initialRoom: repository.lobby(),
                  ),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('open-lobby')));
  await _settle(tester);
}

/// Misafir lobisinde bekleme göstergesi sürekli döner; pumpAndSettle
/// hiç durulmaz. Sabit sayıda kare yeter.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('oda sahibi misafiri onayla odadan çıkarır', (tester) async {
    final repository = _LobbyRepository('host');
    addTearDown(repository.players.close);
    await _open(tester, repository);

    await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('player-kick-action')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('player-kick-action')));
    await _settle(tester);

    expect(find.text('Berat odadan çıkarılsın mı?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('kick-player-confirm')));
    await _settle(tester);

    expect(repository.kickedPlayerIds, ['guest']);
    expect(find.text('Oyuncu odadan çıkarıldı.'), findsOneWidget);
    expect(find.text('Berat'), findsNothing);
  });

  testWidgets('vazgeçilirse kimse çıkarılmaz', (tester) async {
    final repository = _LobbyRepository('host');
    addTearDown(repository.players.close);
    await _open(tester, repository);

    await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('player-kick-action')));
    await _settle(tester);
    await tester.tap(find.byKey(const ValueKey('kick-player-cancel')));
    await _settle(tester);

    expect(repository.kickedPlayerIds, isEmpty);
    expect(find.text('Berat'), findsOneWidget);
  });

  testWidgets('misafir menüsünde "Odadan çıkar" yoktur', (tester) async {
    final repository = _LobbyRepository('guest');
    addTearDown(repository.players.close);
    await _open(tester, repository);

    await tester.tap(find.byKey(const ValueKey('player-moderation-button')));
    await _settle(tester);
    expect(find.byKey(const ValueKey('player-report-action')), findsOneWidget);
    expect(find.byKey(const ValueKey('player-kick-action')), findsNothing);
  });

  testWidgets('çıkarılan misafirin lobisi kapanır ve sebebi söylenir', (
    tester,
  ) async {
    final repository = _LobbyRepository('guest');
    addTearDown(repository.players.close);
    await _open(tester, repository);
    expect(find.byType(RoomScreen), findsOneWidget);

    repository.players.add(const [_host, _guest]);
    await tester.pump();
    repository.players.add(const [_host]);
    await _settle(tester);

    expect(find.byType(RoomScreen), findsNothing);
    expect(find.text('Oda sahibi seni odadan çıkardı.'), findsOneWidget);
  });
}
