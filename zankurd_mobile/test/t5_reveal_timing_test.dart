import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/game/reveal_timing.dart';

void main() {
  test(
    'T5: geçiş sabitleri dağınıktı; modlar birlikte sınanmadığı için sessizdi',
    () {
      expect(RevealTiming.live, const Duration(seconds: 3));
      expect(RevealTiming.crowd, const Duration(seconds: 4));
      expect(RevealTiming.legacy, const Duration(seconds: 5));
      expect(
        RevealTiming.individual(correct: true),
        const Duration(milliseconds: 1200),
      );
      expect(
        RevealTiming.individual(correct: false),
        const Duration(seconds: 3),
      );
    },
  );

  test(
    'T5: geç gelen cihaz yeniden 5 sn bekliyordu; tek cihaz testi gizledi',
    () {
      final origin = DateTime.utc(2026, 10, 30);
      var elapsedA = Duration.zero;
      var elapsedB = Duration.zero;
      final a = ServerRevealClock(
        serverNow: origin,
        endsAt: origin.add(RevealTiming.live),
        elapsed: () => elapsedA,
      );
      final b = ServerRevealClock(
        serverNow: origin.add(const Duration(seconds: 1)),
        endsAt: origin.add(RevealTiming.live),
        elapsed: () => elapsedB,
      );
      expect(a.secondsLeft, 3);
      expect(b.secondsLeft, 2);
      elapsedA = const Duration(milliseconds: 2999);
      elapsedB = const Duration(milliseconds: 1999);
      expect(a.secondsLeft, 1);
      expect(b.secondsLeft, 1);
      elapsedA += const Duration(milliseconds: 1);
      elapsedB += const Duration(milliseconds: 1);
      expect(a.remaining, Duration.zero);
      expect(b.remaining, Duration.zero);
    },
  );

  test('T5: arka planda tick kaçınca sayaç uzuyordu; düzenli pump gizledi', () {
    final origin = DateTime.utc(2026, 10, 30);
    var elapsed = Duration.zero;
    final clock = ServerRevealClock(
      serverNow: origin,
      endsAt: origin.add(RevealTiming.crowd),
      elapsed: () => elapsed,
    );
    elapsed = const Duration(milliseconds: 2500);
    expect(clock.remaining, const Duration(milliseconds: 1500));
    expect(clock.secondsLeft, 2);
    elapsed = const Duration(minutes: 2);
    expect(clock.remaining, Duration.zero);
    expect(clock.secondsLeft, 0);
  });

  test(
    'T5: süresi geçmiş açılış yeniden başlıyordu; yeniden giriş sınanmadı',
    () {
      final origin = DateTime.utc(2026, 10, 30);
      final clock = ServerRevealClock(
        serverNow: origin,
        endsAt: origin.subtract(const Duration(seconds: 1)),
        elapsed: () => Duration.zero,
      );
      expect(clock.remaining, Duration.zero);
    },
  );
}
