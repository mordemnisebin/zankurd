import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Sunucuya "bu hesap bugün uygulamayı açtı" bilgisini yollar
/// (`record_activity` RPC'si, bkz. `supabase/2026-11-12_yonetim_paneli.sql`).
///
/// ## Niçin var
///
/// Yönetim panosundaki "bugün/hafta aktif" ve "solo kullanımı" sayıları için
/// sunucuda bir sayaç yoktu; pano `profiles.updated_at` vekilinden
/// uydurma sayı gösteriyordu. Sunucu hesap başına günde TEK satır tutar ve
/// yalnız toplam gösterir; içerik (ne oynadığı, nerede olduğu) gönderilmez.
///
/// Analitik rızasından (`AnalyticsConsentProvider`) bağımsızdır: Firebase gibi
/// üçüncü tarafa gitmez, sunucunun zaten bildiği hesabın "açıldı" işaretidir,
/// ek bir kişisel veri doğurmaz.
///
/// ## Güvenlik / dayanıklılık
///
/// Hiçbir hata kullanıcıya yansımaz ve ağ bekletmez (ateşle-unut). Supabase
/// açılmamışsa (çevrimdışı açılış, test) ya da oturum yoksa sessizce çıkar.
class ActivityPing {
  ActivityPing._();

  static DateTime? _lastOpenPing;

  /// Aynı süreçte "açıldı" bildirimi bu aralıktan sık gitmez (sunucu zaten
  /// günde bir satır tutar; ağ çağrısı boşa gitmesin).
  @visibleForTesting
  static const Duration openPingInterval = Duration(hours: 4);

  /// Test kancası: çağrıyı yapan işlev (üretimde Supabase RPC'si).
  @visibleForTesting
  static Future<void> Function(bool solo)? debugSender;

  @visibleForTesting
  static void resetForTest() {
    _lastOpenPing = null;
    debugSender = null;
  }

  /// Uygulama açılışı / öne gelişi. Sık çağrılabilir; ağ çağrısı seyreltilir.
  static Future<void> open({DateTime? now}) async {
    final at = now ?? DateTime.now();
    final last = _lastOpenPing;
    if (last != null && at.difference(last) < openPingInterval) return;
    _lastOpenPing = at;
    await _send(solo: false);
  }

  /// Solo oyun başladı (günlük aktif de sayılır).
  static Future<void> soloStarted() => _send(solo: true);

  static Future<void> _send({required bool solo}) async {
    try {
      final sender = debugSender;
      if (sender != null) return await sender(solo);
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return;
      await client.rpc<dynamic>('record_activity', params: {'p_solo': solo});
    } catch (_) {
      // Ölçüm uğruna kullanıcıya hata gösterilmez.
    }
  }
}
