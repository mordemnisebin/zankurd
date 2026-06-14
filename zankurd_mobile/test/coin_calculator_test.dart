import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/coin_calculator.dart';

void main() {
  group('CoinCalculator.award', () {
    test('sıfır doğru, sıfır streak → yalnızca completionBonus (10 soruda)', () {
      expect(
        CoinCalculator.award(
          score: 0,
          correctCount: 0,
          bestStreak: 0,
          totalQuestions: 10,
        ),
        20,
      );
    });

    test('10 doğru, streak 5, score 800, 10 soru → 100', () {
      // completionBonus=20 + 10*6=60 + 5*2=10 + 800~/80=10 → 100
      expect(
        CoinCalculator.award(
          score: 800,
          correctCount: 10,
          bestStreak: 5,
          totalQuestions: 10,
        ),
        100,
      );
    });

    test('az soru (<10) → completionBonus=8', () {
      expect(
        CoinCalculator.award(
          score: 0,
          correctCount: 0,
          bestStreak: 0,
          totalQuestions: 5,
        ),
        8,
      );
    });

    test('yüksek streak bonus doğru hesaplanır', () {
      // completionBonus=20 + 0 + 10*2=20 + 0 = 40
      expect(
        CoinCalculator.award(
          score: 0,
          correctCount: 0,
          bestStreak: 10,
          totalQuestions: 10,
        ),
        40,
      );
    });

    test('practice mode → 0 coin', () {
      expect(CoinCalculator.practiceAward(), 0);
    });
  });
}
