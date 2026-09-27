import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../utils/error_reporter.dart';

/// Bildirime dokununca oynanacak hedef ekran.
///
/// `async_duel_result` → [playTab] (Yarış sekmesi, "Düellolarım" sonucu
/// orada görünür). `friend_request` → [friends] (Liderlik sekmesi +
/// üstüne açılan Arkadaşlar ekranı).
enum PushTapTarget { playTab, friends }

/// Bildirime dokunan oyuncuyu doğru ekrana yönlendirir.
///
/// Bildirime dokunmak her zaman ana ekrana (Öğren sekmesi) düşüyordu:
/// `tool/send_push_outbox.py` FCM'e yalnız `notification: {title, body}`
/// yolluyor, bildirimin TÜRÜNÜ (`kind`) hiç taşımıyordu; uygulama tarafında
/// da dokunuşu dinleyen hiçbir kod yoktu. Bu sınıf iki ucu birleştirir:
/// [wireFirebase] dokunuşu (`onMessageOpenedApp`, soğuk açılışta
/// `getInitialMessage`) dinler, [targetForKind] `kind`i bir [PushTapTarget]e
/// çözer ve [pending]e yazar. [AppShell] `JoinDeepLink` ile AYNI deseni
/// izleyerek kabuk hazır olduğunda [take] ile tüketir.
class PushTapRouter {
  PushTapRouter._();

  /// [kind] bilinen bir bildirim türüyse karşılık gelen hedef, değilse
  /// (bilinmeyen ya da `null`/boş) `null`.
  static PushTapTarget? targetForKind(String? kind) {
    return switch (kind) {
      'async_duel_result' => PushTapTarget.playTab,
      'friend_request' => PushTapTarget.friends,
      _ => null,
    };
  }

  /// Bekleyen bildirim hedefi. [AppShell] dinler; kabuk hazır olduğunda
  /// [take] ile tüketir. Kabuk henüz kurulmamışsa (açılış, giriş) hedef
  /// burada bekler.
  static final ValueNotifier<PushTapTarget?> pending =
      ValueNotifier<PushTapTarget?>(null);

  static bool _firebaseWired = false;

  /// [data] (bir `RemoteMessage.data`) bilinen bir `kind` taşıyorsa hedefi
  /// [pending]e yazar ve `true` döner; değilse `false`.
  static bool offer(Map<String, dynamic> data) {
    // FCM veri değerleri dizedir; yine de başka türde bir değer dinleyicide
    // tür dönüşümü hatasıyla düşmesin.
    final kind = data['kind'];
    final target = targetForKind(kind is String ? kind : null);
    if (target == null) return false;
    // Aynı hedef PENDING'DE dururken yeniden gelirse de dinleyici uyansın
    // diye önce boşaltılır (ValueNotifier aynı değerde bildirim yapmaz) —
    // bkz. `JoinDeepLink.offer`deki aynı desen.
    pending.value = null;
    pending.value = target;
    return true;
  }

  /// Bekleyen hedefi alır ve kanalı boşaltır.
  static PushTapTarget? take() {
    final target = pending.value;
    if (target != null) pending.value = null;
    return target;
  }

  /// Bildirime dokunuşu dinlemeye başlar: uygulama arka plandayken/kapalıyken
  /// dokunulup öne getirilmesi (`onMessageOpenedApp`) ve tamamen kapalıyken
  /// dokunulup soğuk açılması (`getInitialMessage`).
  ///
  /// Web'de ve Firebase hiç başlatılmamışsa (testler, yapılandırma eksik
  /// açılış) sessizce hiçbir şey yapmaz. İkinci çağrı statik bayrakla
  /// engellenir — aksi halde her çağrı `onMessageOpenedApp`e yeniden abone
  /// olur ve tek dokunuş [offer]i birden çok kez tetikler.
  static Future<void> wireFirebase() async {
    if (kIsWeb || Firebase.apps.isEmpty || _firebaseWired) return;
    _firebaseWired = true;
    try {
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        offer(message.data);
      });
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) offer(initial.data);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'push tap wiring failed');
    }
  }

  /// Testler arası statik durumu sıfırlar.
  @visibleForTesting
  static void resetForTest() {
    pending.value = null;
    _firebaseWired = false;
  }
}
