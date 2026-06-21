import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    BadgeService.resetInstance();
  });

  group('BadgeService', () {
    test('başlangıçta hiç rozet açılmamıştır', () async {
      final service = await BadgeService.load();
      expect(service.unlockedCount, 0);
      expect(service.totalCount, BadgeService.badgeDefinitions.length);
    });

    test('30 günlük streak rozeti açılır', () async {
      final service = await BadgeService.load();
      final newBadges = await service.evaluateStreakBadges(30);
      expect(newBadges, contains('streak_30'));
      expect(service.isUnlocked('streak_30'), true);
    });

    test('30 altı streak rozet açmaz', () async {
      final service = await BadgeService.load();
      final newBadges = await service.evaluateStreakBadges(29);
      expect(newBadges, isEmpty);
      expect(service.isUnlocked('streak_30'), false);
    });

    test('500 soru rozeti açılır', () async {
      final service = await BadgeService.load();
      final newBadges = await service.evaluateQuestionBadges(500);
      expect(newBadges, contains('questions_500'));
      expect(service.isUnlocked('questions_500'), true);
    });

    test('1000 soru rozeti açılır (500 de açılır)', () async {
      final service = await BadgeService.load();
      final newBadges = await service.evaluateQuestionBadges(1000);
      expect(newBadges, contains('questions_500'));
      expect(newBadges, contains('questions_1000'));
    });

    test('mükemmel oyun rozeti açılır', () async {
      final service = await BadgeService.load();
      final result = await service.evaluatePerfectGame(10, 10);
      expect(result, true);
      expect(service.isUnlocked('perfect_game'), true);
    });

    test('mükemmel olmayan oyun rozet açmaz', () async {
      final service = await BadgeService.load();
      final result = await service.evaluatePerfectGame(9, 10);
      expect(result, false);
      expect(service.isUnlocked('perfect_game'), false);
    });

    test('hız canavarı rozeti 60 saniyenin altında açılır', () async {
      final service = await BadgeService.load();
      final result = await service.evaluateSpeedDemon(
        const Duration(seconds: 45),
      );
      expect(result, true);
      expect(service.isUnlocked('speed_demon'), true);
    });

    test('hız canavarı 60 saniye ve üstünde açılmaz', () async {
      final service = await BadgeService.load();
      final result = await service.evaluateSpeedDemon(
        const Duration(seconds: 60),
      );
      expect(result, false);
    });

    test('aynı rozet iki kez açılmaz', () async {
      final service = await BadgeService.load();
      await service.evaluateStreakBadges(30);
      final secondRun = await service.evaluateStreakBadges(30);
      expect(secondRun, isEmpty);
      expect(service.unlockedCount, 1);
    });
  });
}
