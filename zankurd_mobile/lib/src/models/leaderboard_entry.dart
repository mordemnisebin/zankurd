class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.totalScore,
    required this.bestStreak,
    required this.roomsPlayed,
    this.avatarIcon,
    this.avatarColor,
    this.avatarUrl,
    this.avatarFrame,
    this.showcaseTitle,
  });

  final int rank;
  final String playerId;
  final String displayName;
  final int totalScore;
  final int bestStreak;
  final int roomsPlayed;

  // Kozmetik vitrin alanları; eski sorgular döndürmediğinde null kalır ve
  // görünüm baş-harf avatarına düşer (PlayerAvatar fallback zinciri).
  final String? avatarIcon;
  final String? avatarColor;
  final String? avatarUrl;
  final String? avatarFrame;
  final String? showcaseTitle;
}
