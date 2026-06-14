import 'package:flutter_test/flutter_test.dart';

// quiz_screen.dart:475 mantığını izole test fonksiyonu olarak yansıtıyoruz.
int _applyCorrectAnswer({required int score, required int streak}) {
  return score + 100 + (streak * 10).clamp(0, 50);
}

void main() {
  group('quiz skor hesaplama', () {
    test('ilk doğru cevap: 100 puan, streak=0', () {
      expect(_applyCorrectAnswer(score: 0, streak: 0), 100);
    });

    test('streak 1 iken → 100 + 10 = 110 puan', () {
      expect(_applyCorrectAnswer(score: 0, streak: 1), 110);
    });

    test('streak 5 → 100 + 50 = 150 (max streak bonus)', () {
      expect(_applyCorrectAnswer(score: 0, streak: 5), 150);
    });

    test('streak 10 → 100 + 50 = 150 (clamp uygulandı)', () {
      expect(_applyCorrectAnswer(score: 0, streak: 10), 150);
    });

    test('birden fazla doğru cevap birikir', () {
      // 3 doğru: streak 0→1→2, puanlar: 100+110+120=330
      int score = 0;
      for (int streak = 0; streak < 3; streak++) {
        score = _applyCorrectAnswer(score: score, streak: streak);
      }
      expect(score, 330);
    });
  });
}
