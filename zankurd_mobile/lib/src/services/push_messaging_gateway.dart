import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Uygulama AÇIKKEN gelen bir push iletisi (FCM `RemoteMessage`ın uygulamanın
/// ihtiyaç duyduğu kısmı).
class ForegroundPush {
  const ForegroundPush({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;

  /// FCM veri alanları; `kind` bildirim türünü taşır (bkz. [PushTapRouter]).
  final Map<String, dynamic> data;

  String? get kind {
    final value = data['kind'];
    return value is String ? value : null;
  }
}

/// `FirebaseMessaging`in bu uygulamanın kullandığı dar yüzü: izin sorgusu,
/// izin isteği ve ön plan iletileri.
///
/// Firebase'i doğrudan çağırmak testleri cihaza bağlardı; bu arayüz
/// [PushTokenSource] kalıbıyla aynı nedenle vardır: testte sahte bağlanır.
abstract class PushMessagingGateway {
  /// Push bu platformda/oturumda kullanılabilir mi? Web'de ve Firebase hiç
  /// başlatılmamışsa (testler, yapılandırma eksik açılış) `false`: hiçbir
  /// izin istemi çıkmaz, ön plan akışı boş kalır.
  bool get isAvailable;

  /// Sistem bildirim izni verilmiş mi (iOS authorized/provisional; Android
  /// 13+ POST_NOTIFICATIONS ya da bildirimler açık)?
  Future<bool> hasPermission();

  /// Sistem iznini ister (iOS: alert+badge+sound; Android 13+:
  /// POST_NOTIFICATIONS). İzin verildiyse `true`.
  Future<bool> requestPermission();

  /// Uygulama ön plandayken gelen iletiler.
  Stream<ForegroundPush> get onForegroundMessage;
}

/// Üretim gerçeklemesi: `FirebaseMessaging.instance`.
class FirebasePushMessagingGateway implements PushMessagingGateway {
  const FirebasePushMessagingGateway();

  @override
  bool get isAvailable => !kIsWeb && Firebase.apps.isNotEmpty;

  static bool _granted(NotificationSettings settings) =>
      settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  @override
  Future<bool> hasPermission() async {
    if (!isAvailable) return false;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return _granted(settings);
  }

  @override
  Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _granted(settings);
  }

  @override
  Stream<ForegroundPush> get onForegroundMessage {
    if (!isAvailable) return const Stream.empty();
    return FirebaseMessaging.onMessage.map(
      (message) => ForegroundPush(
        title: message.notification?.title,
        body: message.notification?.body,
        data: message.data,
      ),
    );
  }
}

/// Uygulamanın tek [PushMessagingGateway] noktası. Testler [gateway]i
/// değiştirir ve [resetForTest] ile geri alır.
class PushMessaging {
  PushMessaging._();

  static PushMessagingGateway gateway = const FirebasePushMessagingGateway();

  @visibleForTesting
  static void resetForTest() {
    gateway = const FirebasePushMessagingGateway();
  }
}
