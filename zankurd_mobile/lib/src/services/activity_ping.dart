import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/analytics_consent_provider.dart';

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
/// ## Rıza (2.1.2, GPT-6 Pro alan 7 bulgu 1.4)
///
/// Satır hesap kimliğine bağlıdır (gün + kullanıcı). Eskiden analitik kapalıyken
/// de yazılıyordu ve gizlilik metni bunu söylemiyordu. Artık YALNIZ kullanım
/// analizi açıkken ([AnalyticsConsentProvider.isEnabled]) gider; kapalıyken
/// hiçbir şey yazılmaz. Pano sayıları bu yüzden "analizi açan hesaplar"
/// üzerinden okunur; kişisiz bir sayaç ayrı bir tasarım işidir.
///
/// ## Güvenlik / dayanıklılık
///
/// Hiçbir hata kullanıcıya yansımaz ve ağ bekletmez (ateşle-unut). Supabase
/// açılmamışsa (çevrimdışı açılış, test) ya da oturum yoksa sessizce çıkar.
class ActivityPing {
  ActivityPing._();

  static DateTime? _lastOpenPing;

  /// Son BAŞARILI gönderimin "gün|kullanıcı" anahtarı: gün ya da hesap
  /// değişince 4 saatlik seyreltme uygulanmaz (alan 8 #23).
  static String? _lastKey;

  /// Aynı süreçte "açıldı" bildirimi bu aralıktan sık gitmez (sunucu zaten
  /// günde bir satır tutar; ağ çağrısı boşa gitmesin).
  @visibleForTesting
  static const Duration openPingInterval = Duration(hours: 4);

  /// Test kancası: çağrıyı yapan işlev (üretimde Supabase RPC'si).
  @visibleForTesting
  static Future<void> Function(bool solo)? debugSender;

  /// Test kancası: oturum kullanıcısı kimliği (üretimde Supabase'ten okunur).
  @visibleForTesting
  static String? debugUserId;

  static String? _currentUserId() {
    final injected = debugUserId;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _lastOpenPing = null;
    _lastKey = null;
    debugSender = null;
    debugUserId = null;
  }

  /// Uygulama açılışı / öne gelişi. Sık çağrılabilir; ağ çağrısı seyreltilir.
  static Future<void> open({DateTime? now}) async {
    final at = now ?? DateTime.now();
    if (!AnalyticsConsentProvider.isEnabled) return;
    final key = '${_currentUserId()}|${at.year}-${at.month}-${at.day}';
    final last = _lastOpenPing;
    if (key == _lastKey &&
        last != null &&
        at.difference(last) < openPingInterval) {
      return;
    }
    // Yalnız başarılı gönderim seyreltmeyi başlatır: ağ yokken ilk deneme
    // sonraki açılışları 4 saat boyunca susturmasın.
    if (await _send(solo: false)) {
      _lastOpenPing = at;
      _lastKey = key;
    }
  }

  /// Solo oyun başladı (günlük aktif de sayılır).
  static Future<void> soloStarted() => _send(solo: true);

  static Future<bool> _send({required bool solo}) async {
    if (!AnalyticsConsentProvider.isEnabled) return false;
    try {
      final sender = debugSender;
      if (sender != null) {
        await sender(solo);
        return true;
      }
      final client = Supabase.instance.client;
      if (client.auth.currentUser == null) return false;
      await client.rpc<dynamic>('record_activity', params: {'p_solo': solo});
      return true;
    } catch (_) {
      // Ölçüm uğruna kullanıcıya hata gösterilmez.
      return false;
    }
  }
}
