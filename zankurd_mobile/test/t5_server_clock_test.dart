import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/game/reveal_timing.dart';
import 'package:zankurd_mobile/src/game/server_clock.dart';

void main() {
  test('T5: ±5 sn cihaz farkı ve 2 sn geç olay ortak deadlineı kaydırmaz', () {
    final origin = DateTime.utc(2026, 10, 30, 12);
    var elapsedA = Duration.zero;
    var elapsedB = Duration.zero;
    // A: cihaz saati +5 sn, RPC 200 ms. B: -5 sn, olay iki saniye geç,
    // RPC 400 ms. server_now istek/yanıtın orta anındaki sunucu örneğidir.
    final a = ServerClock(
      serverNow: origin.add(const Duration(milliseconds: 100)),
      roundTrip: const Duration(milliseconds: 200),
      localReceivedAt: origin.add(const Duration(milliseconds: 5200)),
      elapsed: () => elapsedA,
    );
    final b = ServerClock(
      serverNow: origin.add(const Duration(milliseconds: 2200)),
      roundTrip: const Duration(milliseconds: 400),
      localReceivedAt: origin.subtract(const Duration(milliseconds: 2600)),
      elapsed: () => elapsedB,
    );
    expect(a.offset, const Duration(seconds: -5));
    expect(b.offset, const Duration(seconds: 5));
    final deadline = origin.add(const Duration(seconds: 20));
    final questionA = ServerRevealClock.fromServerClock(
      clock: a,
      endsAt: deadline,
    );
    final questionB = ServerRevealClock.fromServerClock(
      clock: b,
      endsAt: deadline,
    );
    // İki istemciyi aynı gerçek anlarda gözle: yerel saat/olay geliş anı
    // bağımsız olmalı. Ortak sunucu başlangıcı origin, son süre origin+20.
    for (final milliseconds in [2400, 3400, 12400, 19400, 20000, 22000]) {
      elapsedA = Duration(milliseconds: milliseconds - 200);
      elapsedB = Duration(milliseconds: milliseconds - 2400);
      expect(
        (questionA.secondsLeft - questionB.secondsLeft).abs(),
        lessThanOrEqualTo(1),
      );
    }
    expect(questionA.secondsLeft, 0);
    expect(questionB.secondsLeft, 0);
    elapsedA = const Duration(milliseconds: 3200);
    elapsedB = const Duration(seconds: 1);
    expect(questionA.secondsLeft, 17);
    expect(questionB.secondsLeft, 17);
    final revealEnd = origin.add(const Duration(seconds: 5));
    expect(
      ServerRevealClock.fromServerClock(
        clock: a,
        endsAt: revealEnd,
      ).secondsLeft,
      2,
    );
    expect(
      ServerRevealClock.fromServerClock(
        clock: b,
        endsAt: revealEnd,
      ).secondsLeft,
      2,
    );
  });

  test(
    'T5: örnekten sonraki duvar saati değişimi ve kaçan tick süre eklemez',
    () {
      final origin = DateTime.utc(2026, 10, 30);
      var elapsed = Duration.zero;
      var wall = origin.add(const Duration(seconds: 5));
      final clock = ServerClock(
        serverNow: origin,
        localReceivedAt: wall,
        elapsed: () => elapsed,
      );
      wall = wall.subtract(const Duration(hours: 1));
      elapsed = const Duration(seconds: 12);
      expect(
        clock.remainingUntil(origin.add(const Duration(seconds: 20))),
        const Duration(seconds: 8),
      );
      expect(clock.now, origin.add(const Duration(seconds: 12)));
      expect(clock.now, isNot(wall));
      elapsed = const Duration(minutes: 1);
      expect(
        clock.remainingUntil(origin.add(const Duration(seconds: 20))),
        Duration.zero,
      );
    },
  );
}
