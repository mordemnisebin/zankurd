import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

/// Sunucu tarafında bir oturumun yerini BAŞKA bir kullanıcı aldığında
/// yerel ilerleme (XP/streak/mistake/rozet/...) eski kullanıcıdan yeni
/// kullanıcıya sessizce devrediyordu.
///
/// ## Kusur
///
/// `XPStore` gibi yerel store'lar SharedPreferences'ta GLOBAL anahtarlarla
/// tutulur (`zankurd.xp.total`), kullanıcıya özel değil. `AuthProvider`ın
/// `onAuthStateChange` dinleyicisi yalnız `SyncManager.restart()`ı
/// tetikliyordu; hiçbir yerde "bu, ÖNCEKİ oturumdan farklı bir kullanıcı
/// mı?" sorusu sorulmuyordu. `signOut()` bu store'ları temizliyordu, ama
/// aktif bir oturumun üzerine `signInWithPassword` ile farklı bir hesaba
/// girildiğinde (GoTrue oturumu doğrudan değiştirir, ara bir `signedOut`
/// olayı hiç gelmez) `signOut()` hiç çağrılmıyordu. Paylaşılan bir
/// cihazda ikinci kullanıcı, birincinin XP'sini/serisini/rozetlerini
/// devralmış oluyordu (2026-08-14 denetimi).
///
/// ## Bekçinin tuttuğu üç şey
///
/// 1. Cihazın son sahibinden FARKLI bir kullanıcı geldiğinde yerel
///    ilerleme temizlenir.
/// 2. AYNI kullanıcının normal yeniden girişinde ilerleme SİLİNMEZ —
///    "hesap değiştiren her oturum açmada sıfırla" değil, "önceki
///    oturumdan farklı bir kullanıcı geldiğinde sıfırla".
/// 3. Bu alan uygulamaya SONRADAN eklendiği için, hiç kayıtlı sahip yokken
///    (var olan bir kullanıcının ilk açılışı) ilerleme silinmez — yalnız
///    sahip kaydedilir.
void main() {
  User user(String id) => User(
    id: id,
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: '2026-08-14T00:00:00Z',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  test(
    'cihazın önceki sahibinden farklı kullanıcı yerel XP\'yi temizler',
    () async {
      SharedPreferences.setMockInitialValues({
        'zankurd.localProgress.deviceOwnerUserId': 'user-old',
        'zankurd.xp.total': 500,
      });
      final provider = AuthProvider.test();

      await provider.debugResetLocalProgressIfForeignUser(user('user-new'));

      XPStore.resetInstance();
      final xp = await XPStore.load();
      expect(xp.totalXP, 0, reason: 'önceki kullanıcının XP\'si devretmemeli');

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('zankurd.localProgress.deviceOwnerUserId'),
        'user-new',
      );
    },
  );

  test('aynı kullanıcının yeniden girişinde ilerleme SİLİNMEZ', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.localProgress.deviceOwnerUserId': 'user-a',
      'zankurd.xp.total': 500,
    });
    final provider = AuthProvider.test();

    await provider.debugResetLocalProgressIfForeignUser(user('user-a'));

    XPStore.resetInstance();
    final xp = await XPStore.load();
    expect(
      xp.totalXP,
      500,
      reason: 'aynı kullanıcının kendi ilerlemesi silinmemeli',
    );
  });

  test(
    'kayıtlı bir cihaz sahibi yokken (özellik yeni eklendi) mevcut ilerleme silinmez, yalnız sahip kaydedilir',
    () async {
      SharedPreferences.setMockInitialValues({'zankurd.xp.total': 500});
      final provider = AuthProvider.test();

      await provider.debugResetLocalProgressIfForeignUser(user('user-a'));

      XPStore.resetInstance();
      final xp = await XPStore.load();
      expect(
        xp.totalXP,
        500,
        reason:
            'zaten oturum açmış kullanıcının ilerlemesi ilk okumada silinmemeli',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('zankurd.localProgress.deviceOwnerUserId'),
        'user-a',
      );
    },
  );
}
