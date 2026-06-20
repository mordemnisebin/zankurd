import 'dart:math';

enum MissionType {
  answerCorrect,
  completeQuiz,
  useWildcard,
  keepStreak,
  playCategory,
}

class DailyMission {
  DailyMission({
    required this.type,
    required this.target,
    required this.coinReward,
    this.category,
    this.progress = 0,
    this.completed = false,
  });

  final MissionType type;
  final int target;
  final int coinReward;
  final String? category;
  int progress;
  bool completed;

  String get labelKu => switch (type) {
        MissionType.answerCorrect => '$target bersivên rast bide',
        MissionType.completeQuiz => '$target pêşbirk biqedîne',
        MissionType.useWildcard => '$target joker bikar bîne',
        MissionType.keepStreak => 'Seriya xwe biparêze',
        MissionType.playCategory => 'Di ${category ?? '?'} de bilîze',
      };

  String get labelTr => switch (type) {
        MissionType.answerCorrect => '$target doğru cevap ver',
        MissionType.completeQuiz => '$target quiz tamamla',
        MissionType.useWildcard => '$target joker kullan',
        MissionType.keepStreak => 'Serisini koru',
        MissionType.playCategory => '${category ?? '?'} kategorisinde oyna',
      };
}

class MissionDef {
  const MissionDef({
    required this.type,
    required this.target,
    required this.coinReward,
    this.category,
  });

  final MissionType type;
  final int target;
  final int coinReward;
  final String? category;
}

class MissionDefinitions {
  static const List<MissionDef> pool = [
    MissionDef(type: MissionType.answerCorrect, target: 5, coinReward: 30),
    MissionDef(type: MissionType.answerCorrect, target: 10, coinReward: 50),
    MissionDef(type: MissionType.answerCorrect, target: 15, coinReward: 75),
    MissionDef(type: MissionType.completeQuiz, target: 1, coinReward: 25),
    MissionDef(type: MissionType.completeQuiz, target: 3, coinReward: 60),
    MissionDef(type: MissionType.useWildcard, target: 1, coinReward: 20),
    MissionDef(type: MissionType.useWildcard, target: 2, coinReward: 40),
    MissionDef(type: MissionType.keepStreak, target: 1, coinReward: 30),
    MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Ziman',
    ),
    MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Çand',
    ),
    MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Dîrok',
    ),
    MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Edebiyat',
    ),
    MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Cografya',
    ),
    MissionDef(
      type: MissionType.playCategory,
      target: 1,
      coinReward: 25,
      category: 'Muzîk',
    ),
  ];

  /// Verilen gün tohumundan 3 görev üretir. Aynı gün = aynı 3 görev.
  static List<DailyMission> forDay(DateTime day) {
    final seed = day.year * 10000 + day.month * 100 + day.day;
    final rng = Random(seed);
    final shuffled = List<MissionDef>.from(pool)..shuffle(rng);
    return shuffled
        .take(3)
        .map(
          (def) => DailyMission(
            type: def.type,
            target: def.target,
            coinReward: def.coinReward,
            category: def.category,
          ),
        )
        .toList();
  }
}
