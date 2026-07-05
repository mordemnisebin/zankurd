import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/game/avatar_frames.dart';

void main() {
  group('unlockedFrames', () {
    test('hiç rozet ve mastery yokken boş küme', () {
      expect(
        unlockedFrames(unlockedBadgeCount: 0, masteryCorrectByCategory: {}),
        isEmpty,
      );
    });

    test('1 rozet bronzu açar', () {
      expect(
        unlockedFrames(unlockedBadgeCount: 1, masteryCorrectByCategory: {}),
        {AvatarFrame.bronze},
      );
    });

    test('5 rozet gümüşü de açar', () {
      expect(
        unlockedFrames(unlockedBadgeCount: 5, masteryCorrectByCategory: {}),
        {AvatarFrame.bronze, AvatarFrame.silver},
      );
    });

    test('herhangi kategoride Pispor (100+) altını açar', () {
      expect(
        unlockedFrames(
          unlockedBadgeCount: 0,
          masteryCorrectByCategory: {'Ziman': 100},
        ),
        {AvatarFrame.gold},
      );
      expect(
        unlockedFrames(
          unlockedBadgeCount: 0,
          masteryCorrectByCategory: {'Ziman': 99},
        ),
        isEmpty,
      );
    });

    test('Mamoste (400+) mamoste çerçevesini açar', () {
      expect(
        unlockedFrames(
          unlockedBadgeCount: 2,
          masteryCorrectByCategory: {'Dîrok': 400, 'Ziman': 50},
        ),
        {AvatarFrame.bronze, AvatarFrame.gold, AvatarFrame.mamoste},
      );
    });
  });

  group('frameColor', () {
    test('her çerçevenin bir rengi var', () {
      for (final frame in AvatarFrame.values) {
        expect(frameColor(frame), isNotNull);
      }
    });
  });

  group('frameFromId', () {
    test('bilinen kimlik çözülür, bilinmeyen null', () {
      expect(frameFromId('gold'), AvatarFrame.gold);
      expect(frameFromId('yok'), isNull);
      expect(frameFromId(null), isNull);
    });
  });
}
