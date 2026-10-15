import '../models/player.dart';

/// Kalabalık odada bir oyuncunun sırası.
class CrowdStanding {
  const CrowdStanding({required this.player, required this.rank});

  final Player player;

  /// 1'den başlar; eşit skor aynı sırayı paylaşır (1, 1, 3 …).
  final int rank;
}

/// Oyuncuları skora göre sıralar ve eşitlikte aynı sırayı verir.
///
/// Sunucunun sonuç yükündeki `rank` ile aynı kural: sıra = kendinden
/// KESİNLİKLE yüksek skorlu oyuncu sayısı + 1. Oyun sürerken sıra ekranda
/// canlı hesaplanır (sunucu yalnız sonuç yükünde verir). Ayrılan/düşen
/// oyuncular ([Player.left]) sıralamaya girmez; skorları listede kalır ama
/// kimseyi geride bırakmazlar.
///
/// Eşit skorda giriş sırası korunur (kararlı): lobiye katılış sırası, kendi
/// kendine zıplayan satırlardan iyidir.
List<CrowdStanding> crowdStandings(Iterable<Player> players) {
  final active = [
    for (final player in players)
      if (!player.left) player,
  ];
  // List.sort kararlı değildir; indeksle bağlayıp eşitliği girişe göre kır.
  final indexed = [for (var i = 0; i < active.length; i++) (i, active[i])];
  indexed.sort((a, b) {
    final byScore = b.$2.score.compareTo(a.$2.score);
    return byScore != 0 ? byScore : a.$1.compareTo(b.$1);
  });
  final result = <CrowdStanding>[];
  for (var i = 0; i < indexed.length; i++) {
    final player = indexed[i].$2;
    final rank = i > 0 && indexed[i - 1].$2.score == player.score
        ? result[i - 1].rank
        : i + 1;
    result.add(CrowdStanding(player: player, rank: rank));
  }
  return result;
}
