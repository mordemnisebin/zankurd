import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/error_reporter.dart';

/// "Sign in with Apple" bağlantısının hesap silinirken Apple tarafında da
/// iptal edilmesi (App Store İnceleme Kılavuzu 5.1.1(v)).
///
/// ## Akış
///
/// 1. Apple ile girişten HEMEN SONRA [registerAppleAuthorization]: Apple'ın
///    verdiği `authorizationCode` tek kullanımlık ve ~5 dakikalıktır, bu
///    yüzden silme anına kadar tutulamaz. `apple-revoke` Edge Function'ı
///    kodu Apple'a takas edip kalıcı `refresh_token`ı sunucuda saklar.
/// 2. Hesap silinirken, `delete_my_account` ÇAĞRILMADAN önce
///    [revokeAppleAuthorization]: saklı jeton Apple'da iptal edilir.
///
/// ## Başarısızlık hesap silmeyi ENGELLEMEZ
///
/// Fonksiyon dağıtılmamış, Apple erişilemez ya da gizli anahtarlar eksik
/// olabilir. Kullanıcının silme hakkı bunlara bağlı olamaz (5.1.1(v) hesabın
/// silinebilmesini şart koşar); hata kaydedilir ve silme sürer. İki fonksiyon
/// da asla fırlatmaz.
///
/// Edge Function kaynağı: `supabase/functions/apple-revoke/index.ts`; saklama
/// tablosu: `supabase/2026-10-02_apple_auth_tokens.sql`.
const String kAppleRevokeFunction = 'apple-revoke';

/// Ağ beklemesi sınırı: silme düğmesi Apple yavaş diye uzun donmasın.
const Duration kAppleRevokeTimeout = Duration(seconds: 10);

/// Girişten hemen sonra çağrılır; yanıt beklenmez/hata yutulur.
Future<void> registerAppleAuthorization(
  SupabaseClient client,
  String authorizationCode,
) async {
  final code = authorizationCode.trim();
  if (code.isEmpty) return;
  try {
    await client.functions
        .invoke(
          kAppleRevokeFunction,
          body: {'action': 'register', 'authorization_code': code},
        )
        .timeout(kAppleRevokeTimeout);
  } catch (error, stack) {
    ErrorReporter.record(
      error,
      stack,
      reason: 'apple-revoke register failed (sign-in continues)',
    );
  }
}

/// Hesap silmeden ÖNCE çağrılır. Başarısızlık yutulur; `true` yalnız
/// çağrının hatasız tamamlandığını söyler (Apple'ın iptali kabul ettiğini
/// değil: saklı jeton yoksa sunucu `no_token` döner).
Future<bool> revokeAppleAuthorization(SupabaseClient client) async {
  try {
    await client.functions
        .invoke(kAppleRevokeFunction, body: {'action': 'revoke'})
        .timeout(kAppleRevokeTimeout);
    return true;
  } catch (error, stack) {
    ErrorReporter.record(
      error,
      stack,
      reason: 'apple-revoke revoke failed (account deletion continues)',
    );
    return false;
  }
}

/// Oturumdaki kullanıcının Apple kimliği var mı? Apple dışı hesaplarda
/// fonksiyon hiç çağrılmaz.
bool userHasAppleIdentity(User? user) =>
    user?.identities?.any((identity) => identity.provider == 'apple') ?? false;
