import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/widgets/floating_reaction_overlay.dart';

void main() {
  group('GameRoom Customization & Gamification', () {
    test('GameRoom model supports entryFee, durations and question counts', () {
      const room = GameRoom(
        id: 'test-room-1',
        name: '1vs1',
        code: 'ZK-0123456789',
        category: 'Ziman',
        players: [],
        status: RoomStatus.lobby,
        questionCount: 15,
        secondsPerQuestion: 15,
        entryFee: 50,
      );

      expect(room.entryFee, 50);
      expect(room.questionCount, 15);
      expect(room.secondsPerQuestion, 15);

      final updated = room.copyWith(entryFee: 100, questionCount: 5);
      expect(updated.entryFee, 100);
      expect(updated.questionCount, 5);
      expect(updated.secondsPerQuestion, 15);
    });

    test('GameRoom constants define allowed parameters', () {
      expect(GameRoom.allowedEntryFees, containsAll([0, 25, 50, 100]));
      expect(GameRoom.allowedQuestionCounts, containsAll([5, 10, 15]));
      expect(GameRoom.allowedDurations, containsAll([10, 15, 20, 30]));
      expect(GameRoom.defaultSecondsPerQuestion, 20);
    });

    test(
      'MockZanKurdRepository creates custom online room with parameters',
      () async {
        final repo = MockZanKurdRepository();
        final room = await repo.createOnlineRoom(
          category: 'Wêje',
          secondsPerQuestion: 30,
          questionCount: 15,
          entryFee: 25,
        );

        expect(room.category, 'Wêje');
        expect(room.secondsPerQuestion, 30);
        expect(room.questionCount, 15);
        expect(room.entryFee, 25);
      },
    );

    test(
      'room header reaction band stays clear of the centered back action on wide surfaces',
      () {
        const screenWidth = 1024.0;
        const contentWidth = 680.0;
        const backButtonWidth = 48.0;
        const safetyGap = 12.0;
        const peakBubbleWidth = 184.0 * 1.15;

        const contentLeft = (screenWidth - contentWidth) / 2;
        const backButtonRight = contentLeft + backButtonWidth;
        final left = roomHeaderReactionX(
          screenWidth: screenWidth,
          startXRatio: 0.25,
        );

        expect(left, greaterThanOrEqualTo(backButtonRight + safetyGap));
        expect(
          left + peakBubbleWidth,
          lessThanOrEqualTo(screenWidth - safetyGap),
        );
      },
    );

    testWidgets(
      'room header queues simultaneous reactions instead of overlapping them',
      (tester) async {
        final controller = FloatingReactionController();
        addTearDown(controller.dispose);
        tester.view.devicePixelRatio = 3.0;
        tester.view.physicalSize = const Size(390, 844) * 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            home: FloatingReactionOverlay(
              controller: controller,
              placement: FloatingReactionPlacement.roomHeader,
              child: const SizedBox.expand(),
            ),
          ),
        );

        controller.triggerReaction('👏 Destxweş!', senderName: 'Berfin');
        controller.triggerReaction('🔥 Agir!', senderName: 'Rojda');
        controller.triggerReaction('⚡ Lez be!', senderName: 'Baran');
        await tester.pump();

        final visibleBubbles = // 2026-09-29 Şahnê: balon görünüşüyle değil anahtarıyla bulunur.
        find.byKey(
          FloatingReactionOverlay.bubbleKey,
        );

        expect(controller.activeBubbles, hasLength(3));
        expect(
          visibleBubbles,
          findsOneWidget,
          reason:
              'Room-header reactions share a narrow safe band; rendering them '
              'all at once makes the messages cover each other.',
        );

        await tester.pump(const Duration(milliseconds: 1300));
        await tester.pump();

        expect(controller.activeBubbles, hasLength(2));
        expect(
          visibleBubbles,
          findsOneWidget,
          reason: 'The next queued reaction should replace the completed one.',
        );
      },
    );

    testWidgets('overlay follows a replacement external reaction controller', (
      tester,
    ) async {
      final first = FloatingReactionController();
      final second = FloatingReactionController();
      addTearDown(first.dispose);
      addTearDown(second.dispose);

      Widget overlay(FloatingReactionController controller) => MaterialApp(
        home: FloatingReactionOverlay(
          key: const ValueKey('reaction-overlay'),
          controller: controller,
          placement: FloatingReactionPlacement.roomHeader,
          child: const SizedBox.expand(),
        ),
      );

      await tester.pumpWidget(overlay(first));
      first.triggerReaction('İlk');
      await tester.pump();

      Finder richTextContaining(String value) => find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.textSpan?.toPlainText().contains(value) == true,
      );
      expect(richTextContaining('İlk'), findsOneWidget);

      await tester.pumpWidget(overlay(second));
      await tester.pump();
      first.triggerReaction('Eski');
      second.triggerReaction('Yeni');
      await tester.pump();

      expect(richTextContaining('Yeni'), findsOneWidget);
      expect(richTextContaining('Eski'), findsNothing);
    });

    test('reaction IDs are monotonic and unique within one controller', () {
      final controller = FloatingReactionController();

      controller.triggerReaction('👏 Destxweş!');
      controller.triggerReaction('🔥 Agir!');
      controller.triggerReaction('⚡ Lez be!');

      expect(
        controller.activeBubbles.map((bubble) => bubble.id).toList(),
        const ['reaction_0', 'reaction_1', 'reaction_2'],
      );
    });

    test(
      'FloatingReactionController manages reaction bubbles and triggers listeners',
      () {
        final controller = FloatingReactionController();
        expect(controller.activeBubbles, isEmpty);

        controller.triggerReaction('👏 Destxweş!', senderName: 'Berfin');
        expect(controller.activeBubbles.length, 1);
        expect(controller.activeBubbles.first.text, '👏 Destxweş!');
        expect(controller.activeBubbles.first.senderName, 'Berfin');

        final id = controller.activeBubbles.first.id;
        controller.removeReaction(id);
        expect(controller.activeBubbles, isEmpty);
      },
    );

    test(
      'Localization keys for gamification and custom rooms are present in both languages',
      () {
        final keysToCheck = [
          K.customRoomTitle,
          K.selectCategory,
          K.questionCountLabel,
          K.entryFeeLabel,
          K.freeEntry,
          K.insufficientCoins,
          K.entryFeeRequired,
          K.newRoom,
          K.newRoomAction,
          K.newRoomFeeConfirm,
          K.comboMultiplier,
          K.streakFire,
          K.opponentAnswered,
          K.yourTurnFast,
          K.reactionBravo,
          K.reactionGoodLuck,
          K.reactionFast,
          K.reactionSmiley,
          K.reactionFire,
        ];

        for (final key in keysToCheck) {
          final ku = Tr.of(key, AppLanguage.ku);
          final tr = Tr.of(key, AppLanguage.tr);
          expect(ku.isNotEmpty, true, reason: '$key missing for ku');
          expect(tr.isNotEmpty, true, reason: '$key missing for tr');
        }
      },
    );
  });
}
