// Bekçi: arkadaşlık isteği sonucu ayrıştırılır; okuma hatası "boş" değildir (C3).
//
// ## Kusur
// 1. `addFriend` sunucunun `success`/`message` cevabını tek bir `bool`a
//    eziyordu: "engellendi", "zaten arkadaşsınız", "istek zaten bekliyor",
//    hız sınırı ve karşılıklı isteğin otomatik kabulü ekranda aynı
//    "İstek gönderilemedi" ya da (otomatik kabulde) yanlış "İstek
//    gönderildi" idi.
// 2. `loadPendingFriendRequests` / `loadFriends` RPC hatasında `_offline`
//    boş listeyi dönüyordu: ekran "bekleyen istek yok" / "arkadaşın yok"
//    diyordu, oysa yalnız yükleyememişti. Ekranda hata + "tekrar dene"
//    durumu var ama hiç tetiklenemiyordu.
//
// ## Niçin sessiz kalırdı
// Hiçbir yerde istisna ya da log görünmez; ekran her zaman dolu bir
// cümle gösterirdi, yalnız yanlış cümleyi.
//
// ## Kural
// `addFriend` yazılı bir sonuç ([AddFriendOutcome]) döner ve ekran her
// sonuç için doğru cümleyi gösterir. Okuma hatası yukarı taşınır.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/add_friend_outcome.dart';

class _RpcClient extends http.BaseClient {
  _RpcClient(this.responses);

  /// RPC adı → JSON gövde; olmayan ad ağ hatası gibi düşer.
  final Map<String, Object> responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final name = request.url.pathSegments.last;
    final body = responses[name];
    if (body == null) {
      throw Exception('SocketException: Failed host lookup: $name');
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

SupabaseZanKurdRepository _repo(Map<String, Object> responses) =>
    SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _RpcClient(responses),
      ),
    );

Future<AddFriendOutcome> _add(Map<String, Object> responses) =>
    _repo(responses).addFriend('friend-1', 'Berfin');

void main() {
  Map<String, Object> reply(bool success, String message) => {
    'add_friend': [
      {'success': success, 'message': message},
    ],
  };

  test('gönderildi', () async {
    expect(
      await _add(reply(true, 'Friend request sent')),
      AddFriendOutcome.sent,
    );
  });

  test('karşılıklı istek otomatik kabul edildi', () async {
    expect(
      await _add(reply(true, 'Friend request accepted')),
      AddFriendOutcome.autoAccepted,
    );
  });

  test('zaten arkadaş', () async {
    expect(
      await _add(reply(false, 'Already friends')),
      AddFriendOutcome.alreadyFriends,
    );
  });

  test('istek zaten bekliyor', () async {
    expect(
      await _add(reply(false, 'Friend request already pending')),
      AddFriendOutcome.alreadyPending,
    );
  });

  test('engellendi', () async {
    expect(
      await _add(reply(false, 'Friend request blocked')),
      AddFriendOutcome.blocked,
    );
  });

  test('hız sınırı / bekleme süresi', () async {
    expect(
      await _add(reply(false, 'Too many friend requests')),
      AddFriendOutcome.rateLimited,
    );
    expect(
      await _add(reply(false, 'Please wait: cooldown active')),
      AddFriendOutcome.rateLimited,
    );
  });

  test('tanınmayan ret ve ağ hatası failed olur', () async {
    expect(
      await _add(reply(false, 'Authenticated user required')),
      AddFriendOutcome.failed,
    );
    expect(await _add(const {}), AddFriendOutcome.failed);
  });
}
