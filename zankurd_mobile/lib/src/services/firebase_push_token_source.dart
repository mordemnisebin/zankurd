import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_token_sync.dart';

/// FCM jeton kaynağı.
///
/// ## Kusur (GPT-6 Pro ALAN 4)
///
/// AppShell Firebase'den ÖNCE kurulursa `onTokenRefresh` kapanmış bir
/// `Stream.empty()` döndürüyor, ilk jeton okuması `null` dönüyordu; Firebase
/// sonradan hazır olunca ikisi de yenilenmiyordu. Niçin sessiz: hata yok,
/// resume tek seferlik okumayı kurtarırdı ama kayıp yenileme aboneliğini
/// onarmazdı — jeton döndüğünde sunucu eski jetonda kalırdı.
///
/// Düzeltme: Firebase hazır olana dek ([FirebaseReadiness]) beklenir; abonelik gerçek
/// akışa ancak o zaman bağlanır. Hazırlık ve akış enjekte edilebilir (test).
/// `Firebase.initializeApp` sonucunu bekleyenlere bildirir. Yoklama (zamanlayıcı)
/// yerine tamamlanan bir `Future` kullanılır: testlerde Firebase hiç başlamaz
/// ve bekleyen zamanlayıcı bırakmaz; üretimde başarı/başarısızlık main()'den
/// bildirilir.
abstract final class FirebaseReadiness {
  static Completer<bool> _completer = Completer<bool>();

  static Future<bool> get future => _completer.future;

  /// `true`: Firebase hazır. `false`: başlatma kesin olarak başarısız.
  static void complete(bool ready) {
    if (!_completer.isCompleted) _completer.complete(ready);
  }

  @visibleForTesting
  static void resetForTest() => _completer = Completer<bool>();
}

class FirebasePushTokenSource
    implements PushTokenSource, PushTokenRefreshSource {
  FirebasePushTokenSource({
    bool Function()? isReady,
    Future<bool> Function()? whenReady,
    Stream<String> Function()? refreshStream,
    Future<String?> Function()? readToken,
  }) : _isReady = isReady ?? _firebaseReady,
       _whenReady = whenReady ?? (() => FirebaseReadiness.future),
       _refreshStream =
           refreshStream ?? (() => FirebaseMessaging.instance.onTokenRefresh),
       _readToken = readToken ?? (() => FirebaseMessaging.instance.getToken());

  static bool _firebaseReady() => !kIsWeb && Firebase.apps.isNotEmpty;

  final bool Function() _isReady;
  final Future<bool> Function() _whenReady;
  final Stream<String> Function() _refreshStream;
  final Future<String?> Function() _readToken;

  Future<bool> _ready() async {
    if (kIsWeb) return false;
    if (_isReady()) return true;
    return await _whenReady() && _isReady();
  }

  @override
  Stream<String> get onTokenRefresh async* {
    if (!await _ready()) return;
    yield* _refreshStream();
  }

  @override
  Future<String?> currentToken() async {
    // Firebase henüz hazır değilse hazır olana dek beklenir (AppShell
    // Firebase'den önce çalışabilir); hiç hazır olmazsa null döner.
    if (!await _ready()) return null;
    // Token senkronizasyonu bir izin isteme yüzeyi değildir. AppShell bunu
    // ilk açılışta ve her resume'da çağırır; burada requestPermission()
    // kullanmak onboarding görünmeden iOS sistem diyaloğunu açıyordu.
    // Kullanıcı izni yalnız NotificationService.setEnabled(true) ile,
    // "Günlük hatırlatıcı"yı bilinçli olarak açtığı anda istenir.
    return _readToken();
  }
}

/// Bu kurulumun FCM jetonunu Firebase'de geçersiz kılar (çıkışta sunucu
/// temizliği düşerse son çare). Firebase yoksa ya da hata olursa sessizce
/// döner; çıkışı asla engellemez.
Future<void> revokeFirebaseDeviceToken({
  bool Function()? isReady,
  Future<void> Function()? deleteToken,
}) async {
  try {
    final ready = (isReady ?? FirebasePushTokenSource._firebaseReady)();
    if (!ready) return;
    await (deleteToken ?? () => FirebaseMessaging.instance.deleteToken())()
        .timeout(const Duration(seconds: 3));
  } catch (_) {
    // En iyi çaba: jeton sonraki girişte zaten yenilenir.
  }
}
