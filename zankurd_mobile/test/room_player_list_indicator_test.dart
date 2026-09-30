import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

/// "Lîsteya lîstikvanan tê nûvekirin…" göstergesi yalnız GERÇEK bir ilk
/// yükleme sürerken görünmeli.
///
/// ## Kusur
///
/// Gösterge `room.players.length < 2` kapısına bağlıydı. Bu bir yenileme
/// durumu değil, bir bekleme koşuluydu: ev sahibi odada tek kaldığı sürece
/// (canlı sunucuda 11+ saniye) dönen daire hiç kapanmıyordu. Oysa oyuncu
/// listesi çoktan gelmişti — gösterge veriyi değil, ikinci oyuncunun yokluğunu
/// işaret ediyordu ve kullanıcı onu "takılı kalan yenileme" sanıyordu.
///
/// ## Kural
///
///   * İlk oyuncu listesi henüz gelmediyse gösterge AÇIKTIR,
///   * ilk liste uygulanınca (ya da ilk deneme bitince) KAPANIR,
///   * periyodik arka plan yoklaması göstergeyi ASLA YAKMAZ.
///
/// Davranış (oyuncu listesinin kendisi) değişmez; yalnız göstergeye bağlı
/// durum değişir.
class _DeferredPlayersRepository extends MockZanKurdRepository {
  final StreamController<List<Player>> _playersController =
      StreamController<List<Player>>.broadcast();
  final List<Player> _players = <Player>[];

  /// Kaç kez arka plan yoklaması yapıldığı — test, yoklamanın gerçekten
  /// çalıştığını kanıtlamak için bu sayaca bakar.
  int pollCalls = 0;

  @override
  String? get currentUserId => 'host-user';

  Future<void> close() => _playersController.close();

  /// İlk (ya da sonraki) oyuncu listesini bilinçli olarak GEÇ gönderir:
  /// gerçek depoda ilk liste realtime'den gelir, burada gelme anını test
  /// yönetir.
  void emitPlayers(List<Player> players) {
    _players
      ..clear()
      ..addAll(players);
    _playersController.add(List<Player>.of(_players));
  }

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      _playersController.stream;

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async {
    pollCalls += 1;
    return List<Player>.of(_players);
  }
}

const ValueKey<String> _indicatorKey = ValueKey('room-connection-state');

void main() {
  testWidgets('ilk oyuncu listesi gelince gösterge kaybolur', (tester) async {
    final repository = _DeferredPlayersRepository();
    addTearDown(repository.close);

    // Gösterge listenin en üstündedir; yine de "kaybolmuş gibi" görünmesin
    // diye lobinin üst bölümü tek kareye sığacak kadar yüksek yüzey kuruyoruz.
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final room = repository.createRoom().copyWith(
      id: 'room-indicator-first-list',
      players: const <Player>[],
    );

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump();

    final indicator = find.byKey(_indicatorKey);
    final label = find.text(Tr.forKu(K.playerListUpdating, false));

    expect(
      indicator,
      findsOneWidget,
      reason: 'İlk liste henüz gelmedi: gösterge bu sırada açık olmalı.',
    );
    expect(label, findsOneWidget);

    // İlk liste geldi — tek oyuncu (ev sahibi) ile.
    repository.emitPlayers(const [
      Player(id: 'host-user', name: 'HostOyuncu', score: 0, state: 'Hazır'),
    ]);
    await tester.pump();

    expect(find.text('HostOyuncu'), findsOneWidget);
    expect(
      indicator,
      findsNothing,
      reason:
          'İlk liste elde: gösterge inmeli. Oda 1 oyunculu olduğu için eski '
          '`players.length < 2` kapısı burada takılı kalıyordu.',
    );
    expect(label, findsNothing);

    // Arka plan yoklaması: 3 saniye sonra `_pollPlayersOnce` listeyi yeniden
    // uygular. Bu tazeleme göstergeyi yeniden yakmamalı.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();

    expect(
      repository.pollCalls,
      greaterThan(0),
      reason: 'Yoklama çalışmış olmalı — sonstür "arka plan" iddiası boşa.',
    );
    expect(
      indicator,
      findsNothing,
      reason: 'Periyodik arka plan yoklaması göstergeyi yakmamalı.',
    );
    expect(label, findsNothing);
  });

  testWidgets('odayla gelen liste varsa gösterge hiç çıkmaz', (tester) async {
    final repository = _DeferredPlayersRepository();
    addTearDown(repository.close);

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Canlı senaryo: ev sahibi odayı tek başına açar, liste zaten eldedir.
    final room = repository.createRoom().copyWith(
      id: 'room-indicator-initial-data',
      players: const [
        Player(id: 'host-user', name: 'HostOyuncu', score: 0, state: 'Hazır'),
      ],
    );

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump();

    expect(find.text('HostOyuncu'), findsOneWidget);
    expect(
      find.byKey(_indicatorKey),
      findsNothing,
      reason:
          'İlk veri baştan elde: tek oyunculu odada da dönen daire '
          'çizilmemeli (canlı sunucuda 11+ saniye dönüyordu).',
    );
    expect(find.text(Tr.forKu(K.playerListUpdating, false)), findsNothing);
  });
}
