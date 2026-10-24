// Bekçi: onAuthStateChange hata akışı (A4).
//
// ## Kusur
// `AuthProvider._wireAuth` `onAuthStateChange.listen(...)` çağrısına
// `onError` vermiyordu. OAuth yönlendirme hatası (ör. `error_description`
// içeren geri dönüş bağlantısı) gotrue tarafından akışa HATA olarak yazılır;
// dinleyicide işleyici yoksa hata yakalanmamış bölge hatası olur.
//
// ## Niçin sessiz kalırdı
// Kullanıcı hiçbir şey görmezdi: giriş ekranı aynı kalır, hata yalnız
// konsola/rapora düşerdi. Testlerde de akışa hiç hata yazılmadığı için
// görünmezdi.
//
// ## Kural
// Akış hatası eşlenmiş mesajla `errorMessage`e yazılır ve dinleyicilere
// bildirilir; yakalanmamış hata kalmaz.
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';

void main() {
  test('onAuthStateChange hatası errorMessage olur ve bildirilir', () async {
    final client = SupabaseClient('https://example.supabase.co', 'anon-key');
    final provider = AuthProvider(client);
    var notified = 0;
    provider.addListener(() => notified++);

    // ignore: invalid_use_of_internal_member
    client.auth.notifyException(
      const AuthException(
        'For security purposes, you can only request this after 30 seconds.',
        statusCode: '429',
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(provider.errorMessage, K.authErrRateLimit);
    expect(notified, greaterThan(0));
    provider.dispose();
  });

  test('beklenmeyen akış hatası genel mesaja düşer', () async {
    final client = SupabaseClient('https://example.supabase.co', 'anon-key');
    final provider = AuthProvider(client);

    // ignore: invalid_use_of_internal_member
    client.auth.notifyException(StateError('boom'));
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(provider.errorMessage, isNotNull);
    provider.dispose();
  });
}
