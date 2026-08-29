import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_token_sync.dart';

class FirebasePushTokenSource implements PushTokenSource {
  const FirebasePushTokenSource();

  @override
  Future<String?> currentToken() async {
    if (kIsWeb) return null;
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    return messaging.getToken();
  }
}
