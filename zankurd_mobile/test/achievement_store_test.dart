import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/models/player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AchievementStore.resetInstance();
  });

  test(
    'first completed quiz unlocks the first game achievement once',
    () async {
      final store = await AchievementStore.load();

      final firstUnlocks = await store.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 3,
        correctCount: 2,
        bestStreak: 2,
        dailyStreak: 1,
        userScore: 230,
      );
      final secondUnlocks = await store.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 3,
        correctCount: 1,
        bestStreak: 1,
        dailyStreak: 1,
        userScore: 100,
      );

      expect(firstUnlocks.map((achievement) => achievement.id), [
        AchievementIds.firstGame,
      ]);
      expect(secondUnlocks, isEmpty);
      expect(store.isUnlocked(AchievementIds.firstGame), isTrue);
    },
  );

  test('tracks cumulative question and daily quiz milestones', () async {
    final store = await AchievementStore.load();

    for (var i = 0; i < 4; i++) {
      await store.recordQuizResult(
        category: 'Ziman',
        totalQuestions: 20,
        correctCount: 10,
        bestStreak: 3,
        dailyStreak: 1,
        userScore: 1000,
        dailyQuiz: true,
      );
    }
    final unlocks = await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 20,
      correctCount: 10,
      bestStreak: 3,
      dailyStreak: 1,
      userScore: 1000,
      dailyQuiz: true,
    );

    final ids = unlocks.map((achievement) => achievement.id).toSet();
    expect(ids, contains(AchievementIds.hundredQuestions));
    expect(ids, contains(AchievementIds.dailyQuizFive));
  });

  test('unlocks category, streak, mistake, and bot achievements', () async {
    final store = await AchievementStore.load();
    final allUnlocks = <String>{};

    for (final category in AchievementStore.requiredCategories) {
      final unlocks = await store.recordQuizResult(
        category: category,
        totalQuestions: 1,
        correctCount: 1,
        bestStreak: 1,
        dailyStreak: 1,
        userScore: 100,
      );
      allUnlocks.addAll(unlocks.map((achievement) => achievement.id));
    }
    final unlocks = await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 10,
      correctCount: 10,
      bestStreak: 10,
      dailyStreak: 7,
      userScore: 1200,
      practice: true,
      remainingMistakes: 0,
      opponents: const [
        Player(name: 'Rojda', score: 900, state: 'Bot'),
        Player(name: 'Baran', score: 700, state: 'Bot'),
      ],
    );

    final ids = {
      ...allUnlocks,
      ...unlocks.map((achievement) => achievement.id),
    };
    expect(ids, contains(AchievementIds.allCategories));
    expect(ids, contains(AchievementIds.tenStreak));
    expect(ids, contains(AchievementIds.sevenDayStreak));
    expect(ids, contains(AchievementIds.mistakesCleared));
    expect(ids, contains(AchievementIds.botWinner));
  });

  test('persists unlocked achievements across instances', () async {
    final store = await AchievementStore.load();
    await store.recordQuizResult(
      category: 'Ziman',
      totalQuestions: 3,
      correctCount: 2,
      bestStreak: 2,
      dailyStreak: 1,
      userScore: 230,
    );

    AchievementStore.resetInstance();
    final restored = await AchievementStore.load();

    expect(restored.isUnlocked(AchievementIds.firstGame), isTrue);
    expect(restored.unlockedAchievements.length, 1);
  });
}
