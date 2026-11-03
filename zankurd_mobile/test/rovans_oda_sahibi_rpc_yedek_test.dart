/// T2 (2026-11-03): `room_heartbeat` / `update_room_settings` göçü canlıda
/// yokken (PGRST202 / 42883) istemci ESKİ davranışta kalmalı.
///
/// ## Kusur
///
/// Yeni RPC'leri koşulsuz çağıran istemci, göç uygulanmadan yayınlanırsa
/// lobide her yoklama turunda (3-6 sn) başarısız bir istek atar ve hatayı
/// kaydeder; ayar düğmesi basınca "oda açılamadı" der.
///
/// ## Niçin sessiz kalırdı
///
/// Sahte depolar RPC'yi hep var sayar; hata yalnız göçsüz canlı sunucuda
/// ve yalnız lobide çıkar. Bu dosya gerçek `SupabaseZanKurdRepository`yi
/// 404/PGRST202 döndüren bir HTTP istemcisiyle sınar: bir kez görülen eksik
/// RPC tekrar denenmez, ayar düzenleme kapanır, diğer hatalar eksik sayılmaz.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

class _Client extends http.BaseClient {
  _Client(this.handler);
  final http.Response Function(http.Request) handler;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final result = handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(result.bodyBytes),
      result.statusCode,
      headers: result.headers,
      request: request,
    );
  }
}

class _Repository extends SupabaseZanKurdRepository {
  _Repository(super.client);
  @override
  String? get currentUserId => 'host-user';
}

http.Response _json(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

const _room = GameRoom(
  id: 'room-1',
  name: '1vs1',
  code: '482913',
  category: 'Ziman',
  players: [],
  status: RoomStatus.lobby,
  hostId: 'host-user',
  isCustom: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final code in ['PGRST202', '42883']) {
    test(
      'heartbeat RPC yoksa ($code) null döner ve bir daha denenmez',
      () async {
        final calls = <String>[];
        final client = SupabaseClient(
          'https://example.invalid',
          'test',
          httpClient: _Client((r) {
            calls.add(r.url.pathSegments.last);
            return _json({'code': code, 'message': 'Missing RPC'}, 404);
          }),
        );
        addTearDown(client.dispose);
        final repo = _Repository(client);

        expect(await repo.roomHeartbeat(_room), isNull);
        expect(await repo.roomHeartbeat(_room), isNull);
        expect(calls, ['room_heartbeat'], reason: 'eksik RPC tekrar denenmez');
      },
    );

    test('ayar RPC yoksa ($code) RoomLiveUnsupported + düzenleme kapanır', () {
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: _Client(
          (r) => _json({'code': code, 'message': 'Missing RPC'}, 404),
        ),
      );
      addTearDown(client.dispose);
      final repo = _Repository(client);
      expect(repo.roomSettingsEditable, isTrue);
      return expectLater(
        repo.updateRoomSettings(
          room: _room,
          category: 'Ziman',
          secondsPerQuestion: 30,
          questionCount: 20,
        ),
        throwsA(isA<RoomLiveUnsupported>()),
      ).then((_) => expect(repo.roomSettingsEditable, isFalse));
    });
  }

  test('yetki hatası eksik göç sayılmaz: RoomSettingsException', () async {
    final client = SupabaseClient(
      'https://example.invalid',
      'test',
      httpClient: _Client(
        (r) => _json({
          'code': 'P0001',
          'message': 'Only the room host can change settings',
        }, 400),
      ),
    );
    addTearDown(client.dispose);
    final repo = _Repository(client);
    await expectLater(
      repo.updateRoomSettings(
        room: _room,
        category: 'Ziman',
        secondsPerQuestion: 30,
        questionCount: 20,
      ),
      throwsA(isA<RoomSettingsException>()),
    );
    expect(repo.roomSettingsEditable, isTrue);
  });

  test(
    'ayar RPC parametreleri: Karışık boş dizi, çok kategori ayrılır',
    () async {
      final bodies = <Map<String, dynamic>>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test',
        httpClient: _Client((r) {
          bodies.add(jsonDecode(r.body) as Map<String, dynamic>);
          return _json({
            'host_id': 'host-user',
            'status': 'lobby',
            'category_name': 'Tevlihev',
            'seconds_per_question': 30,
            'question_count': 20,
          });
        }),
      );
      addTearDown(client.dispose);
      final repo = _Repository(client);
      final state = await repo.updateRoomSettings(
        room: _room,
        category: 'Tevlihev',
        secondsPerQuestion: 30,
        questionCount: 20,
      );
      await repo.updateRoomSettings(
        room: _room,
        category: 'Ziman, Dîrok',
        secondsPerQuestion: 30,
        questionCount: 20,
      );
      expect(bodies[0]['p_category_names'], isEmpty);
      expect(bodies[1]['p_category_names'], ['Ziman', 'Dîrok']);
      expect(bodies[0]['p_room_id'], 'room-1');
      expect(state.secondsPerQuestion, 30);
      expect(state.questionCount, 20);
      expect(state.status, RoomStatus.lobby);
    },
  );
}
