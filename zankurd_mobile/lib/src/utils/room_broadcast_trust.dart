import '../models/player.dart';

/// Oda yayınının (Realtime broadcast) güven sınırı.
///
/// Kanal herkese açıktır: odanın uuid'ini bilen herkes `sender_id`, `sender`,
/// `score`, `streak` alanlarını istediği gibi yazabilir (GPT-6 Pro denetimi,
/// 2026-11-04). Yayın bu yüzden yalnız İPUCUDUR:
/// - Oyuncu listesini yetkili kaynak belirler (`room_players` akışı / sunucu
///   özeti). Listede olmayan gönderici yok sayılır; yayın listeye oyuncu
///   EKLEYEMEZ.
/// - Sunucu gizli cevap modundaysa yayındaki skor/seri hiç uygulanmaz; sunucu
///   satırı zaten yetkilidir.
/// - Eski (yayın tabanlı) odalarda skor ipucu yalnız ARTAR, hiç düşmez ve
///   üst sınırı vardır; bir sonraki yetkili satır (`subscribeRoomPlayers` /
///   `_applySnapshot`) değeri doğrudan ezer, yani yayın kalıcı skor yazamaz.
abstract final class RoomBroadcastTrust {
  /// Bir sorudan alınabilecek en yüksek puan ipucu payı (temel + süre + seri
  /// payı için bol bir üst sınır). Bundan büyük sıçrama sahte sayılır.
  static const maxHintJumpPerBroadcast = 5000;

  /// [roster] içinde yayını gönderen üye; yoksa null (yayın yok sayılır).
  static Player? member(
    List<Player> roster, {
    required String? senderId,
    required String? senderName,
  }) {
    if (senderName == null && senderId == null) return null;
    final claimed = Player(
      id: senderId,
      name: senderName ?? '',
      score: 0,
      state: '',
    );
    for (final player in roster) {
      if (playersShareIdentity(player, claimed)) return player;
    }
    return null;
  }

  /// Yayındaki skor/seri ipucundan [member] için gösterilecek değerler.
  static ({int score, int streak}) hintedProgress(
    Player member, {
    required int? hintScore,
    required int? hintStreak,
    required bool serverAuthoritative,
  }) {
    if (serverAuthoritative) {
      return (score: member.score, streak: member.streak);
    }
    var score = member.score;
    if (hintScore != null &&
        hintScore > score &&
        hintScore - score <= maxHintJumpPerBroadcast) {
      score = hintScore;
    }
    var streak = member.streak;
    if (hintStreak != null && hintStreak >= 0 && hintStreak <= 1000) {
      streak = hintStreak;
    }
    return (score: score, streak: streak);
  }
}
