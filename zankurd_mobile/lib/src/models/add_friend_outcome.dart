/// Arkadaşlık isteği gönderme sonucu.
///
/// `add_friend` RPC'si `success` + `message` döner. İstemci bunu eskiden tek
/// bir `bool`a eziyordu; "engellendi", "zaten arkadaş", "istek bekliyor",
/// hız sınırı ve karşılıklı isteğin otomatik kabulü ekranda aynı cümleye
/// düşüyordu (bkz. `test/friend_request_outcome_test.dart`).
enum AddFriendOutcome {
  /// İstek gönderildi.
  sent,

  /// Karşı tarafın bekleyen isteği vardı; sunucu ikisini birleştirip
  /// arkadaşlığı kurdu (ekran "istek gönderildi" DEMEMELİ).
  autoAccepted,
  alreadyFriends,
  alreadyPending,
  blocked,
  rateLimited,

  /// Ağ/oturum hatası ya da tanınmayan ret.
  failed;

  /// İstek ya da arkadaşlık gerçekten yazıldı mı?
  bool get isSuccess => this == sent || this == autoAccepted;

  /// Sunucu cevabını sonuca çevirir. Mesajlar sunucunun İngilizce sabit
  /// metinleridir (`supabase/2026-10-02_blocking_enforcement.sql`); hız
  /// sınırı/bekleme metinleri depodaki SQL'de henüz yok, ama canlı sunucu
  /// verirse ekran genel "başarısız" yerine doğru cümleyi göstersin diye
  /// savunmacı olarak tanınır.
  static AddFriendOutcome fromServer({
    required bool success,
    required String? message,
  }) {
    final text = (message ?? '').toLowerCase();
    if (success) {
      return text.contains('accepted') ? autoAccepted : sent;
    }
    if (text.contains('already friends')) return alreadyFriends;
    if (text.contains('already pending')) return alreadyPending;
    if (text.contains('blocked')) return blocked;
    if (text.contains('too many') ||
        text.contains('cooldown') ||
        text.contains('rate limit') ||
        text.contains('please wait')) {
      return rateLimited;
    }
    return failed;
  }
}
