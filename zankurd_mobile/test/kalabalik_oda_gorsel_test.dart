import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

import 'support/widget_test_helpers.dart';

/// Kalabalık lobi görsel denetimi (2026-10-17 ekran turu).
///
/// ## Kusur
///
/// Kalabalık odada her oyuncu satırının sonunda bildir bayrağı vardı: 7–50
/// satırda aynı simge tekrarlanıp listeyi gürültüye çeviriyordu.
///
/// ## Bekçi
///
/// Kalabalık odada bayrak yok; başkalarının satırında sessiz üç nokta (App
/// Store 1.2 görünür bildir/engelle), kendi satırında hiçbiri; uzun basış da
/// açar. 2 kişilik odada bayrak kalır.
void main() {
  Future<void> mount(WidgetTester tester, {required int maxPlayers}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = MockZanKurdRepository();
    final room = repository.createRoom().copyWith(
      maxPlayers: maxPlayers,
      isCustom: true,
      players: const [
        Player(id: 'user', name: 'Sen', score: 0, state: 'Hazır'),
        Player(id: 'other-player', name: 'Berfin', score: 0, state: 'Hazır'),
        Player(id: 'third', name: 'Rojda', score: 0, state: 'Hazır'),
      ],
    );
    await tester.pumpWidget(
      testShell(
        child: RoomScreen(repository: repository, initialRoom: room),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'kalabalık odada üç nokta yalnız başkalarında; uzun basış da açar',
    (tester) async {
      await mount(tester, maxPlayers: 8);
      final buttons = find.byKey(const ValueKey('player-moderation-button'));
      // 3 oyuncu: kendi satırında yok, öteki ikisinde var.
      expect(buttons, findsNWidgets(2));
      expect(
        find.descendant(of: buttons, matching: find.byIcon(AppIcons.flag)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: buttons.first,
          matching: find.byIcon(AppIcons.ellipsisVertical),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(buttons.first).shortestSide,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(buttons.first);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('player-report-action')),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();

      await tester.longPress(
        find.byKey(const ValueKey('room-player-moderation-other-player')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-block-action')), findsOneWidget);
    },
  );

  testWidgets('iki kişilik odada görünür bayrak kalır', (tester) async {
    await mount(tester, maxPlayers: 2);
    expect(
      find.byKey(const ValueKey('player-moderation-button')),
      findsWidgets,
    );
  });
}
