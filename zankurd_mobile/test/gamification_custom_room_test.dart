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
