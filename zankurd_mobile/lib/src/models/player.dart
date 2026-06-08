class Player {
  const Player({
    this.id,
    required this.name,
    required this.score,
    required this.state,
    this.streak = 0,
  });

  final String? id;
  final String name;
  final int score;
  final String state;
  final int streak;

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
    );
  }
}
