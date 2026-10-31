import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/game/speed_score.dart';
import 'package:zankurd_mobile/src/models/room.dart';

void main() {
  test('oda süresi yalnızca desteklenen seçeneklerden oluşur', () {
    // 90/120 saniye sunucu göçüyle birlikte yayımlanır; varsayılan değişmez.
    expect(GameRoom.allowedSecondsPerQuestion, [
      10,
      15,
      20,
      30,
      45,
      60,
      90,
      120,
    ]);
    expect(GameRoom.defaultSecondsPerQuestion, 20);
  });

  test('arayüzün sunduğu süreler sözleşmenin içinde kalır', () {
    // İki liste var ve karışması kolay: `allowedDurations` oda kurma
    // ekranının gösterdiği seçenekler, `allowedSecondsPerQuestion` ise
    // sunucuya gönderilmeden önceki geçerlilik kümesi. Biri büyüyüp öbürü
    // büyümezse arayüz, sunucunun reddedeceği bir süreyi sunar.
    for (final seconds in GameRoom.allowedDurations) {
      expect(
        GameRoom.allowedSecondsPerQuestion,
        contains(seconds),
        reason:
            'Arayüz $seconds saniyeyi sunuyor ama sözleşme kümesinde yok; '
            'oda açma sunucuda reddedilir.',
      );
    }
    expect(
      GameRoom.allowedDurations,
      contains(GameRoom.defaultSecondsPerQuestion),
      reason: 'Varsayılan süre arayüzün sunduğu seçenekler arasında değil.',
    );
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
      SpeedScore.calculate(responseMs: 2_000, limitSeconds: 30, correct: false),
      0,
    );
    expect(
      SpeedScore.calculate(responseMs: 31_000, limitSeconds: 30, correct: true),
      0,
    );
  });

  test('120 saniyelik odada 60 saniye sonrası cevap geçerlidir', () {
    expect(
      SpeedScore.calculate(
        responseMs: 90_000,
        limitSeconds: 120,
        correct: true,
      ),
      125,
    );
    expect(
      SpeedScore.calculate(
        responseMs: 120_001,
        limitSeconds: 120,
        correct: true,
      ),
      0,
    );
  });
}
