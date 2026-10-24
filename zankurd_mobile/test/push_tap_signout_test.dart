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
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/services/push_tap_router.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PushTapRouter.resetForTest();
  });
  tearDown(PushTapRouter.resetForTest);

  test('signOut bekleyen bildirim hedefini siler', () async {
    final provider = AuthProvider.test();
    PushTapRouter.offer({'kind': 'friend_request'});
    expect(PushTapRouter.pending.value, PushTapTarget.friends);

    await provider.signOut();

    expect(
      PushTapRouter.pending.value,
      isNull,
      reason: 'sonraki hesap önceki hesabın bildirim hedefini tüketmemeli',
    );
  });
}
