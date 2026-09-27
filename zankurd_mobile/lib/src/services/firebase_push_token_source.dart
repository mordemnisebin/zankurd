import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_token_sync.dart';

class FirebasePushTokenSource implements PushTokenSource {
  const FirebasePushTokenSource();

  @override
  Future<String?> currentToken() async {
    if (kIsWeb) return null;
    // Token senkronizasyonu bir izin isteme yüzeyi değildir. AppShell bunu
    // ilk açılışta ve her resume'da çağırır; burada requestPermission()
    // kullanmak onboarding görünmeden iOS sistem diyaloğunu açıyordu.
    // Kullanıcı izni yalnız NotificationService.setEnabled(true) ile,
    // "Günlük hatırlatıcı"yı bilinçli olarak açtığı anda istenir.
    return FirebaseMessaging.instance.getToken();
  }
}
