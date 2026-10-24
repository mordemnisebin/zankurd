import 'package:flutter/foundation.dart';

/// Günlük contest/etkinlik teması
@immutable
class Contest {
  final String id;
  final DateTime dayKey;
  final String themeNameKu;
  final String? themeDescriptionKu;

  /// Tema adının Türkçesi. Yoksa Kurmancî'ye düşülür.
  ///
  /// Alan yokken günün etkinliği Türkçe arayüzde de "Ziman Eksperi" diye
  /// görünüyordu: kategori çipi "Dil" derken hemen üstündeki başlık
  /// Kurmancî kalıyordu (2026-07-26 denetimi). `QuizQuestion` ile aynı
  /// desen — çok dilli alan opsiyoneldir, eksikse dil değil içerik düşer.
  final String? themeNameTr;
  final String? themeDescriptionTr;
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
    this.themeNameTr,
    this.themeDescriptionTr,
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
    String? themeNameTr,
    String? themeDescriptionTr,
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
    themeNameTr: themeNameTr ?? this.themeNameTr,
    themeDescriptionTr: themeDescriptionTr ?? this.themeDescriptionTr,
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
    if (themeNameTr != null) 'theme_name_tr': themeNameTr,
    if (themeDescriptionTr != null) 'theme_description_tr': themeDescriptionTr,
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
    dayKey:
        DateTime.tryParse(json['day_key'] as String? ?? '') ?? DateTime.now(),
    themeNameKu: json['theme_name_ku'] as String,
    themeDescriptionKu: json['theme_description_ku'] as String?,
    themeNameTr: json['theme_name_tr'] as String?,
    themeDescriptionTr: json['theme_description_tr'] as String?,
    category: json['category'] as String,
    difficultyMin: json['difficulty_min'] as int? ?? 1,
    difficultyMax: json['difficulty_max'] as int? ?? 5,
    participationReward: json['participation_reward'] as int? ?? 10,
    rank1Reward: json['rank1_reward'] as int? ?? 500,
    rank2Reward: json['rank2_reward'] as int? ?? 300,
    rank3Reward: json['rank3_reward'] as int? ?? 100,
    questionCount: json['question_count'] as int? ?? 10,
  );

  /// Arayüz diline göre tema adı; çeviri yoksa Kurmancî döner.
  String themeNameFor({required bool isKu}) {
    if (isKu) return themeNameKu;
    final turkish = themeNameTr?.trim();
    return (turkish == null || turkish.isEmpty) ? themeNameKu : turkish;
  }

  /// Arayüz diline göre tema açıklaması; çeviri yoksa Kurmancî döner.
  String? themeDescriptionFor({required bool isKu}) {
    if (isKu) return themeDescriptionKu;
    final turkish = themeDescriptionTr?.trim();
    return (turkish == null || turkish.isEmpty) ? themeDescriptionKu : turkish;
  }

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
    finishedAt: DateTime.tryParse(json['finished_at'] as String? ?? ''),
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
        finishedAt: DateTime.tryParse(json['finished_at'] as String? ?? ''),
      );
}

/// "Bugünün sıralaması" satırı: yalnız herkese açık gösterim verisi.
@immutable
class DailyEventEntry {
  const DailyEventEntry({
    required this.rank,
    required this.name,
    required this.correct,
    required this.total,
    required this.seconds,
    this.isMe = false,
  });

  final int rank;
  final String name;
  final int correct;
  final int total;
  final int seconds;
  final bool isMe;

  static DailyEventEntry? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    // Sunucudan gelen veri: yanlış tipli alan fırlatmaz, satırı atlatır.
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    final rank = asInt(json['rank']);
    final correct = asInt(json['correct']);
    final total = asInt(json['total']);
    if (rank == null || correct == null || total == null) return null;
    final rawName = json['name'];
    final name = rawName is String ? rawName.trim() : null;
    return DailyEventEntry(
      rank: rank,
      name: (name == null || name.isEmpty) ? 'Oyuncu' : name,
      correct: correct,
      total: total,
      seconds: asInt(json['seconds']) ?? 0,
      isMe: json['is_me'] == true,
    );
  }

  /// `m:ss` (62 sn -> `1:02`).
  String get timeLabel =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// Günün yarışmasının sonuç panosu (`get_daily_event_board`).
@immutable
class DailyEventBoard {
  const DailyEventBoard({
    this.top = const [],
    this.me,
    this.yesterdayWinner,
    this.participants = 0,
  });

  /// Bugünün ilk üçü (sıra sırasıyla).
  final List<DailyEventEntry> top;

  /// Çağıranın bugünkü satırı; bugün bitirmediyse null.
  final DailyEventEntry? me;

  /// Dünün birincisi; dün kimse bitirmediyse null.
  final DailyEventEntry? yesterdayWinner;
  final int participants;

  static DailyEventBoard? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final topRaw = json['top'];
    return DailyEventBoard(
      top: [
        if (topRaw is List)
          for (final item in topRaw) ?DailyEventEntry.tryParse(item),
      ],
      me: DailyEventEntry.tryParse(json['me']),
      yesterdayWinner: DailyEventEntry.tryParse(json['yesterday']),
      participants: switch (json['participants']) {
        final num n => n.toInt(),
        _ => 0,
      },
    );
  }
}

/// Günün yarışmasının bir sonraki sıfırlanma anı (UTC).
///
/// Sunucu günü `app_today()` = Europe/Istanbul takvim günüdür
/// (`2026-10-24_gunun_yarismasi_sonuc.sql`); Türkiye yıl boyu UTC+3'tür
/// (yaz saati yok), yani sınır her gün 21:00 UTC'dir. Cihazın saat dilimi
/// bilerek kullanılmaz: Almanya'daki oyuncu için de sıralama Türkiye
/// gece yarısı kapanır.
DateTime nextContestResetAt(DateTime now) {
  final shifted = now.toUtc().add(const Duration(hours: 3));
  final nextMidnight = DateTime.utc(
    shifted.year,
    shifted.month,
    shifted.day + 1,
  );
  return nextMidnight.subtract(const Duration(hours: 3));
}

/// [now]'dan sıfırlanmaya kalan süre, dakikaya YUKARI yuvarlanmış: kalan
/// "0 sa 0 dk" gösterilmez, 59 sn kala "1 dk" denir.
({int hours, int minutes}) contestResetCountdown(DateTime now) {
  final left = nextContestResetAt(now).difference(now.toUtc());
  final totalMinutes = (left.inSeconds + 59) ~/ 60;
  return (hours: totalMinutes ~/ 60, minutes: totalMinutes % 60);
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
        earnedAt:
            DateTime.tryParse(json['earned_at'] as String? ?? '') ??
            DateTime.now(),
      );

  @override
  String toString() =>
      'UserContestBadge(user: $userId, badge: $badgeId, earned: $earnedAt)';
}
