import 'package:firebase_analytics/firebase_analytics.dart';

/// Analytics event tracker — Firebase Analytics'e unified interface
class AnalyticsTracker {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // ============================================================================
  // CATEGORY SELECTION & QUIZ FLOW
  // ============================================================================

  /// Kullanıcı kategori seçer ve quiz'i başlatır
  static Future<void> trackCategorySelected(String categoryName) async {
    await _analytics.logEvent(
      name: 'category_selected',
      parameters: {
        'category': categoryName,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Kullanıcı seviye seçer (kategori içinde)
  static Future<void> trackLevelSelected(
    String categoryName,
    int difficultyMin,
    int difficultyMax,
  ) async {
    await _analytics.logEvent(
      name: 'level_selected',
      parameters: {
        'category': categoryName,
        'difficulty_range': '$difficultyMin-$difficultyMax',
      },
    );
  }

  // ============================================================================
  // WILDCARD / JOKER USAGE
  // ============================================================================

  /// Kullanıcı joker (wildcard) kullanır
  static Future<void> trackWildcardUsed(
    String wildcardType,
    int coinCost,
  ) async {
    await _analytics.logEvent(
      name: 'wildcard_used',
      parameters: {
        'wildcard_type':
            wildcardType, // '50_50', 'audience', 'double_answer', 'question_change'
        'coin_cost': coinCost,
      },
    );
  }

  // ============================================================================
  // MISSION / DAILY MISSION EVENTS
  // ============================================================================

  /// Günlük görev tamamlandı
  static Future<void> trackMissionCompleted(
    String missionType,
    int coinReward,
    int xpReward,
  ) async {
    await _analytics.logEvent(
      name: 'mission_completed',
      parameters: {
        'mission_type':
            missionType, // 'answer_correct', 'complete_quiz', 'use_wildcard', etc.
        'coin_reward': coinReward,
        'xp_reward': xpReward,
      },
    );
  }

  /// Günlük görev ödülü talep edildi
  static Future<void> trackMissionRewardClaimed(
    String missionKey,
    int coinAmount,
  ) async {
    await _analytics.logEvent(
      name: 'mission_reward_claimed',
      parameters: {'mission_key': missionKey, 'coin_amount': coinAmount},
    );
  }

  // ============================================================================
  // LEADERBOARD & COMPETITION
  // ============================================================================

  /// Liderlik tablosunu görüntüle
  static Future<void> trackLeaderboardViewed(String period) async {
    await _analytics.logEvent(
      name: 'leaderboard_viewed',
      parameters: {
        'period': period, // 'weekly', 'monthly', 'all_time'
      },
    );
  }

  /// Turnuva başladı
  static Future<void> trackTournamentStarted() async {
    await _analytics.logEvent(name: 'tournament_started');
  }

  /// Turnuva bölümüne ulaştı
  static Future<void> trackTournamentStageReached(String stage) async {
    await _analytics.logEvent(
      name: 'tournament_stage_reached',
      parameters: {
        'stage': stage, // 'quarter', 'semi', 'final', 'champion'
      },
    );
  }

  // ============================================================================
  // AVATAR & PROFILE CUSTOMIZATION
  // ============================================================================

  /// Avatar özelleştirmesi değişti
  static Future<void> trackAvatarCustomized(String customizationType) async {
    await _analytics.logEvent(
      name: 'avatar_customized',
      parameters: {
        'customization_type':
            customizationType, // 'icon', 'color', 'photo', 'frame', 'title'
      },
    );
  }

  /// Profil adı güncellendi
  static Future<void> trackProfileNameUpdated() async {
    await _analytics.logEvent(name: 'profile_name_updated');
  }

  // ============================================================================
  // MASTERY & PROGRESSION
  // ============================================================================

  /// Mastery seviyesi yükseldi
  static Future<void> trackMasteryPromoted(
    String categoryName,
    String masteryLevel,
  ) async {
    await _analytics.logEvent(
      name: 'mastery_promoted',
      parameters: {
        'category': categoryName,
        'mastery_level': masteryLevel, // 'xwendekar', 'pispor', 'mamoste'
      },
    );
  }

  // ============================================================================
  // CONTEST & EVENTS
  // ============================================================================

  /// Contest/Etkinlik katılımı
  static Future<void> trackContestJoined(String contestId) async {
    await _analytics.logEvent(
      name: 'contest_joined',
      parameters: {'contest_id': contestId},
    );
  }

  /// Contest ödülü talep edildi
  static Future<void> trackContestRewardClaimed(
    String contestId,
    int coinReward,
  ) async {
    await _analytics.logEvent(
      name: 'contest_reward_claimed',
      parameters: {'contest_id': contestId, 'coin_reward': coinReward},
    );
  }

  // ============================================================================
  // LEARNING ZONE
  // ============================================================================

  /// Ders kategorisini seç
  static Future<void> trackLessonCategoryViewed(String category) async {
    await _analytics.logEvent(
      name: 'lesson_category_viewed',
      parameters: {'category': category},
    );
  }

  /// Dersi tamamla
  static Future<void> trackLessonCompleted(String lessonSlug) async {
    await _analytics.logEvent(
      name: 'lesson_completed',
      parameters: {'lesson_slug': lessonSlug},
    );
  }

  // ============================================================================
  // SOCIAL / SHARING
  // ============================================================================

  /// Quiz sonucunu paylaş
  static Future<void> trackResultShared(String shareMethod) async {
    await _analytics.logEvent(
      name: 'result_shared',
      parameters: {
        'share_method':
            shareMethod, // 'sms', 'email', 'whatsapp', 'facebook', etc.
      },
    );
  }

  // ============================================================================
  // MONETIZATION
  // ============================================================================

  /// Spin wheel çevrildi
  static Future<void> trackSpinWheelSpun(int rewardCoins) async {
    await _analytics.logEvent(
      name: 'spin_wheel_spun',
      parameters: {'reward_coins': rewardCoins},
    );
  }

  /// Coin harcandı
  static Future<void> trackCoinSpent(int amount, String reason) async {
    await _analytics.logEvent(
      name: 'coin_spent',
      parameters: {
        'amount': amount,
        'reason': reason, // 'wildcard', 'shop', etc.
      },
    );
  }

  // ============================================================================
  // ERROR TRACKING
  // ============================================================================

  /// İşlem hatalı oldu (failsafe)
  static Future<void> trackError(String errorType, String message) async {
    await _analytics.logEvent(
      name: 'error_occurred',
      parameters: {'error_type': errorType, 'message': message},
    );
  }
}
