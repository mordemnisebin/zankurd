import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/matchmaking_metrics.dart';

void main() {
  test('her arama bir kez biter ve yalnız süre/sonuç kaydeder', () {
    var now = Duration.zero;
    final events = <Map<String, Object>>[];
    final metrics = MatchmakingMetrics(elapsed: () => now, record: events.add);
    metrics.start();
    now = const Duration(seconds: 12);
    metrics.finish(MatchmakingOutcome.cancelled);
    metrics.finish(MatchmakingOutcome.cancelled);
    expect(events, [
      {'outcome': 'cancelled', 'wait_seconds': 12},
    ]);
    metrics.start();
    now = const Duration(seconds: 15);
    metrics.finish(MatchmakingOutcome.human);
    expect(events.last, {'outcome': 'human', 'wait_seconds': 3});
  });

  test('başlamayan arama veri üretmez', () {
    final events = <Map<String, Object>>[];
    MatchmakingMetrics(record: events.add).finish(MatchmakingOutcome.bot);
    expect(events, isEmpty);
  });

  test(
    'sırayla düello sonucu analitikte snake_case "async_duel" olarak geçer',
    () {
      // `.name` kullansaydı 'asyncDuel' (camelCase) yazardı; diğer üç
      // olay adının (`cancelled`, `human`, `bot`) ve olayın kendi
      // alanlarının (`wait_seconds`) kullandığı kılıfla uyuşmazdı.
      var now = Duration.zero;
      final events = <Map<String, Object>>[];
      final metrics = MatchmakingMetrics(
        elapsed: () => now,
        record: events.add,
      );
      metrics.start();
      now = const Duration(seconds: 20);
      metrics.finish(MatchmakingOutcome.asyncDuel);
      expect(events, [
        {'outcome': 'async_duel', 'wait_seconds': 20},
      ]);
    },
  );
}
