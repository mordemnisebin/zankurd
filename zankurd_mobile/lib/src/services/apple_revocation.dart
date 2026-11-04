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

/// Kayıt başarısızsa yeniden deneme aralıkları. Apple'ın kodu ~5 dakika
/// geçerli: toplam bekleme bunun çok altında kalır (GPT-6 Pro ALAN 4: tek
/// atışlık kayıt hatayı yalnız logluyor, sunucuda iptal jetonu hiç
/// oluşmayabiliyordu).
const List<Duration> kAppleRegisterRetryDelays = <Duration>[
  Duration(seconds: 3),
  Duration(seconds: 10),
  Duration(seconds: 30),
];

/// Yeniden denemeye değer mi? Ağ/zaman aşımı ve 5xx evet; 4xx (kimlik yok,
/// geçersiz istek, Apple kimliği yok) kalıcıdır.
bool _isRetryableRegisterError(Object error) {
  if (error is FunctionException) return error.status >= 500;
  return true;
}

/// Girişten hemen sonra çağrılır; yanıt beklenmez/hata yutulur. Geçici
/// hatada kod geçerliyken sınırlı sayıda yeniden denenir; `true` yalnız
/// sunucunun kaydı onayladığını söyler.
Future<bool> registerAppleAuthorization(
  SupabaseClient client,
  String authorizationCode, {
  List<Duration> retryDelays = kAppleRegisterRetryDelays,
}) async {
  final code = authorizationCode.trim();
  if (code.isEmpty) return false;
  for (var attempt = 0; ; attempt++) {
    try {
      await client.functions
          .invoke(
            kAppleRevokeFunction,
            body: {'action': 'register', 'authorization_code': code},
          )
          .timeout(kAppleRevokeTimeout);
      return true;
    } catch (error, stack) {
      final retry =
          attempt < retryDelays.length && _isRetryableRegisterError(error);
      ErrorReporter.record(
        error,
        stack,
        reason: retry
            ? 'apple-revoke register failed (retrying)'
            : 'apple-revoke register failed (sign-in continues)',
      );
      if (!retry) return false;
      await Future<void>.delayed(retryDelays[attempt]);
    }
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
