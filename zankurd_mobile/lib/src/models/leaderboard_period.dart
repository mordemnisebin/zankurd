enum LeaderboardPeriod {
  daily(days: 1),
  weekly(days: 7),
  monthly(days: 30);

  const LeaderboardPeriod({required this.days});
  final int days;
}
