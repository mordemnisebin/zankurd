import 'leaderboard_entry.dart';

/// Haftalık lig (Duolingo tarzı küme). Sunucu: `get_my_league()`
/// (`supabase/2026-11-05_haftalik_lig.sql`). Eski [LeagueTier] (3 kademe,
/// canlı sıradan türetilen sunum) ile karışmasın: bu, sunucunun kümesidir.
///
/// Kademe sayısı sunucuda `0..4`: Bronz, Gümüş, Altın, Elmas, Efsane. Adlar
/// istemci metinleridir (`K.lgTier*`); sunucu yalnız indeks taşır.
const int kLeagueTierCount = 5;

/// Kümedeki bir oyuncu. Sıra, kümenin GERÇEK sırasıdır (engellenenler listeden
/// çıkar ama numara kaymaz; bölgeler bozulmaz).
class LeagueMember {
  const LeagueMember({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.score,
    required this.isMe,
    this.avatarIcon,
    this.avatarColor,
    this.avatarUrl,
    this.avatarFrame,
  });

  factory LeagueMember.fromJson(Map<String, dynamic> json) => LeagueMember(
    rank: (json['rank'] as num?)?.toInt() ?? 0,
    playerId: json['player_id'] as String? ?? '',
    displayName: json['display_name'] as String? ?? 'Oyuncu',
    score: (json['score'] as num?)?.toInt() ?? 0,
    isMe: json['is_me'] as bool? ?? false,
    avatarIcon: json['avatar_icon'] as String?,
    avatarColor: json['avatar_color'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    avatarFrame: json['avatar_frame'] as String?,
  );

  final int rank;
  final String playerId;
  final String displayName;
  final int score;
  final bool isMe;
  final String? avatarIcon;
  final String? avatarColor;
  final String? avatarUrl;
  final String? avatarFrame;

  /// Ortak sıra satırı bileşeni için.
  LeaderboardEntry toEntry() => LeaderboardEntry(
    rank: rank,
    playerId: playerId,
    displayName: displayName,
    totalScore: score,
    bestStreak: 0,
    roomsPlayed: 0,
    avatarIcon: avatarIcon,
    avatarColor: avatarColor,
    avatarUrl: avatarUrl,
    avatarFrame: avatarFrame,
  );
}

enum LeagueOutcome { promoted, demoted, stayed }

/// Geçen haftanın (henüz görülmemiş) sonucu: "Altın lige yükseldin!".
class LeagueResult {
  const LeagueResult({
    required this.outcome,
    required this.fromTier,
    required this.toTier,
    this.rank,
  });

  static LeagueResult? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final outcome = switch (raw['outcome']) {
      'promoted' => LeagueOutcome.promoted,
      'demoted' => LeagueOutcome.demoted,
      'stayed' => LeagueOutcome.stayed,
      _ => null,
    };
    if (outcome == null) return null;
    final from = (raw['from_tier'] as num?)?.toInt() ?? 0;
    return LeagueResult(
      outcome: outcome,
      fromTier: from,
      toTier: (raw['to_tier'] as num?)?.toInt() ?? from,
      rank: (raw['rank'] as num?)?.toInt(),
    );
  }

  final LeagueOutcome outcome;
  final int fromTier;
  final int toTier;
  final int? rank;
}

class WeeklyLeague {
  const WeeklyLeague({
    required this.tier,
    required this.joined,
    required this.secondsLeft,
    required this.cohortSize,
    required this.promoteCount,
    required this.demoteCount,
    required this.myRank,
    required this.myScore,
    required this.members,
    this.lastResult,
  });

  factory WeeklyLeague.fromJson(Map<String, dynamic> json) {
    final members = [
      for (final m in (json['members'] as List<dynamic>? ?? const []))
        if (m is Map) LeagueMember.fromJson(Map<String, dynamic>.from(m)),
    ];
    return WeeklyLeague(
      tier: ((json['tier'] as num?)?.toInt() ?? 0).clamp(
        0,
        kLeagueTierCount - 1,
      ),
      joined: json['joined'] as bool? ?? false,
      secondsLeft: (json['seconds_left'] as num?)?.toInt() ?? 0,
      cohortSize: (json['cohort_size'] as num?)?.toInt() ?? members.length,
      promoteCount: (json['promote_count'] as num?)?.toInt() ?? 0,
      demoteCount: (json['demote_count'] as num?)?.toInt() ?? 0,
      myRank: (json['my_rank'] as num?)?.toInt(),
      myScore: (json['my_score'] as num?)?.toInt() ?? 0,
      members: members,
      lastResult: LeagueResult.fromJson(json['last_result']),
    );
  }

  final int tier;

  /// Oyuncu bu hafta bir kümeye girdi mi (haftada ilk puandan sonra).
  final bool joined;
  final int secondsLeft;
  final int cohortSize;
  final int promoteCount;
  final int demoteCount;
  final int? myRank;
  final int myScore;
  final List<LeagueMember> members;
  final LeagueResult? lastResult;

  /// Sıra, çıkma bölgesinde mi (ilk [promoteCount]).
  bool inPromotionZone(int rank) => promoteCount > 0 && rank <= promoteCount;

  /// Sıra, düşme bölgesinde mi (son [demoteCount]; küme boyutu kadar).
  bool inDemotionZone(int rank) =>
      demoteCount > 0 && rank > cohortSize - demoteCount;
}
