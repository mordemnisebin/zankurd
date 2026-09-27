import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/config/bot_names.dart';
import 'package:zankurd_mobile/src/game/bot_opponent.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_bot_controller.dart';

class _FixedRng implements Random {
  _FixedRng(this._value);
  final double _value;

  @override
  double nextDouble() => _value;
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => 0;
}

void main() {
  group('QuizBotController', () {
    test('for1v1 creates exactly one bot with name avoiding collisions', () {
      final existing = [
        const Player(name: 'Rojda', score: 0, state: 'Hazır'),
      ];

      final controller = QuizBotController.for1v1(
        existingPlayers: existing,
        random: _FixedRng(0.5),
      );

      expect(controller.bots.length, 1);
      final bot = controller.bots.first;
      expect(bot.name, isNotEmpty);
      expect(BotNames.pool.contains(bot.name), isTrue);
      expect(bot.name, isNot('Rojda'));
      expect(bot.skill, greaterThanOrEqualTo(0.65));
      expect(bot.skill, lessThanOrEqualTo(0.90));
    });

    test('forRace creates standard 3 bots', () {
      final controller = QuizBotController.forRace(random: _FixedRng(0.2));
      expect(controller.bots.length, 3);
      expect(controller.toPlayers().length, 3);
    });

    test('advance triggers answerAll and updates scores', () {
      // _FixedRng(0.0) her zaman doğru cevaplatır
      final bot = BotOpponent(name: 'Bot1', skill: 0.85, random: _FixedRng(0.0));
      final controller = QuizBotController.fromRace(BotRace([bot]));

      expect(controller.bots.first.score, 0);
      controller.advance(1);
      expect(controller.bots.first.score, 110);
    });

    test('composePlayers merges human player and bots sorted by score descending', () {
      final bot1 = BotOpponent(name: 'BotLow', skill: 0.5);
      bot1.score = 50;

      final bot2 = BotOpponent(name: 'BotHigh', skill: 0.9);
      bot2.score = 250;

      final controller = QuizBotController.fromRace(BotRace([bot1, bot2]));

      const human = Player(name: 'Human', score: 150, state: '—');
      final leaderboard = controller.composePlayers(humanPlayer: human);

      expect(leaderboard.length, 3);
      expect(leaderboard[0].name, 'BotHigh');
      expect(leaderboard[0].score, 250);
      expect(leaderboard[1].name, 'Human');
      expect(leaderboard[1].score, 150);
      expect(leaderboard[2].name, 'BotLow');
      expect(leaderboard[2].score, 50);
    });
  });
}
