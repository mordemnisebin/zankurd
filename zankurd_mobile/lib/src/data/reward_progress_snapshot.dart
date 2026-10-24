import '../models/achievement.dart';
import '../utils/error_reporter.dart';
import 'achievement_store.dart';
import 'badge_service.dart';
import 'streak_store.dart';

/// Başarı ve rozetlerin ilerleme/tarih görünümü (profildeki "Tüm başarılar").
///
/// İki depodaki kimlikler ayrıktır (`first_game`… / `streak_30`…), bu yüzden
/// tek haritada birleşirler. YALNIZ OKUR: açılma kuralları depolarda durur.
class RewardProgressSnapshot {
  const RewardProgressSnapshot({
    this.progress = const {},
    this.unlockedOn = const {},
  });

  final Map<String, RewardProgress> progress;
  final Map<String, DateTime> unlockedOn;

  /// [dailyStreak] verilmezse `StreakStore`dan okunur; okunamazsa 0.
  static Future<RewardProgressSnapshot> load({
    required AchievementStore achievements,
    required BadgeService badges,
    int? dailyStreak,
  }) async {
    var streak = dailyStreak ?? 0;
    if (dailyStreak == null) {
      try {
        streak = (await StreakStore.load()).effectiveStreak();
      } catch (error, stack) {
        ErrorReporter.record(error, stack, reason: 'reward progress streak');
      }
    }
    final progress = <String, RewardProgress>{};
    final unlockedOn = <String, DateTime>{};
    for (final def in AchievementStore.definitions) {
      final value = achievements.progressFor(def.id, dailyStreak: streak);
      if (value != null) progress[def.id] = value;
      final day = achievements.unlockedAt(def.id);
      if (day != null) unlockedOn[def.id] = day;
    }
    for (final id in BadgeService.badgeDefinitions.keys) {
      final value = badges.progressFor(
        id,
        answeredQuestions: achievements.answeredQuestions,
        dailyStreak: streak,
      );
      if (value != null) progress[id] = value;
      final day = badges.unlockedAt(id);
      if (day != null) unlockedOn[id] = day;
    }
    return RewardProgressSnapshot(progress: progress, unlockedOn: unlockedOn);
  }
}
