import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

const _round = '33333333-3333-4333-8333-333333333333';
const _question = QuizQuestion(
  id: '11111111-1111-4111-8111-111111111111',
  category: 'Synthetic',
  prompt: 'Synthetic question',
  answers: ['A', 'B', 'C', 'D'],
  correctAnswer: 'A',
  explanation: '',
);

class _Rpc extends http.BaseClient {
  final calls = <({String name, Map<String, dynamic> params})>[];
  Completer<void>? answerGate;
  bool missing = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final rawBody = await (request as http.Request).finalize().bytesToString();
    final decoded = rawBody.isEmpty ? null : jsonDecode(rawBody);
    final body = decoded == null
        ? <String, dynamic>{}
        : decoded as Map<String, dynamic>;
    final name = request.url.pathSegments.last;
    calls.add((name: name, params: body));
    if (name == 'answer_verified_quiz') await answerGate?.future;
    final Object? result = switch (name) {
      'prepare_verified_solo_questions' => {
        'selection_id': '22222222-2222-4222-8222-222222222222',
        'question_ids': [_question.id],
      },
      'start_verified_quiz' => '44444444-4444-4444-8444-444444444444',
      'answer_verified_quiz' => true,
      'claim_verified_solo_reward' => {'amount': 6},
      'submit_verified_daily_event_result' => true,
      'get_verified_daily_event_board' => null,
      'get_daily_event_board' => null,
      _ => throw StateError('Unexpected RPC: $name'),
    };
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode(
            missing
                ? {'code': 'PGRST202', 'message': 'Missing migration'}
                : result,
          ),
        ),
      ),
      missing ? 404 : 200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

class _Repo extends SupabaseZanKurdRepository {
  _Repo(_Rpc rpc)
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'test-key',
          httpClient: rpc,
        ),
      );
  String owner = 'synthetic-user';
  @override
  String? get currentUserId => owner;
  @override
  List<QuizQuestion> get playableQuestions => [_question];
  @override
  Future<void> ensureProfile() async {}
  @override
  Future<User> signInAnonymously() async => User(
    id: owner,
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-11-01T00:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'G5 son cevap beklenmezse sessiz eksik ödül: eski test yalnız özeti gönderirdi',
    () async {
      final rpc = _Rpc()..answerGate = Completer<void>();
      final repo = _Repo(rpc);
      final questions = await repo.loadQuestions(limit: 1);
      await repo.startVerifiedSoloRound(
        clientRoundId: _round,
        questions: questions,
        daily: false,
      );
      final answer = repo.recordVerifiedSoloAnswer(
        clientRoundId: _round,
        questionId: _question.id,
        choice: 'A',
      );
      final reward = repo.awardSoloQuizCoins(
        score: 999,
        correctCount: 50,
        bestStreak: 50,
        totalQuestions: 50,
        clientRoundId: _round,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        rpc.calls.map((c) => c.name),
        isNot(contains('claim_verified_solo_reward')),
      );
      rpc.answerGate!.complete();
      await answer;
      expect((await reward).amount, 6);
      expect(rpc.calls.last.params, {'p_client_round_id': _round});
      expect(rpc.calls[1].params['p_selection_id'], isNotNull);
    },
  );

  test(
    'G5 keyfi soru oturumu: eski beyan testleri sunucu seçim biletini aramıyordu',
    () async {
      final rpc = _Rpc();
      final repo = _Repo(rpc);
      await repo.startVerifiedSoloRound(
        clientRoundId: _round,
        questions: [_question],
        daily: false,
      );
      await repo.recordVerifiedSoloAnswer(
        clientRoundId: _round,
        questionId: _question.id,
        choice: 'A',
      );
      expect(rpc.calls, isEmpty);
    },
  );

  test(
    'G5 hesap değişimi: gecikmiş cevap yeni sahibin RPC kimliğiyle sessizce gönderilirdi',
    () async {
      final rpc = _Rpc();
      final repo = _Repo(rpc);
      final questions = await repo.loadQuestions(limit: 1);
      await repo.startVerifiedSoloRound(
        clientRoundId: _round,
        questions: questions,
        daily: false,
      );
      repo.owner = 'different-user';
      await repo.recordVerifiedSoloAnswer(
        clientRoundId: _round,
        questionId: _question.id,
        choice: 'A',
      );
      expect(
        rpc.calls.map((c) => c.name),
        isNot(contains('answer_verified_quiz')),
      );
    },
  );

  test(
    'G9 sahte 20/20 ve sıfır saniye: gösterim denilerek eski sonuç doğrulaması sessiz kalmıştı',
    () async {
      final rpc = _Rpc();
      final repo = _Repo(rpc);
      expect(
        await repo.submitDailyEventResult(correct: 20, total: 20, seconds: 0),
        isFalse,
      );
      expect(rpc.calls, isEmpty);
      expect(await repo.submitVerifiedDailyResult(_round), isTrue);
      expect(rpc.calls.single.params, {'p_client_round_id': _round});
    },
  );

  test(
    'G9 iki pano da yoksa dürüst null döner; eski skor yazımı açılmaz',
    () async {
      final rpc = _Rpc()..missing = true;
      final repo = _Repo(rpc);
      expect(await repo.loadDailyEventBoard(), isNull);
      expect(await repo.submitVerifiedDailyResult(_round), isFalse);
      expect(rpc.calls.map((c) => c.name), [
        'get_verified_daily_event_board',
        'get_daily_event_board',
        'submit_verified_daily_event_result',
      ]);
    },
  );

  test(
    'G5/G9 göç güvenliği: eski dosya varlığı testleri açık ACL ve beyan yollarını sessizce kaçırdı',
    () {
      final migration = File(
        'supabase/2026-11-01_solo_daily_verified.sql',
      ).readAsStringSync();
      final rollback = File(
        'supabase/geri_al/2026-11-01_solo_daily_verified.sql',
      ).readAsStringSync();
      expect(migration, contains('pg_get_functiondef(v_oid)'));
      expect(migration, contains('Server selection required'));
      expect(
        migration,
        contains(
          'on public.verified_quiz_sessions(user_id, day) where is_daily',
        ),
      );
      expect(
        migration,
        contains('v_session.completed_at - v_session.started_at'),
      );
      expect(migration, contains("' from public, anon'"));
      expect(migration, contains('public.app_today() + 1'));
      expect(rollback, contains('execute v_backup.definition'));
      expect(File('tool/verified_quiz_sql_smoke.mjs').existsSync(), isTrue);
    },
  );
}
