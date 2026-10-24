// Bekçi: okuma hatası "boş liste" değildir (C3, ikinci yarı).
//
// ## Kusur
// `loadPendingFriendRequests` / `loadFriends` RPC hatasında `_offline` boş
// listeyi dönüyordu: ekran "bekleyen istek yok" / "arkadaşın yok" diyordu,
// oysa yalnız yükleyememişti. Ekranda hata + "tekrar dene" durumu vardı ama
// hiç tetiklenemiyordu.
//
// ## Niçin sessiz kalırdı
// Boş liste geçerli bir cevaptır; ne istisna ne log vardı.
//
// ## Kural
// Okuma hatası yukarı taşınır; çağıran ekran hata durumunu gösterir.
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

class _DownClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('SocketException: Failed host lookup: example');
  }
}

SupabaseZanKurdRepository _repo() => SupabaseZanKurdRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: _DownClient(),
  ),
);

void main() {
  test(
    'bekleyen istekler yüklenemezse hata fırlar (boş liste değil)',
    () async {
      await expectLater(_repo().loadPendingFriendRequests(), throwsA(anything));
    },
  );

  test('arkadaş listesi yüklenemezse hata fırlar (boş liste değil)', () async {
    await expectLater(_repo().loadFriends(), throwsA(anything));
  });
}
