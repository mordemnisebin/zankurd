/// Ağa giden yedek yoklamaların TEK yerde toplanan aralıkları.
///
/// Kusur (yük denetimi 2026-11-03): lobi 3 sn'de iki sorgu + yoklama
/// (kalabalıkta 6 sn), kalabalık quiz 1 sn'de ilerleme + 4–6 sn'de oda
/// sırası, sıralama 30 sn'de bir sorgu atıyordu. Realtime akışları zaten
/// var; yoklama onların YEDEĞİ olmalıydı ama asıl yolmuş gibi sık çalışıyordu.
/// 10.000 eşzamanlı kullanıcıda bu, yalnız lobi + quiz için on binlerce
/// istek/sn demek; hata VERMEZ, sadece sunucuyu sessizce boğar — o yüzden
/// kimse fark etmez. Aralıklar burada durur ki bir daha "sadece bir sn"
/// diye sıkıştırılamasın; `poll_cadence_test.dart` bütçeyi korur.
class PollCadence {
  PollCadence._();

  /// Lobi: oyuncu listesi + oda durumu yedek yoklaması. `room_heartbeat`
  /// (sunucuda 45 sn sahiplik kuralı) durum yoklamasıyla birlikte gider:
  /// 3 vuruş/45 sn pay kalır.
  static const lobbyFallback = Duration(seconds: 15);
  static const lobbyCrowdFallback = Duration(seconds: 20);

  /// Quiz: oda sırası (`rooms` akışı yedeği) ve kalabalık ilerleme sayısı.
  static const duelRoomIndexFallback = Duration(seconds: 10);
  static const crowdRoomIndexFallback = Duration(seconds: 15);
  static const crowdProgressFallback = Duration(seconds: 10);

  /// Sıralama: yalnız görünürken ve ön plandayken; elle çekip yenilenir.
  static const leaderboardRefresh = Duration(seconds: 120);

  /// Sohbet akışı yalnız son bu kadar mesajı taşır.
  static const chatWindow = 50;

  /// Bir aralığın tek kullanıcıda dakikada attığı istek sayısı.
  static double perMinute(Duration interval) => 60000 / interval.inMilliseconds;
}
