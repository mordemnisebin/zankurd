enum MatchmakingOutcome { cancelled, human, bot }

class MatchmakingMetrics {
  MatchmakingMetrics({
    Duration Function()? elapsed,
    void Function(Map<String, Object>)? record,
  }) : _elapsed = elapsed ?? (() => Duration.zero),
       _record = record ?? ((_) {});

  final Duration Function() _elapsed;
  final void Function(Map<String, Object>) _record;
  Duration? _start;

  void start() {
    _start = _elapsed();
  }

  void finish(MatchmakingOutcome outcome) {
    final start = _start;
    if (start == null) return;
    _start = null;
    final wait = _elapsed() - start;
    _record({'outcome': outcome.name, 'wait_seconds': wait.inSeconds});
  }
}
