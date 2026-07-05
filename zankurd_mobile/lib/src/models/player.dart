class Player {
  const Player({
    this.id,
    required this.name,
    required this.score,
    required this.state,
    this.streak = 0,
    this.avatarIcon,
    this.avatarColor,
    this.avatarUrl,
    this.avatarFrame,
    this.showcaseTitle,
  });

  final String? id;
  final String name;
  final int score;
  final String state;
  final int streak;

  // Kozmetik vitrin alanları (1v1/oda ekranlarında rakip avatarı için);
  // sunucu döndürmediğinde null kalır, baş-harf avatarına düşülür.
  final String? avatarIcon;
  final String? avatarColor;
  final String? avatarUrl;
  final String? avatarFrame;
  final String? showcaseTitle;

  Player copyWith({
    String? id,
    String? name,
    int? score,
    String? state,
    int? streak,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      score: score ?? this.score,
      state: state ?? this.state,
      streak: streak ?? this.streak,
      avatarIcon: avatarIcon,
      avatarColor: avatarColor,
      avatarUrl: avatarUrl,
      avatarFrame: avatarFrame,
      showcaseTitle: showcaseTitle,
    );
  }
}
