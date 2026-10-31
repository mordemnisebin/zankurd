import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/home/room_invite_card.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/services/foreground_push_center.dart';
import 'package:zankurd_mobile/src/services/push_messaging_gateway.dart';

import 'support/widget_test_helpers.dart';

void main() {
  setUp(ForegroundPushCenter.resetForTest);
  tearDown(ForegroundPushCenter.resetForTest);

  testWidgets(
    'oda push Yarış kartını yeniler; gizli Ana kartı polling yapmaz',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: AppShell(
            repository: repository,
            connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-play')));
      await tester.pumpAndSettle();

      final play = tester.widget<PlayHubScreen>(find.byType(PlayHubScreen));
      var refreshes = 0;
      void onRefresh() => refreshes++;
      play.refreshSignal!.addListener(onRefresh);
      ForegroundPushCenter.emit(
        const ForegroundPush(data: {'kind': 'room_invite'}),
      );
      await tester.pumpAndSettle();
      expect(refreshes, 1);
      play.refreshSignal!.removeListener(onRefresh);
      final cards = tester.widgetList<RoomInviteCard>(
        find.byType(RoomInviteCard, skipOffstage: false),
      );
      expect(cards.where((card) => card.isVisible).length, 1);
      expect(cards.where((card) => !card.isVisible), isNotEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
