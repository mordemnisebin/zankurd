// Lobide öteki oyuncular adlarıyla değil "Oyuncu" olarak görünüyordu:
// oda oyuncuları `profiles(...)` gömülü seçimle okunuyor, ama `profiles`
// RLS'i yalnız kendi satırını okutuyor; gömülü profil öteki oyuncular için
// null geliyordu. Test sahte istemcide hep profili doldurduğundan kusur
// görünmüyordu; kalabalık oda simülatör denemesi yakaladı (2026-10-16).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

class _Http extends http.BaseClient {
  final paths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    Object? body;
    if (request.url.path == '/rest/v1/room_players') {
      body = [
        {
          'player_id': 'me',
          'score': 0,
          'streak': 0,
          'is_ready': true,
          'left_at': null,
          'profiles': {'display_name': 'Ez'},
        },
        {
          'player_id': 'other',
          'score': 0,
          'streak': 0,
          'is_ready': false,
          'left_at': null,
          'profiles': null,
        },
      ];
    } else if (request.url.path == '/rest/v1/rpc/get_public_profiles') {
      body = [
        {'id': 'other', 'display_name': 'Rojda', 'avatar_icon': 'star'},
      ];
    } else {
      body = <Object>[];
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

void main() {
  test(
    'gömülü profili gelmeyen oyuncunun adı açık profilden tamamlanır',
    () async {
      final httpClient = _Http();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000077',
        name: 'oda',
        code: 'ZK-ABCDEF0123',
        category: 'Ziman',
        players: [],
        status: RoomStatus.lobby,
      );

      final players = await repository.loadRoomPlayers(room);

      expect(players.map((p) => p.name), ['Ez', 'Rojda']);
      expect(players.last.avatarIcon, 'star');
      expect(httpClient.paths, contains('/rest/v1/rpc/get_public_profiles'));
    },
  );
}
