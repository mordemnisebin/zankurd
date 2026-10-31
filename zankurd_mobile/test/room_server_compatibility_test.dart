import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

http.Response _json(Object? value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
http.Response _error(String message, {String code = 'P0001'}) =>
    _json({'message': message, 'code': code}, 400);

class _Repository extends SupabaseZanKurdRepository {
  _Repository(super.client);
  @override
  Future<void> ensureProfile() async {}
}

SupabaseClient _client(Future<http.Response> Function(http.Request) handle) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'fixture-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/v1/signup') {
        final expiry =
            DateTime.now()
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch ~/
            1000;
        String segment(Object value) => base64Url
            .encode(utf8.encode(jsonEncode(value)))
            .replaceAll('=', '');
        return _json({
          'access_token':
              '${segment({'alg': 'HS256'})}.${segment({'sub': 'test-user', 'exp': expiry})}.fixture',
          'refresh_token': 'fixture-refresh',
          'token_type': 'bearer',
          'expires_in': 86400,
          'expires_at': expiry,
          'user': {
            'id': 'test-user',
            'aud': 'authenticated',
            'created_at': '2026-10-31T00:00:00Z',
            'app_metadata': {},
            'user_metadata': {},
          },
        });
      }
      final response = await handle(request);
      return http.Response(
        response.body,
        response.statusCode,
        headers: response.headers,
        request: request,
      );
    }),
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final message in [
    'Unsupported seconds per question',
    'Unsupported question count',
    'Unsupported entry fee',
  ]) {
    test(
      'göçsüz sınırlar yetenekle süzülür ($message); yalnız modern mock sessiz bıraktı',
      () async {
        var calls = 0;
        final client = _client((request) async {
          calls++;
          expect(request.url.path, '/rest/v1/rpc/create_online_room_v2');
          expect(jsonDecode(request.body), {
            'p_category_names': [],
            'p_seconds_per_question': 120,
            'p_question_count': 50,
            'p_entry_fee': -1,
          });
          return _error(message);
        });
        final repository = _Repository(client);
        expect(
          await repository.supportsExtendedRoomOptions(),
          message == 'Unsupported entry fee',
        );
        expect(
          await repository.supportsExtendedRoomOptions(),
          message == 'Unsupported entry fee',
        );
        expect(calls, 1);
      },
    );
  }

  test(
    'belirsiz yetenek yeni seçenek açmaz ve kalıcı olmaz; ağsız mock sessiz bıraktı',
    () async {
      var calls = 0;
      final repository = _Repository(
        _client(
          (request) async => ++calls == 1
              ? _error('temporary failure', code: '503')
              : _error('Unsupported entry fee'),
        ),
      );
      expect(await repository.supportsExtendedRoomOptions(), isFalse);
      expect(await repository.supportsExtendedRoomOptions(), isTrue);
      expect(calls, 2);
    },
  );

  test(
    'sınır reddi sessiz küçültme yapmaz; eski başarı fixture yeniden seçimi gizledi',
    () async {
      final requests = <Map<String, dynamic>>[];
      final client = _client((request) async {
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return _error('Unsupported seconds per question');
      });
      await client.auth.signInAnonymously();
      final repository = _Repository(client);
      await expectLater(
        repository.createOnlineRoom(questionCount: 50, secondsPerQuestion: 120),
        throwsA(isA<RoomOptionsUnsupported>()),
      );
      expect(await repository.supportsExtendedRoomOptions(), isFalse);
      expect(requests, hasLength(1));
      expect(requests.single['p_question_count'], 50);
      expect(requests.single['p_entry_fee'], 0);
    },
  );

  for (final modernTerms in [false, true]) {
    test(
      'eksik hedef RPC daveti listeden bulur (terms=$modernTerms); yalnız yeni göç fixture sessiz bıraktı',
      () async {
        final calls = <String>[];
        final client = _client((request) async {
          calls.add(request.url.path);
          if (request.url.path.endsWith('list_my_room_invites') &&
              request.body.contains('p_invite_id')) {
            return _error('missing RPC', code: 'PGRST202');
          }
          if (request.url.path.endsWith('list_my_room_invites_v2') &&
              !modernTerms) {
            return _error('missing RPC', code: 'PGRST202');
          }
          if (request.url.path.contains('list_my_room_invites')) {
            return _json([
              for (final id in ['other', 'target'])
                {
                  'invite_id': id,
                  'room_id': 'room-$id',
                  'room_code': '123456',
                  'inviter_id': '',
                  'inviter_name': 'Rojda',
                  'category_name': 'Ziman',
                  'player_count': 1,
                  'max_players': 2,
                  'created_at': '2026-10-31',
                  if (modernTerms) 'entry_fee': 25,
                },
            ]);
          }
          fail('Unexpected request: ${request.url}');
        });
        await client.auth.signInAnonymously();
        final invites = await _Repository(
          client,
        ).loadMyRoomInvites(inviteId: 'target', throwOnError: true);
        expect(invites.single.id, 'target');
        expect(invites.single.entryFee, modernTerms ? 25 : null);
        expect(invites.single.hasLegacyTerms, !modernTerms);
        expect(calls, hasLength(modernTerms ? 2 : 3));
      },
    );
  }

  test(
    'ücret aralığı ve negatif ücret yoklaması eski SQL ile aynı; yalnız Dart mock sessiz bıraktı',
    () {
      for (final path in [
        'supabase/2026-10-18_oda_kod_kategori.sql',
        'supabase/2026-10-31_room_limits.sql',
      ]) {
        final sql = File(path).readAsStringSync();
        final start = sql.indexOf(
          'CREATE OR REPLACE FUNCTION public.create_online_room_impl(',
        );
        final body = sql.substring(start, sql.indexOf('\$function\$;', start));
        final feeSet = RegExp(
          r'p_entry_fee not in \(([^)]+)\)',
        ).firstMatch(body)!;
        expect(
          feeSet.group(1)!.split(',').map((n) => int.parse(n.trim())),
          GameRoom.allowedEntryFees,
        );
        final feeRejection = body.indexOf(
          "raise exception 'Unsupported entry fee'",
        );
        expect(
          feeRejection,
          greaterThan(
            body.indexOf("raise exception 'Unsupported question count'"),
          ),
        );
        for (final effect in [
          'pg_advisory_xact_lock',
          'for update',
          'delete from',
          'insert into',
        ]) {
          expect(
            body.indexOf(effect),
            greaterThan(feeRejection),
            reason: '$path: $effect',
          );
        }
      }
    },
  );
}
