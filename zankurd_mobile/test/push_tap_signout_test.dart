// Bekçi: çıkışta bekleyen bildirim hedefi temizlenir (C2).
//
// ## Kusur
// `PushTapRouter.pending` statik bir `ValueNotifier`dır. A hesabı
// "arkadaşlık isteği" bildirimine dokunup tüketilmeden çıkış yaparsa hedef
// bellekte kalıyordu; aynı cihazda giriş yapan B hesabı AppShell kurulunca
// A'nın bildirimini tüketip Arkadaşlar ekranına atılıyordu.
//
// ## Niçin sessiz kalırdı
// Hata yalnız "çıkış + hemen başka hesapla giriş" sırasında, bildirim
// tüketilmeden önce görünür; AppShell testleri hedefi hep doğrudan verir.
//
// ## Kural
// Açık `signOut()` bekleyen hedefi boşaltır. (Soğuk açılışta oturum
// açılmadan gelen hedef BEKLEMEYE devam eder; o yol signOut değildir.)
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

class _TokenSource implements PushTokenSource {
  @override
  Future<String?> currentToken() async => 'device-token';
}

class _PendingTokenRepository extends MockZanKurdRepository {
  final started = Completer<void>();
  final finish = Completer<void>();
  @override
  Future<void> setFcmToken(String token) async {
    started.complete();
    await finish.future;
    await super.setFcmToken(token);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PushTapRouter.resetForTest();
  });
  tearDown(PushTapRouter.resetForTest);

  test('sunucuda silinmiş hesabın yerel çıkışı token RPC beklemez', () async {
    final repository = _PendingTokenRepository();
    final provider = AuthProvider.test(authenticated: true);
    final write = PushTokenSync(
      source: _TokenSource(),
      repository: repository,
    ).sync();
    await repository.started.future;
    try {
      await provider.signOut(
        discardPendingRewards: true,
        pendingRewardsOwnerId: 'deleted-user',
      );
      expect(repository.finish.isCompleted, isFalse);
      expect(provider.isAuthenticated, isFalse);
    } finally {
      repository.finish.complete();
      await write;
      provider.dispose();
    }
  });

  test('gerçek signOut akışı devam eden token kaydını bekler', () async {
    final repository = _PendingTokenRepository();
    final provider = AuthProvider.test(authenticated: true);
    final write = PushTokenSync(
      source: _TokenSource(),
      repository: repository,
    ).sync();
    await repository.started.future;
    final logout = provider.signOut();
    await Future<void>.delayed(Duration.zero);
    expect(provider.isAuthenticated, isTrue);
    repository.finish.complete();
    await write;
    await logout;
    expect(provider.isAuthenticated, isFalse);
    provider.dispose();
  });

  test('signOut bekleyen bildirim hedefini siler', () async {
    final provider = AuthProvider.test();
    PushTapRouter.offer({'kind': 'friend_request'});
    expect(PushTapRouter.pending.value?.target, PushTapTarget.friends);

    await provider.signOut();

    expect(
      PushTapRouter.pending.value,
      isNull,
      reason: 'sonraki hesap önceki hesabın bildirim hedefini tüketmemeli',
    );
  });
}
