import 'dart:math';

import '../../config/bot_names.dart';
import '../../game/bot_opponent.dart';
import '../../models/player.dart';
import '../quiz_screen.dart';

/// Quiz sırasında bot rakiplerin yaşam döngüsünü ve skor sıralamasını yöneten kontrolcü.
///
/// `quiz_screen.dart` içindeki bot mantığını izole eder:
/// - 1v1 için benzersiz isim ve dengeli yetenekle bot rakip kurma
/// - Standart çoklu bot yarışı kurma
/// - Her soruda botların cevaplarını simüle etme
/// - Canlı skor tablosunda insan oyuncu ile botları birleştirip sıralama
class QuizBotController {
  QuizBotController._(this._race);

  /// 1v1 bot eşleşmesi için tek kişilik bot kadrosu oluşturur.
  factory QuizBotController.for1v1({
    required List<Player> existingPlayers,
    Random? random,
  }) {
    final rng = random ?? Random();
    final botName = botOpponentDisplayName(existingPlayers, BotNames.pool, rng);
    final botSkill = 0.65 + rng.nextDouble() * 0.25;
    final race = BotRace([
      BotOpponent(name: botName, skill: botSkill, random: rng),
    ]);
    return QuizBotController._(race);
  }

  /// Çoklu yarış için standart 3 kişilik bot kadrosunu oluşturur.
  factory QuizBotController.forRace({Random? random}) {
    return QuizBotController._(BotRace.standard(random: random));
  }

  /// Harici bir BotRace ile doğrudan başlatmak için (testler için ideal).
  factory QuizBotController.fromRace(BotRace race) {
    return QuizBotController._(race);
  }

  final BotRace _race;

  BotRace get race => _race;
  List<BotOpponent> get bots => _race.bots;

  /// Botların verilen zorluktaki soruya cevap vermesini simüle eder.
  void advance(int difficulty) {
    _race.answerAll(difficulty);
  }

  /// Botları Player model listesi olarak döndürür.
  List<Player> toPlayers() => _race.toPlayers();

  /// İnsan oyuncu ile botları birleştirir ve skora göre büyükten küçüğe sıralar.
  List<Player> composePlayers({required Player humanPlayer}) {
    final players = <Player>[humanPlayer, ..._race.toPlayers()]
      ..sort((a, b) => b.score.compareTo(a.score));
    return players;
  }
}
