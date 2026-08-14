import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';

import 'support/widget_test_helpers.dart';

/// Oda oyuncu listesindeki bir satırı engellemek onu ANINDA gizlemeli.
///
/// ## Kusur
///
/// `PlayerModerationButton.onBlocked` tanımlıydı (engelleme başarılıysa
/// çağıranın listeyi tazelemesi için) ama `room_screen.dart`taki tek çağrı
/// yerinde hiçbir yere bağlanmamıştı. Sonuç: düğme "Oyuncu engellendi"
/// diyordu, sunucudaki `blocked_users` satırı da doğru yazılıyordu, ama
/// aynı oyuncunun satırı oda ekranında durmaya devam ediyordu — kullanıcı
/// ekranı kapatıp açana kadar (o zaman `room.players` yeniden çekiliyordu)
/// tam da engellediği kişiyi görmeye devam ediyordu (2026-08-14 denetimi).
///
/// ## Bekçi
///
/// Rakibi (kendi satırı DEĞİL) engelleyip aynı ekranda, kapatıp açmadan,
/// satırının kaybolduğunu doğrular.
void main() {
  testWidgets('rakibi engelleyince satırı odadan anında kaybolur', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    final room = repository.createRoom().copyWith(
      players: const [
        Player(id: 'user', name: 'Sen', score: 0, state: 'Hazır'),
        Player(id: 'other-player', name: 'Berfin', score: 0, state: 'Hazır'),
      ],
    );

    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump();

    expect(find.text('Berfin'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('player-moderation-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('player-block-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Berfin'),
      findsNothing,
      reason:
          'Engelleme sunucuda başarılı oldu ama satır ekranı kapatıp açana '
          'kadar duruyordu; onBlocked artık yereldeki listeyi de süzer',
    );
  });
}
