/// FCM jeton kaynağı — Firebase geç hazır olduğunda yenileme bekçisi.
///
/// ## Kusur (GPT-6 Pro ALAN 4)
///
/// AppShell Firebase'den önce kurulursa `onTokenRefresh` kapanmış
/// `Stream.empty()` döndürüyor ve ilk jeton `null` okunuyordu; Firebase
/// sonradan hazır olunca abonelik yenilenmiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Hata yok; resume tek seferlik okumayı kurtarır ama kayıp yenileme
/// aboneliğini onarmaz. Jeton döndüğünde sunucu eski jetonda kalır ve push
/// yalnız o cihaza ulaşmaz — kullanıcı da nedenini göremez.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/firebase_push_token_source.dart';

void main() {
  test('Firebase sonradan hazır olunca yenileme akışı ona bağlanır', () async {
    var ready = false;
    final readiness = Completer<bool>();
    final refresh = StreamController<String>();
    final source = FirebasePushTokenSource(
      isReady: () => ready,
      whenReady: () => readiness.future,
      refreshStream: () => refresh.stream,
      readToken: () async => 'ilk',
    );
    final received = <String>[];
    final sub = source.onTokenRefresh.listen(received.add);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(received, isEmpty);
    ready = true; // Firebase şimdi hazır.
    readiness.complete(true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    refresh.add('yeni-jeton');
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(received, ['yeni-jeton']);
    await sub.cancel();
    await refresh.close();
  });

  test('başlatma kesin başarısızsa akış kapanır, jeton null', () async {
    final source = FirebasePushTokenSource(
      isReady: () => false,
      whenReady: () async => false,
      refreshStream: () => const Stream<String>.empty(),
      readToken: () async => 'x',
    );
    expect(await source.onTokenRefresh.toList(), isEmpty);
    expect(await source.currentToken(), isNull);
  });

  test('ilk okuma Firebase hazır olunca yapılır', () async {
    var ready = false;
    final readiness = Completer<bool>();
    final source = FirebasePushTokenSource(
      isReady: () => ready,
      whenReady: () => readiness.future,
      refreshStream: () => const Stream<String>.empty(),
      readToken: () async => 'jeton',
    );
    final future = source.currentToken();
    await Future<void>.delayed(const Duration(milliseconds: 10));
    ready = true;
    readiness.complete(true);
    expect(await future, 'jeton');
  });

  test('hiç başlamayan Firebase (test) bekleyen zamanlayıcı bırakmaz', () {
    // Gerçek kaynak, Firebase yokken zamanlayıcı yerine tamamlanmamış bir
    // Future bekler: widget testleri "pending timer" ile kırılmaz.
    FirebaseReadiness.resetForTest();
    final source = FirebasePushTokenSource();
    unawaited(source.currentToken());
  });
}
