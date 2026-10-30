import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final guest in [true, false]) {
    test(
      'T16 daily RPC own stats: guest=$guest, valid/empty/missing/broken',
      () async {
        final boundaries = [
          for (var i = 0; i < 8; i++) DateTime(2026, 10, 24 + i),
        ];
        final validHistory = [
          for (var i = 0; i < 7; i++) {'correct': i == 6 ? 8 : 0, 'wrong': 0},
        ];
        Object? body = validHistory;
        var status = 200;
        var reads = 0;
        var transportFails = false;
        final client = SupabaseClient(
          'http://127.0.0.1:55441',
          'local-fixture',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            expect(request.url.host, '127.0.0.1');
            if (request.url.path == '/auth/v1/signup') {
              final expiry =
                  DateTime.now()
                      .add(const Duration(days: 1))
                      .millisecondsSinceEpoch ~/
                  1000;
              String segment(Object value) => base64Url
                  .encode(utf8.encode(jsonEncode(value)))
                  .replaceAll('=', '');
              return http.Response(
                jsonEncode({
                  'access_token':
                      '${segment({'alg': 'HS256'})}.${segment({'sub': 'guest-fixture', 'exp': expiry})}.fixture',
                  'refresh_token': 'fixture',
                  'token_type': 'bearer',
                  'expires_in': 86400,
                  'user': {
                    'id': 'guest-fixture',
                    'aud': 'authenticated',
                    'created_at': '2026-10-30T00:00:00Z',
                    'is_anonymous': guest,
                    'app_metadata': <String, Object>{},
                    'user_metadata': <String, Object>{},
                  },
                }),
                200,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
            expect(
              request.url.path,
              '/rest/v1/rpc/get_my_online_answer_history',
            );
            expect(jsonDecode(request.body), {
              'p_day_boundaries': [
                for (final day in boundaries) day.toUtc().toIso8601String(),
              ],
            }, reason: 'No caller-selected player id');
            reads++;
            if (transportFails) throw http.ClientException('offline');
            return http.Response(
              jsonEncode(body),
              status,
              headers: {'content-type': 'application/json'},
              request: request,
            );
          }),
        );
        addTearDown(client.dispose);
        final repo = SupabaseZanKurdRepository(client);
        expect(
          await repo.loadOnlineAnswerHistory(dayBoundaries: boundaries),
          isNull,
        );
        expect(reads, 0);
        await client.auth.signInAnonymously();
        expect(await repo.loadOnlineAnswerHistory(dayBoundaries: boundaries), [
          for (var i = 0; i < 7; i++) (correct: i == 6 ? 8 : 0, wrong: 0),
        ]);
        body = null;
        expect(
          await repo.loadOnlineAnswerHistory(dayBoundaries: boundaries),
          isNull,
        );
        for (final invalid in [
          <String, Object>{},
          [],
          [
            {'correct': 1, 'wrong': 0},
          ],
          [
            for (var i = 0; i < 7; i++) {'correct': -1, 'wrong': 0},
          ],
          [
            for (var i = 0; i < 7; i++) {'correct': 1.5, 'wrong': 0},
          ],
          [
            for (var i = 0; i < 7; i++) {'correct': '8', 'wrong': 0},
          ],
          [
            for (var i = 0; i < 7; i++) {'correct': 0},
          ],
        ]) {
          body = invalid;
          await expectLater(
            repo.loadOnlineAnswerHistory(dayBoundaries: boundaries),
            throwsFormatException,
          );
        }
        body = {'code': 'PGRST202', 'message': 'RPC unavailable'};
        status = 404;
        await expectLater(
          repo.loadOnlineAnswerHistory(dayBoundaries: boundaries),
          throwsA(isA<PostgrestException>()),
        );
        transportFails = true;
        await expectLater(
          repo.loadOnlineAnswerHistory(dayBoundaries: boundaries),
          throwsA(isA<http.ClientException>()),
        );
      },
    );
  }
}
