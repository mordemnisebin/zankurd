// Alan 9 #8 (2026-11-06): her sohbet mesajından önce İKİ ek profil okuması
// (`getProfileName` + `loadAvatarIdentity`) yapılıyordu — kalabalık odada her
// mesaj 3 istek demekti. Bekçi: art arda iki mesaj, toplam TEK profil okuması
// ve mesajlar doğru ad/renkle gider; profil yazımı önbelleği siler.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

class _SessionGoTrue extends GoTrueClient {
  _SessionGoTrue()
    : super(url: 'https://example.invalid/auth/v1', autoRefreshToken: false);

  final _user = const User(
    id: 'user-1',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00.000Z',
  );

  @override
  User? get currentUser => _user;
}

class _Client extends SupabaseClient {
  _Client(http.Client httpClient)
    : _auth = _SessionGoTrue(),
      super(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );

  final GoTrueClient _auth;

  @override
  GoTrueClient get auth => _auth;
}

class _Http extends http.BaseClient {
  var profileReads = 0;
  final sent = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    Object body = const [];
    if (request.url.path == '/rest/v1/profiles' && request.method == 'GET') {
      profileReads += 1;
      body = {'display_name': 'Berfin', 'avatar_color': '#123456'};
    } else if (request.url.path == '/rest/v1/room_messages' &&
        request.method == 'POST') {
      sent.add(
        jsonDecode(await (request as http.Request).finalize().bytesToString())
            as Map<String, dynamic>,
      );
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      request.method == 'POST' ? 201 : 200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('art arda iki mesaj tek profil okuması yapar', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = _Http();
    final repository = SupabaseZanKurdRepository(_Client(fake));

    await repository.sendRoomMessage(roomId: 'room-1', text: 'silav');
    await repository.sendRoomMessage(roomId: 'room-1', text: 'çawa yî');

    expect(
      fake.profileReads,
      1,
      reason: 'ad+renk tek okuma, ikincisi önbellek',
    );
    expect(fake.sent, hasLength(2));
    expect(fake.sent.first['sender_name'], 'Berfin');
    expect(fake.sent.first['sender_avatar_color'], '#123456');
    expect(fake.sent.last['text'], 'çawa yî');
  });

  test('ad güncellenince önbellek silinir ve yeni ad okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = _Http();
    final repository = SupabaseZanKurdRepository(_Client(fake));

    await repository.sendRoomMessage(roomId: 'room-1', text: 'bir');
    await repository.upsertProfile(displayName: 'Yeni Ad');
    await repository.sendRoomMessage(roomId: 'room-1', text: 'iki');

    expect(fake.profileReads, 2, reason: 'yazımdan sonra yeniden okunmalı');
  });
}
