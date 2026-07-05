import 'package:flutter/foundation.dart';

/// Günlük contest/etkinlik teması
@immutable
class Contest {
  final String id;
  final DateTime dayKey;
  final String themeNameKu;
  final String? themeDescriptionKu;
  final String category;
  final int difficultyMin;
  final int difficultyMax;
  final int participationReward;
  final int rank1Reward;
  final int rank2Reward;
  final int rank3Reward;
  final int questionCount;

  const Contest({
    required this.id,
    required this.dayKey,
    required this.themeNameKu,
    this.themeDescriptionKu,
    required this.category,
    this.difficultyMin = 1,
    this.difficultyMax = 5,
    this.participationReward = 10,
    this.rank1Reward = 500,
    this.rank2Reward = 300,
    this.rank3Reward = 100,
    this.questionCount = 10,
  });

  Contest copyWith({
    String? id,
    DateTime? dayKey,
    String? themeNameKu,
    String? themeDescriptionKu,
    String? category,
    int? difficultyMin,
    int? difficultyMax,
    int? participationReward,
    int? rank1Reward,
    int? rank2Reward,
    int? rank3Reward,
    int? questionCount,
  }) => Contest(
    id: id ?? this.id,
    dayKey: dayKey ?? this.dayKey,
    themeNameKu: themeNameKu ?? this.themeNameKu,
    themeDescriptionKu: themeDescriptionKu ?? this.themeDescriptionKu,
    category: category ?? this.category,
    difficultyMin: difficultyMin ?? this.difficultyMin,
    difficultyMax: difficultyMax ?? this.difficultyMax,
    participationReward: participationReward ?? this.participationReward,
    rank1Reward: rank1Reward ?? this.rank1Reward,
    rank2Reward: rank2Reward ?? this.rank2Reward,
    rank3Reward: rank3Reward ?? this.rank3Reward,
    questionCount: questionCount ?? this.questionCount,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'day_key': dayKey.toIso8601String(),
    'theme_name_ku': themeNameKu,
    'theme_description_ku': themeDescriptionKu,
    'category': category,
    'difficulty_min': difficultyMin,
    'difficulty_max': difficultyMax,
    'participation_reward': participationReward,
    'rank1_reward': rank1Reward,
    'rank2_reward': rank2Reward,
    'rank3_reward': rank3Reward,
    'question_count': questionCount,
  };

  static Contest fromJson(Map<String, dynamic> json) => Contest(
    id: json['id'] as String,
    dayKey: DateTime.parse(json['day_key'] as String),
    themeNameKu: json['theme_name_ku'] as String,
    themeDescriptionKu: json['theme_description_ku'] as String?,
    category: json['category'] as String,
    difficultyMin: json['difficulty_min'] as int? ?? 1,
    difficultyMax: json['difficulty_max'] as int? ?? 5,
    participationReward: json['participation_reward'] as int? ?? 10,
    rank1Reward: json['rank1_reward'] as int? ?? 500,
    rank2Reward: json['rank2_reward'] as int? ?? 300,
    rank3Reward: json['rank3_reward'] as int? ?? 100,
    questionCount: json['question_count'] as int? ?? 10,
  );

  @override
  String toString() =>
      'Contest(id: $id, theme: $themeNameKu, category: $category, day: $dayKey)';
}

/// Contest katılım sonucu (leaderboard satırı)
@immutable
class ContestEntry {
  final String id;
  final String contestId;
  final String userId;
  final int score;
  final int correctCount;
  final DateTime? finishedAt;
  final int? rank;
  final bool rewardClaimed;

  const ContestEntry({
    required this.id,
    required this.contestId,
    required this.userId,
    this.score = 0,
    this.correctCount = 0,
    this.finishedAt,
    this.rank,
    this.rewardClaimed = false,
  });

  ContestEntry copyWith({
    String? id,
    String? contestId,
    String? userId,
    int? score,
    int? correctCount,
    DateTime? finishedAt,
    int? rank,
    bool? rewardClaimed,
  }) => ContestEntry(
    id: id ?? this.id,
    contestId: contestId ?? this.contestId,
    userId: userId ?? this.userId,
    score: score ?? this.score,
    correctCount: correctCount ?? this.correctCount,
    finishedAt: finishedAt ?? this.finishedAt,
    rank: rank ?? this.rank,
    rewardClaimed: rewardClaimed ?? this.rewardClaimed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'contest_id': contestId,
    'user_id': userId,
    'score': score,
    'correct_count': correctCount,
    'finished_at': finishedAt?.toIso8601String(),
    'rank': rank,
    'reward_claimed': rewardClaimed,
  };

