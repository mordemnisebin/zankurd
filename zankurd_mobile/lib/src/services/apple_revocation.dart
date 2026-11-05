import 'dart:async';

import 'package:flutter/foundation.dart';
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

/// Hesap silme, süren bir kayıt çağrısını en çok bu kadar bekler (GPT-6 Pro
/// ALAN 4 #10: kayıt `unawaited` idi; hızlı silmede iptal, henüz yazılmamış
/// jetonu görmeden `no_token` dönüyordu). Silme hakkı bekleyişe bağlı kalmaz.
const Duration kAppleRevokeWaitForRegister = Duration(seconds: 15);

/// Süren kayıt çağrıları ve henüz sunucuya KAYDEDİLMEMİŞ tek kullanımlık kod.
/// Kod yalnız bellektedir (diske yazılmaz; ~5 dk geçerli); kayıt başarılı
/// olunca ya da kalıcı reddedilince (4xx) silinir. Silme anında kayıt hâlâ
/// bitmediyse kod `revoke` çağrısına eklenir, sunucu takas edip iptal eder.
final Set<Future<bool>> _inFlightRegistrations = <Future<bool>>{};
String? _unregisteredCode;

@visibleForTesting
void resetAppleRegistrationStateForTest() {
  _inFlightRegistrations.clear();
  _unregisteredCode = null;
}

/// Girişten hemen sonra çağrılır; yanıt beklenmez/hata yutulur. Geçici
/// hatada kod geçerliyken sınırlı sayıda yeniden denenir; `true` yalnız
/// sunucunun kaydı onayladığını söyler. Süren çağrı [revokeAppleAuthorization]
/// tarafından beklenir.
Future<bool> registerAppleAuthorization(
  SupabaseClient client,
  String authorizationCode, {
  List<Duration> retryDelays = kAppleRegisterRetryDelays,
}) {
  final code = authorizationCode.trim();
  if (code.isEmpty) return Future<bool>.value(false);
  _unregisteredCode = code;
  late final Future<bool> tracked;
  tracked = _registerWithRetry(client, code, retryDelays)
      .then((ok) {
        if (ok && _unregisteredCode == code) _unregisteredCode = null;
        return ok;
      })
      .whenComplete(() => _inFlightRegistrations.remove(tracked));
  _inFlightRegistrations.add(tracked);
  return tracked;
}

Future<bool> _registerWithRetry(
  SupabaseClient client,
  String code,
  List<Duration> retryDelays,
) async {
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
      if (!retry) {
        // Kalıcı ret (4xx; ör. apple_subject_mismatch): kod bir daha kullanılamaz.
        if (error is FunctionException && error.status < 500) {
          if (_unregisteredCode == code) _unregisteredCode = null;
        }
        return false;
      }
      await Future<void>.delayed(retryDelays[attempt]);
    }
  }
}

/// Hesap silmeden ÖNCE çağrılır. Hiç fırlatmaz (iptal hesap silmeyi
/// ENGELLEMEZ). `true` YALNIZ sunucu `revoked: true` döndüyse: saklı jeton
/// yoksa (`no_token`, HTTP 200) ya da Apple reddettiyse `false` (GPT-6 Pro
/// ALAN 4 #1: eskiden çağrının hatasız bitmesi başarı sayılıyordu). Apple
/// hatasında sunucu jetonu hesap silmeden bağımsız bir kuyrukta tutar ve
/// yeniden dener (apple_auth_tokens yetim satırları).
Future<bool> revokeAppleAuthorization(SupabaseClient client) async {
  try {
    if (_inFlightRegistrations.isNotEmpty) {
      await Future.wait(
        _inFlightRegistrations.toList(),
      ).timeout(kAppleRevokeWaitForRegister);
    }
  } catch (_) {
    // Bekleme sınırı doldu ya da kayıt başarısız: silme sürer.
  }
  try {
    final pending = _unregisteredCode;
    final response = await client.functions
        .invoke(
          kAppleRevokeFunction,
          body: {'action': 'revoke', 'authorization_code': ?pending},
        )
        .timeout(kAppleRevokeTimeout);
    final data = response.data;
    final revoked = data is Map && data['revoked'] == true;
    if (revoked) {
      _unregisteredCode = null;
    } else {
      final reason = data is Map ? data['reason'] : null;
      ErrorReporter.record(
        StateError('apple-revoke: bağlantı iptal edilmedi (reason: $reason)'),
        StackTrace.current,
        reason: 'apple-revoke revoke not revoked (account deletion continues)',
      );
    }
    return revoked;
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
/// fonksiyon hiç çağrılmaz. Ölçüt Edge'dekiyle (`hasAppleIdentity`,
/// apple-revoke/lib.ts) AYNI: `identities`te apple, yoksa
/// `app_metadata.provider` / `providers` (GPT-6 Pro ALAN 4 #20: istemci yalnız
/// `identities`e bakıyordu, Edge ikisine de; tutarsızlıkta Apple hesabı için
/// iptal hiç çağrılmayabiliyordu).
bool userHasAppleIdentity(User? user) {
  if (user == null) return false;
  if (user.identities?.any((identity) => identity.provider == 'apple') ??
      false) {
    return true;
  }
  final meta = user.appMetadata;
  if (meta['provider'] == 'apple') return true;
  final providers = meta['providers'];
  return providers is List && providers.contains('apple');
}
