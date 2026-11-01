/// G6/G7/G8 kusurları: yalnız yeni katılım yolu, doğru şık gizliliği ve
/// başarılı sunum sınandığı için eski yol/gelecek içerik/kayıtsız cevap sessizdi.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'support/widget_test_helpers.dart';

const _question = QuizQuestion(
  id: 'q',
  category: 'Ziman',
  prompt: 'Visible after presentation',
  answers: ['A', 'B', 'C', 'D'],
  correctAnswer: '',
  explanation: '',
);

class _ContentRepository extends MockZanKurdRepository
    implements AsyncDuelContentPort {
  final gate = Completer<TournamentPresent>();
  @override
  Future<AsyncDuelStart> startAsyncDuel({String? category}) async =>
      AsyncDuelStart(
        duelId: 'duel',
        role: AsyncDuelRole.creator,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        questions: [_question.copyWith(prompt: '', answers: const [])],
      );
  @override
  Future<TournamentPresent> presentAsyncDuelContent(
    String duelId,
    int questionIndex,
  ) => gate.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('G6 eski RPC sınırı atlıyordu; yalnız v2 testleri sessizdi', () {
    final sql = File(
      'supabase/2026-11-01_room_duel_guards.sql',
    ).readAsStringSync();
    expect(sql, contains('select public.join_room_by_code_v2(p_code)'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('from public, anon, authenticated'));
    expect(sql, contains('pg_get_functiondef'));
    // Gerçek SQL davranış bekçisi: tool/test_room_duel_guards_local.mjs.
  });
  test(
    'G7 gelecek içerik önceden geliyordu; yalnız doğru şık gizlenmesi sınanıyordu',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode([
              {
                'id': 'q0',
                'prompt': 'Current',
                'option_a': 'A',
                'option_b': 'B',
              },
              {'id': 'q1', 'index': 1, 'content_hidden': true},
            ]),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      final repo = SupabaseZanKurdRepository(client);
      final room = repo.createRoom(category: 'Ziman').copyWith(id: 'room');
      final rows = await repo.loadRoomQuestions(room);
      expect(rows.map((q) => q.id), ['q0', 'q1']);
      expect(rows[1].prompt, isEmpty);
      expect(rows[1].answers, isEmpty);
      expect(rows[1].correctAnswer, isEmpty);
      await client.dispose();
    },
  );
  for (final missing in [false, true]) {
    test(
      'G8 sunum içeriği ve eski sunucu geri düşüşü ($missing); yalnız sayaç sınanıyordu',
      () async {
        final calls = <String>[];
        final client = SupabaseClient(
          'https://example.supabase.co',
          'test',
          httpClient: MockClient((r) async {
            calls.add(r.url.path.split('/').last);
            if (calls.last == 'present_async_duel_question_v2') {
              if (missing) {
                return http.Response(
                  jsonEncode({
                    'code': 'PGRST202',
                    'message':
                        'Could not find the function public.present_async_duel_question_v2',
                  }),
                  404,
                  request: r,
                  headers: {'content-type': 'application/json'},
                );
              }
              return http.Response(
                jsonEncode({
                  'elapsed_ms': 123,
                  'question': {
                    'id': 'q',
                    'prompt': 'Current',
                    'option_a': 'A',
                    'option_b': 'B',
                  },
                }),
                200,
                request: r,
                headers: {'content-type': 'application/json'},
              );
            }
            return http.Response(
              '{"elapsed_ms":321}',
              200,
              request: r,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        final result = await SupabaseZanKurdRepository(
          client,
        ).presentAsyncDuelContent('duel', 0);
        expect(result.elapsedMs, missing ? 321 : 123);
        expect(result.question?.prompt, missing ? null : 'Current');
        expect(
          calls,
          missing
              ? [
                  'present_async_duel_question_v2',
                  'present_async_duel_question',
                ]
              : ['present_async_duel_question_v2'],
        );
        await client.dispose();
      },
    );
  }
  test(
    'G8 ağ hatası sunumu atlayabiliyordu; eksik RPC ile tüm hatalar karıştırılıyordu',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test',
        httpClient: MockClient((r) async {
          calls++;
          return http.Response(
            '{"message":"unavailable"}',
            503,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await expectLater(
        SupabaseZanKurdRepository(client).presentAsyncDuelContent('duel', 0),
        throwsA(anything),
      );
      expect(calls, 1);
      await client.dispose();
    },
  );
  testWidgets(
    'G8 sunum beklenmeden içerik açılıyordu; yalnız başarılı hızlı sunum sınanıyordu',
    (tester) async {
      final repo = _ContentRepository();
      await tester.pumpWidget(
        testShell(child: AsyncDuelPlayScreen(repository: repo)),
      );
      await tester.pump();
      expect(find.text(_question.prompt), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.gate.complete(
        const TournamentPresent(elapsedMs: 100, question: _question),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text(_question.prompt), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
