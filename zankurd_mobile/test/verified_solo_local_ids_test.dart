import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/server_question_id.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Doğrulanmış solo tur, paketli (uuid OLMAYAN) yerel kimlikli sorularla.
///
/// ## Kusur (alan 6 #1 + #5, W6)
///
/// `verified_solo_daily_test.dart` yalnız doğrudan uuid kimlikli yapay soru
/// kullanıyordu; gerçek bankada kimlikler `r12_sinema_001` gibi olduğundan
/// sunucunun seçtiği uuid'ler yerelde HİÇ bulunmuyor, her tur sessizce yerel
/// (doğrulanmamış) tura düşüyordu ve test bunu göremiyordu. Bu bekçi gerçek
/// biçimli kimliklerle uçtan uca sözleşmeyi sınar: eşleme, sunucuya giden
/// kimlikler (uuid5), oy/rapor kimliği ve eksik soruda yeniden deneme.
const _round = '33333333-3333-4333-8333-333333333333';
const _selection = '22222222-2222-4222-8222-222222222222';
const _serverOnly = 'e9100141-df1c-48a6-b4ec-9d0d9ad9a956';

QuizQuestion _local(String id) => QuizQuestion(
  id: id,
  category: 'Sînema',
  prompt: 'Soru $id',
  answers: const ['A', 'B', 'C', 'D'],
  correctAnswer: 'A',
  explanation: '',
);

final _bank = [
  _local('r12_sinema_001'),
  _local('r12_sinema_002'),
  _local('hat_0011'),
];

class _Rpc extends http.BaseClient {
  _Rpc(this.selections);

  /// Her `prepare_verified_solo_questions` çağrısı sıradakini döndürür.
  final List<List<String>> selections;
  final calls = <({String name, Map<String, dynamic> params})>[];
  var _prepared = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final raw = await (request as http.Request).finalize().bytesToString();
    final params = raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    final name = request.url.pathSegments.last;
    calls.add((name: name, params: params));
    final Object? result = switch (name) {
      'prepare_verified_solo_questions' => {
        'selection_id': _selection,
        'question_ids': selections[_prepared++ % selections.length],
      },
      'start_verified_quiz' => '44444444-4444-4444-8444-444444444444',
      'answer_verified_quiz' => true,
      'rate_question' => null,
      'report_question' => null,
      'question_reports' => null,
      _ => throw StateError('Unexpected RPC: $name'),
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(result))),
      name == 'question_reports' ? 201 : 200,
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
  @override
  String? get currentUserId => 'synthetic-user';
  @override
  List<QuizQuestion> get playableQuestions => _bank;
  @override
  Future<void> ensureProfile() async {}
  @override
  Future<User> signInAnonymously() async => User(
    id: 'synthetic-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-11-01T00:00:00Z',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'sunucu uuid\'leri yerel paketli sorulara eşlenir ve tur doğrulanır',
    () async {
      final ids = [for (final q in _bank.take(2)) serverQuestionId(q.id)];
      final rpc = _Rpc([ids]);
      final repo = _Repo(rpc);
      final turn = await repo.loadQuestions(limit: 2);
      expect(turn.map((q) => q.id), ['r12_sinema_001', 'r12_sinema_002']);
      expect(rpc.calls.map((c) => c.name), ['prepare_verified_solo_questions']);

      await repo.startVerifiedSoloRound(
        clientRoundId: _round,
        questions: turn,
        daily: false,
      );
      // Sunucuya YEREL değil uuid5 kimlikleri gider (başlangıç ve cevap).
      final start = rpc.calls.firstWhere(
        (c) => c.name == 'start_verified_quiz',
      );
      expect(start.params['p_question_ids'], ids);
      expect(start.params['p_selection_id'], _selection);
      await repo.recordVerifiedSoloAnswer(
        clientRoundId: _round,
        questionId: 'r12_sinema_001',
        choice: 'A',
      );
      final answer = rpc.calls.lastWhere(
        (c) => c.name == 'answer_verified_quiz',
      );
      expect(answer.params['p_question_id'], ids.first);
    },
  );

  test(
    'yerelde olmayan sunucu sorusu tüm seti düşürmez: yeni bilet istenir',
    () async {
      final good = [for (final q in _bank.take(2)) serverQuestionId(q.id)];
      final rpc = _Rpc([
        [good.first, _serverOnly],
        good,
      ]);
      final repo = _Repo(rpc);
      final turn = await repo.loadQuestions(limit: 2);
      expect(turn.map((q) => q.id), ['r12_sinema_001', 'r12_sinema_002']);
      expect(
        rpc.calls.where((c) => c.name == 'prepare_verified_solo_questions'),
        hasLength(2),
      );
    },
  );

  test(
    'hep eksik gelirse en çok 3 bilet istenir, sonra yerel tura düşülür',
    () async {
      final rpc = _Rpc([
        [serverQuestionId('r12_sinema_001'), _serverOnly],
      ]);
      final repo = _Repo(rpc);
      final turn = await repo.loadQuestions(limit: 2);
      expect(turn, hasLength(2), reason: 'yerel yedek tur yine de gelir');
      expect(
        rpc.calls.where((c) => c.name == 'prepare_verified_solo_questions'),
        hasLength(3),
      );
      // Biletsiz tur doğrulanmış sayılmaz: başlangıç gönderilmez.
      await repo.startVerifiedSoloRound(
        clientRoundId: _round,
        questions: turn,
        daily: false,
      );
      expect(
        rpc.calls.map((c) => c.name),
        isNot(contains('start_verified_quiz')),
      );
    },
  );

  test('oy ve rapor yerel soruda sunucu uuid5 kimliğiyle gider', () async {
    final rpc = _Rpc([const []]);
    final repo = _Repo(rpc);
    final question = _bank.first;
    final serverId = serverQuestionId(question.id);

    await repo.rateQuestion(question, 1);
    expect(rpc.calls.single.name, 'rate_question');
    expect(rpc.calls.single.params['p_question_id'], serverId);

    rpc.calls.clear();
    await repo.reportQuestion(question, 'Yanlış cevap');
    final insert = rpc.calls.firstWhere((c) => c.name == 'question_reports');
    expect(insert.params['question_id'], serverId);
    expect(insert.params['reason'], startsWith('[r12_sinema_001] '));
    final counter = rpc.calls.lastWhere((c) => c.name == 'report_question');
    expect(counter.params['p_question_id'], serverId);

    // Sunucudan gelen (uuid) soruda kimlik aynen, gerekçeye etiket eklenmez.
    rpc.calls.clear();
    await repo.reportQuestion(_local(_serverOnly), 'Eski bilgi');
    final serverInsert = rpc.calls.firstWhere(
      (c) => c.name == 'question_reports',
    );
    expect(serverInsert.params['question_id'], _serverOnly);
    expect(serverInsert.params['reason'], 'Eski bilgi');
  });
}
