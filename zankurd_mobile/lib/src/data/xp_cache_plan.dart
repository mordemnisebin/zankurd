/// Kuyruk boşken seviye çubuğu ile `profiles.xp` nasıl barışır.
///
/// Sunucu daha yüksekse çubuk onu alır. Yerel öğrenme XP'si daha yüksekse
/// korunur; istemci farkı rekabetçi sunucu XP'sine dönüştürmez.
enum XpCacheStep { keep, applyServer }

class XpCachePlan {
  const XpCachePlan(this.step, [this.amount = 0]);

  final XpCacheStep step;
  final int amount;

  static XpCachePlan decide({
    required int local,
    required int? server,
    required bool xpPending,
  }) {
    if (xpPending || server == null) {
      return const XpCachePlan(XpCacheStep.keep);
    }
    if (server > local) {
      return XpCachePlan(XpCacheStep.applyServer, server);
    }
    return const XpCachePlan(XpCacheStep.keep);
  }
}
