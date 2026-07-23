import 'dart:math';

import '../config/bot_names.dart';
import '../models/player.dart';

/// Tek kişilik yarışta insan hissi veren simüle rakip.
///
/// Her soruda, sorunun zorluğuna ve botun beceri katsayısına göre
/// doğru cevap olasılığı hesaplanır. Puanlama, oyuncunun yerel
/// fallback puanlamasıyla aynıdır (100 + seri bonusu).
class BotOpponent {
  BotOpponent({required this.name, required this.skill, Random? random})
    : _random = random ?? Random();

  final String name;

  /// 0-1 arası beceri; 0.85 güçlü, 0.55 zayıf rakip demektir.
  final double skill;
  final Random _random;

  int score = 0;
  int streak = 0;
  int correctCount = 0;

  /// Botun verilen zorluktaki soruya cevabını simüle eder.
  bool answer(int difficulty) {
    final probability = (skill - (difficulty - 1) * 0.07).clamp(0.15, 0.95);
    final correct = _random.nextDouble() < probability;
    if (correct) {
      streak += 1;
      correctCount += 1;
      score += 100 + (streak * 10).clamp(0, 50);
    } else {
      streak = 0;
    }
    return correct;
  }
}

/// Standart üç kişilik bot kadrosunu yönetir.
class BotRace {
  BotRace(this.bots);

  factory BotRace.standard({Random? random}) {
    final rng = random ?? Random();
    // M-3: İsimler merkezi BotNames.pool'dan rastgele seçilir;
    // her oyunda farklı rakip kadrosu oluşur.
    final shuffled = List<String>.from(BotNames.pool)..shuffle(rng);
    return BotRace([
      BotOpponent(name: shuffled[0], skill: 0.85, random: rng),
      BotOpponent(name: shuffled[1], skill: 0.70, random: rng),
      BotOpponent(name: shuffled[2], skill: 0.55, random: rng),
    ]);
  }

  final List<BotOpponent> bots;

  void answerAll(int difficulty) {
    for (final bot in bots) {
      bot.answer(difficulty);
    }
  }

  List<Player> toPlayers() {
    return bots
        .map(
          (bot) => Player(
            name: bot.name,
            score: bot.score,
            state: 'Bot',
            streak: bot.streak,
          ),
        )
        .toList(growable: false);
  }
}
