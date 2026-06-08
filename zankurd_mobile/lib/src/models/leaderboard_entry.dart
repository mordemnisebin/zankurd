class LeaderboardEntry {
  const LeaderboardEntry({
    required this.rank,
    required this.playerId,
    required this.displayName,
    required this.totalScore,
    required this.bestStreak,
    required this.roomsPlayed,
  });

  final int rank;
  final String playerId;
  final String displayName;
  final int totalScore;
  final int bestStreak;
  final int roomsPlayed;
}
