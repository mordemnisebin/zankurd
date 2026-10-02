enum MatchmakingOutcome {
  cancelled,
  human,
  bot,

  /// Oyuncu 20sn zaman aşımında botu değil sırayla düelloyu seçti — rakip
  /// aynı anda çevrimiçi değil, kendi zamanında oynayacak.
  asyncDuel,
}

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
    // Analitik dizgesi `.name`den bilerek ayrılır: diğer üç değer tek
    // sözcük olduğu için `.name` zaten doğru çıktıyı veriyordu, ama
    // `asyncDuel.name` kayıt defterindeki diğer olay alanlarının
    // (`matchmaking_wait`, `wait_seconds`...) kullandığı yılan-kılıfına
    // (snake_case) uymazdı.
    final outcomeName = switch (outcome) {
      MatchmakingOutcome.cancelled => 'cancelled',
      MatchmakingOutcome.human => 'human',
      MatchmakingOutcome.bot => 'bot',
      MatchmakingOutcome.asyncDuel => 'async_duel',
    };
    _record({'outcome': outcomeName, 'wait_seconds': wait.inSeconds});
  }
}
