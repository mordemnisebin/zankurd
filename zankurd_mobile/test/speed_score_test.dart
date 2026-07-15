import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/game/speed_score.dart';
import 'package:zankurd_mobile/src/models/room.dart';

void main() {
  test('oda süresi yalnızca desteklenen seçeneklerden oluşur', () {
    expect(GameRoom.allowedSecondsPerQuestion, [20, 30, 45, 60]);
    expect(GameRoom.defaultSecondsPerQuestion, 30);
  });

  test('doğru ve hızlı cevap taban puana hız bonusu ekler', () {
    final fast = SpeedScore.calculate(
      responseMs: 4_000,
      limitSeconds: 30,
      correct: true,
    );
    final slow = SpeedScore.calculate(
      responseMs: 25_000,
      limitSeconds: 30,
      correct: true,
    );

    expect(fast, greaterThan(slow));
    expect(slow, greaterThan(0));
  });

  test('yanlış cevap veya süre aşımı hız bonusu vermez', () {
    expect(
      SpeedScore.calculate(
        responseMs: 2_000,
        limitSeconds: 30,
        correct: false,
      ),
      0,
    );
    expect(
      SpeedScore.calculate(
        responseMs: 31_000,
        limitSeconds: 30,
        correct: true,
      ),
      0,
    );
  });
}