  static ContestEntry fromJson(Map<String, dynamic> json) => ContestEntry(
    id: json['id'] as String,
    contestId: json['contest_id'] as String,
    userId: json['user_id'] as String,
    score: json['score'] as int? ?? 0,
    correctCount: json['correct_count'] as int? ?? 0,
    finishedAt: json['finished_at'] != null
        ? DateTime.parse(json['finished_at'] as String)
        : null,
    rank: json['rank'] as int?,
    rewardClaimed: json['reward_claimed'] as bool? ?? false,
  );

  @override
  String toString() =>
      'ContestEntry(id: $id, score: $score, rank: $rank, claimed: $rewardClaimed)';
}

/// Leaderboard satırı (Contest gözlemci açısından)
@immutable
class ContestLeaderboardRow {
  final String userId;
  final String displayName;
  final int score;
  final int correctCount;
  final int? rank;
  final DateTime? finishedAt;

  const ContestLeaderboardRow({
    required this.userId,
    required this.displayName,
    required this.score,
    required this.correctCount,
    this.rank,
    this.finishedAt,
  });

  static ContestLeaderboardRow fromJson(Map<String, dynamic> json) =>
      ContestLeaderboardRow(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String? ?? 'Misafir',
        score: json['score'] as int? ?? 0,
        correctCount: json['correct_count'] as int? ?? 0,
        rank: json['rank'] as int?,
        finishedAt: json['finished_at'] != null
            ? DateTime.parse(json['finished_at'] as String)
            : null,
      );
}

/// Contest rozeti (badge)
@immutable
class ContestBadge {
  final String id;
  final String slug; // contest_20260705_champion
  final String nameKu;
  final String? descriptionKu;
  final String? iconName;
  final String? colorHex;
  final int tier; // 0=participant, 1=finalist, 2=champion

  const ContestBadge({
    required this.id,
    required this.slug,
    required this.nameKu,
    this.descriptionKu,
    this.iconName,
    this.colorHex,
    this.tier = 0,
  });

  ContestBadge copyWith({
    String? id,
    String? slug,
    String? nameKu,
    String? descriptionKu,
    String? iconName,
    String? colorHex,
    int? tier,
  }) => ContestBadge(
    id: id ?? this.id,
    slug: slug ?? this.slug,
    nameKu: nameKu ?? this.nameKu,
    descriptionKu: descriptionKu ?? this.descriptionKu,
    iconName: iconName ?? this.iconName,
    colorHex: colorHex ?? this.colorHex,
    tier: tier ?? this.tier,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name_ku': nameKu,
    'description_ku': descriptionKu,
    'icon_name': iconName,
    'color_hex': colorHex,
    'tier': tier,
  };

  static ContestBadge fromJson(Map<String, dynamic> json) => ContestBadge(
    id: json['id'] as String,
    slug: json['slug'] as String,
    nameKu: json['name_ku'] as String,
    descriptionKu: json['description_ku'] as String?,
    iconName: json['icon_name'] as String?,
    colorHex: json['color_hex'] as String?,
    tier: json['tier'] as int? ?? 0,
  );

  @override
  String toString() => 'ContestBadge(slug: $slug, name: $nameKu)';
}

/// Kullanıcı kazanılan rozet (timeline/profile)
@immutable
class UserContestBadge {
  final String id;
  final String userId;
  final String badgeId;
  final String contestId;
  final DateTime earnedAt;
  final ContestBadge? badge; // Opt-in denormalization

  const UserContestBadge({
    required this.id,
    required this.userId,
    required this.badgeId,
    required this.contestId,
    required this.earnedAt,
    this.badge,
  });

  UserContestBadge copyWith({
    String? id,
    String? userId,
    String? badgeId,
    String? contestId,
    DateTime? earnedAt,
    ContestBadge? badge,
  }) => UserContestBadge(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    badgeId: badgeId ?? this.badgeId,
    contestId: contestId ?? this.contestId,
    earnedAt: earnedAt ?? this.earnedAt,
    badge: badge ?? this.badge,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'badge_id': badgeId,
    'contest_id': contestId,
    'earned_at': earnedAt.toIso8601String(),
  };

  static UserContestBadge fromJson(Map<String, dynamic> json) =>
      UserContestBadge(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        badgeId: json['badge_id'] as String,
        contestId: json['contest_id'] as String,
        earnedAt: DateTime.parse(json['earned_at'] as String),
      );

  @override
  String toString() =>
      'UserContestBadge(user: $userId, badge: $badgeId, earned: $earnedAt)';
}
