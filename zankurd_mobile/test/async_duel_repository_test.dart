/// Sırayla düello (async 1v1) veri katmanı.
///
/// ## Kusur
///
/// `sirayla_duello_tasarim.md` sözleşmeyi tastamam tanımlıyordu: RPC adları,
/// JSON alanları, kazanan kuralı, XP formülü. Ama istemci tarafında hiçbir
/// karşılığı yoktu — ne `AsyncDuelStart`/`AsyncDuelAnswer` gibi modeller, ne
/// `ZanKurdRepository` üzerinde bir yöntem, ne Supabase ne de mock
/// uygulaması. Bu hâliyle "Sırayla düello" ekranını yazmaya başlayan biri
/// ya sözleşmeyi ad-hoc yeniden yazacak ya da tamamen atlayacaktı; ikisi de
/// tasarım belgesiyle kodun sessizce ayrışmasına açık kapıydı.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbir kod yolu bu RPC'leri çağırmadığı için `dart analyze` ve mevcut
/// testlerin hiçbiri eksikliği gösteremezdi: eksik olan bir ÇALIŞMA ZAMANI
/// hatası değil, tasarım belgesiyle kod arasında henüz atılmamış bir
/// köprüydü. Bu dosya köprüyü sözleşmenin dört köşesinden sınar: JSON
/// ayrıştırma (model), bellek içi oyun mantığı (mock — creator/opponent
/// akışı, ilk cevap kilidi), çevrimdışı kilit (offline depo) ve gerçek RPC
/// çağrısı (Supabase — ad ve parametreler).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// RPC adına göre canlı sözleşmeyi taklit eden sahte HTTP client.
///
/// `test/supabase_offline_fallback_test.dart`teki `_RoomSessionHttpClient`
/// deseniyle aynı: isteğin yolunu ve (varsa) gövdesini kaydeder, `responses`
/// haritasındaki RPC adına karşılık gelen JSON'u döner. Haritada olmayan bir
/// RPC çağrılırsa test sessizce yanlış bir şey doğrulamak yerine fırlar.
class _AsyncDuelHttpClient extends http.BaseClient {
  _AsyncDuelHttpClient(this.responses);

  final Map<String, Object?> responses;
  final requestedPaths = <String>[];
  final requestBodies = <Map<String, dynamic>>[];

  static const _rpcPrefix = '/rest/v1/rpc/';

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) {
        requestBodies.add(Map<String, dynamic>.from(decoded));
      }
    }

    final rpcName = request.url.path.startsWith(_rpcPrefix)
        ? request.url.path.substring(_rpcPrefix.length)
        : '';
    if (!responses.containsKey(rpcName)) {
      throw StateError('Beklenmeyen istek: ${request.url.path}');
    }
    final bytes = utf8.encode(jsonEncode(responses[rpcName]));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// Her RPC'ye PostgREST hata gövdesiyle (400) cevap veren sahte client.
class _FailingRpcHttpClient extends http.BaseClient {
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    final bytes = utf8.encode(
      jsonEncode({
        'message': 'boom',
        'code': 'P0001',
        'details': null,
        'hint': null,
      }),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      400,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// `signInAnonymously`/`ensureProfile` gerçek bir ağ çağrısına gitmesin diye
/// kapatılmış test deposu — `_SignedInRoomSessionRepository` ile aynı desen
/// (bkz. `test/supabase_repository_test.dart`).
class _SignedInAsyncDuelRepository extends SupabaseZanKurdRepository {
  _SignedInAsyncDuelRepository(super.client);

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'test-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-09-01T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

const _startAsyncDuelJson = {
  'duel_id': 'duel-creator-1',
  'role': 'creator',
  'opponent_name': null,
  'expires_at': '2026-09-05T12:00:00.000Z',
  'questions': [
    {
      'index': 0,
      'id': 'q-1',
      'category_name': 'Ziman',
      'prompt': 'Peyva "silav" bi Tirkî çi ye?',
      'option_a': 'Merhaba',
      'option_b': 'Güle güle',
      'option_c': 'Teşekkürler',
      'option_d': 'Lütfen',
      'question_type': 'multipleChoice',
      'image_url': null,
      'difficulty': 1,
    },
  ],
};

const _startAsyncDuelOpponentJson = {
  'duel_id': 'duel-opponent-1',
  'role': 'opponent',
  'opponent_name': 'Berfin',
  'expires_at': '2026-09-05T12:00:00.000Z',
  'questions': [
    {
      'index': 0,
      'id': 'q-2',
      'category_name': 'Dîrok',
      'prompt': 'Ev gotin rast e?',
      'option_a': 'Rast',
      'option_b': 'Şaş',
      'option_c': null,
      'option_d': null,
      'question_type': 'trueFalse',
      'image_url': null,
      'difficulty': 2,
    },
  ],
};

void main() {
  group('AsyncDuelStart.fromJson', () {
    test('creator: doğru cevap gizli, tek şık listesi sözleşmeyle birebir', () {
      final start = AsyncDuelStart.fromJson(_startAsyncDuelJson);

      expect(start.duelId, 'duel-creator-1');
      expect(start.role, AsyncDuelRole.creator);
      expect(start.opponentName, isNull);
      expect(start.expiresAt, DateTime.parse('2026-09-05T12:00:00.000Z'));
      expect(start.questions, hasLength(1));

      final question = start.questions.single;
      expect(question.id, 'q-1');
      expect(question.category, 'Ziman');
      expect(question.hasHiddenAnswer, isTrue);
      expect(question.correctAnswer, isEmpty);
      expect(question.answers, [
        'Merhaba',
        'Güle güle',
        'Teşekkürler',
        'Lütfen',
      ]);
      expect(question.type, QuestionType.multipleChoice);
    });

    test(
      'opponent: opponent_name dolu, null option_c/d iki şıklı soru üretir',
      () {
        final start = AsyncDuelStart.fromJson(_startAsyncDuelOpponentJson);

        expect(start.role, AsyncDuelRole.opponent);
        expect(start.opponentName, 'Berfin');
        final question = start.questions.single;
        expect(question.type, QuestionType.trueFalse);
        expect(question.answers, ['Rast', 'Şaş']);
        expect(question.hasHiddenAnswer, isTrue);
      },
    );
  });

  group('AsyncDuelAnswer.fromJson', () {
    test('bitmemiş cevap: result null kalır', () {
      final answer = AsyncDuelAnswer.fromJson(const {
        'correct': true,
        'correct_option': 'A',
        'answered': 3,
        'total': 7,
        'finished': false,
        'result': null,
      });

      expect(answer.correct, isTrue);
      expect(answer.correctOption, 'A');
      expect(answer.answered, 3);
      expect(answer.total, 7);
      expect(answer.finished, isFalse);
      expect(answer.result, isNull);
    });

    test('biten düello ama rakip bitirmedi: result.waiting true', () {
      final answer = AsyncDuelAnswer.fromJson(const {
        'correct': true,
        'correct_option': 'A',
        'answered': 7,
        'total': 7,
        'finished': true,
        'result': {
          'status': 'waiting',
          'my_correct': 5,
          'my_ms': 41000,
          'opponent_correct': null,
          'opponent_ms': null,
          'outcome': null,
        },
      });

      expect(answer.finished, isTrue);
      final result = answer.result!;
      expect(result.waiting, isTrue);
      expect(result.myCorrect, 5);
      expect(result.myMs, 41000);
      expect(result.opponentCorrect, isNull);
      expect(result.opponentMs, isNull);
      expect(result.outcome, isNull);
    });

    test('iki taraf da bitirdi: result.waiting false, outcome dolu', () {
      final answer = AsyncDuelAnswer.fromJson(const {
        'correct': false,
        'correct_option': 'B',
        'answered': 7,
        'total': 7,
        'finished': true,
        'result': {
          'status': 'completed',
          'my_correct': 5,
          'my_ms': 41000,
          'opponent_correct': 4,
          'opponent_ms': 52000,
          'outcome': 'win',
        },
      });

      final result = answer.result!;
      expect(result.waiting, isFalse);
      expect(result.opponentCorrect, 4);
      expect(result.opponentMs, 52000);
      expect(result.outcome, AsyncDuelOutcome.win);
    });
  });

  group('AsyncDuelSummary.fromJson', () {
    test('tamamlanmış satır sözleşmedeki tüm alanları taşır', () {
      final summary = AsyncDuelSummary.fromJson(const {
        'duel_id': 'd-3',
        'status': 'completed',
        'role': 'creator',
        'opponent_name': 'Berfin',
        'category_name': 'Ziman',
        'my_correct': 5,
        'opponent_correct': 4,
        'outcome': 'win',
        'created_at': '2026-09-01T10:00:00.000Z',
        'completed_at': '2026-09-02T09:00:00.000Z',
        'seen': true,
      });

      expect(summary.duelId, 'd-3');
      expect(summary.status, AsyncDuelStatus.completed);
      expect(summary.role, AsyncDuelRole.creator);
      expect(summary.opponentName, 'Berfin');
      expect(summary.categoryName, 'Ziman');
      expect(summary.myCorrect, 5);
      expect(summary.opponentCorrect, 4);
      expect(summary.outcome, AsyncDuelOutcome.win);
      expect(summary.completedAt, DateTime.parse('2026-09-02T09:00:00.000Z'));
      expect(summary.seen, isTrue);
    });

    test('açık düello: opsiyonel alanlar null kalır', () {
      final summary = AsyncDuelSummary.fromJson(const {
        'duel_id': 'd-4',
        'status': 'open',
        'role': 'creator',
        'opponent_name': null,
        'category_name': null,
        'my_correct': null,
        'opponent_correct': null,
        'outcome': null,
        'created_at': '2026-09-01T10:00:00.000Z',
        'completed_at': null,
        'seen': false,
      });

      expect(summary.status, AsyncDuelStatus.open);
      expect(summary.opponentName, isNull);
      expect(summary.myCorrect, isNull);
      expect(summary.opponentCorrect, isNull);
      expect(summary.outcome, isNull);
      expect(summary.completedAt, isNull);
      expect(summary.seen, isFalse);
    });
  });

  group('MockZanKurdRepository — sırayla düello', () {
    test('creator akışı: 7 soru, her cevapta correct/correctOption, sonda '
        'result.waiting true', () async {
      final repo = MockZanKurdRepository();
      final start = await repo.startAsyncDuel();

      expect(start.role, AsyncDuelRole.creator);
      expect(start.opponentName, isNull);
      expect(start.questions, hasLength(7));
      expect(
        start.questions.every((q) => q.hasHiddenAnswer),
        isTrue,
        reason: 'creator da olsa doğru cevap ekrana gizli gelmeli',
      );

      var expectedCorrect = 0;
      const responseMs = 5000;
      AsyncDuelAnswer? last;
      for (var i = 0; i < start.questions.length; i++) {
        final answer = await repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: responseMs,
        );
        expect(answer.answered, i + 1);
        expect(answer.total, 7);
        expect(const ['A', 'B', 'C', 'D'], contains(answer.correctOption));
        if (answer.correct) expectedCorrect++;
        if (i < 6) {
          expect(answer.finished, isFalse);
          expect(answer.result, isNull);
        }
        last = answer;
      }

      expect(last!.finished, isTrue);
      final result = last.result!;
      // Rakip henüz yok: bekleniyor durumu, ama KENDİ toplamım (7
      // cevabın birikmiş hâli) doğru raporlanmalı.
      expect(result.waiting, isTrue);
      expect(result.myCorrect, expectedCorrect);
      expect(result.myMs, responseMs * 7);
      expect(result.opponentCorrect, isNull);
      expect(result.opponentMs, isNull);
      expect(result.outcome, isNull);
    });

    test(
      'opponent akışı: bekleyen açık düello varken anında karşılaştırma',
      () async {
        final repo = MockZanKurdRepository();
        repo.addPendingAsyncDuelForTesting(
          opponentName: 'Rojda',
          opponentCorrect: 4,
          opponentMs: 52000,
        );

        final start = await repo.startAsyncDuel();
        expect(start.role, AsyncDuelRole.opponent);
        expect(start.opponentName, 'Rojda');
        expect(start.questions, hasLength(7));

        AsyncDuelAnswer? last;
        for (var i = 0; i < start.questions.length; i++) {
          last = await repo.answerAsyncDuel(
            duelId: start.duelId,
            questionIndex: i,
            choice: 'A',
            responseMs: 1000,
          );
        }

        expect(last!.finished, isTrue);
        final result = last.result!;
        // Rakip (test tarafından önceden "bitirilmiş") zaten hazır olduğu
        // için son soruda beklemek yok — sonuç DOĞRUDAN kesinleşir.
        expect(result.waiting, isFalse);
        expect(result.opponentCorrect, 4);
        expect(result.opponentMs, 52000);
        expect(result.outcome, isNotNull);

        // "Düellolarım" özeti de aynı tamamlanmış sonucu taşımalı.
        final summaries = await repo.loadMyAsyncDuels();
        final summary = summaries.singleWhere((s) => s.duelId == start.duelId);
        expect(summary.status, AsyncDuelStatus.completed);
        expect(summary.opponentCorrect, 4);
        expect(summary.outcome, result.outcome);
      },
    );

    test('ilk cevap kilidi: aynı soru ikinci kez cevaplanamaz', () async {
      final repo = MockZanKurdRepository();
      final start = await repo.startAsyncDuel();

      await repo.answerAsyncDuel(
        duelId: start.duelId,
        questionIndex: 0,
        choice: 'A',
        responseMs: 1000,
      );

      await expectLater(
        repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: 0,
          choice: 'B',
          responseMs: 1000,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'TIMEOUT geçerli ama yanlış cevaptır: soru kilitlenir, süre eklenir',
      () async {
        final repo = MockZanKurdRepository();
        repo.addPendingAsyncDuelForTesting(opponentCorrect: 0, opponentMs: 1);
        final start = await repo.startAsyncDuel();

        AsyncDuelAnswer? last;
        for (var i = 0; i < start.questions.length; i++) {
          last = await repo.answerAsyncDuel(
            duelId: start.duelId,
            questionIndex: i,
            choice: 'TIMEOUT',
            responseMs: 20000,
          );
          expect(last.correct, isFalse);
          expect(['A', 'B', 'C', 'D'], contains(last.correctOption));
        }

        expect(last!.finished, isTrue);
        expect(last.result!.myCorrect, 0);
        expect(last.result!.myMs, 20000 * start.questions.length);
        // Doğru sayısı eşit (0-0); rakibin toplam süresi kısa → kayıp.
        expect(last.result!.outcome, AsyncDuelOutcome.loss);
        await expectLater(
          repo.answerAsyncDuel(
            duelId: start.duelId,
            questionIndex: 0,
            choice: 'A',
            responseMs: 10,
          ),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'claimAsyncDuelXp bitmemiş düelloda "Duel not finished" fırlatır',
      () async {
        final repo = MockZanKurdRepository();
        final start = await repo.startAsyncDuel();
        await repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: 0,
          choice: 'A',
          responseMs: 1000,
        );

        await expectLater(
          repo.claimAsyncDuelXp(start.duelId),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'claimAsyncDuelXp tamamlanmış düellodan sonra idempotenttir',
      () async {
        final repo = MockZanKurdRepository();
        repo.addPendingAsyncDuelForTesting(opponentCorrect: 0, opponentMs: 1);

        final start = await repo.startAsyncDuel();
        for (var i = 0; i < start.questions.length; i++) {
          await repo.answerAsyncDuel(
            duelId: start.duelId,
            questionIndex: i,
            choice: 'A',
            responseMs: 1000,
          );
        }

        final firstClaim = await repo.claimAsyncDuelXp(start.duelId);
        final secondClaim = await repo.claimAsyncDuelXp(start.duelId);
        expect(secondClaim, firstClaim);
      },
    );
  });

  group('OfflineZanKurdRepository — sırayla düello', () {
    test('bütün async düello yöntemleri StateError fırlatır', () async {
      final repo = OfflineZanKurdRepository();

      await expectLater(repo.startAsyncDuel(), throwsA(isA<StateError>()));
      await expectLater(
        repo.answerAsyncDuel(
          duelId: 'x',
          questionIndex: 0,
          choice: 'A',
          responseMs: 1000,
        ),
        throwsA(isA<StateError>()),
      );
      await expectLater(repo.loadMyAsyncDuels(), throwsA(isA<StateError>()));
      await expectLater(
        repo.markAsyncDuelSeen('x'),
        throwsA(isA<StateError>()),
      );
      await expectLater(repo.claimAsyncDuelXp('x'), throwsA(isA<StateError>()));
    });
  });

  group('SupabaseZanKurdRepository — sırayla düello RPC çağrıları', () {
    test(
      'startAsyncDuel doğru RPC adını ve p_category parametresini gönderir',
      () async {
        final httpClient = _AsyncDuelHttpClient({
          'start_async_duel': _startAsyncDuelJson,
        });
        final repo = _SignedInAsyncDuelRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: httpClient,
          ),
        );

        final start = await repo.startAsyncDuel(category: 'Ziman');

        expect(httpClient.requestedPaths, ['/rest/v1/rpc/start_async_duel']);
        expect(httpClient.requestBodies.single, {'p_category': 'Ziman'});
        expect(start.duelId, 'duel-creator-1');
        expect(start.questions.single.hasHiddenAnswer, isTrue);
      },
    );

    test('answerAsyncDuel doğru RPC adını ve parametreleri gönderir', () async {
      final httpClient = _AsyncDuelHttpClient({
        'answer_async_duel': const {
          'correct': true,
          'correct_option': 'C',
          'answered': 3,
          'total': 7,
          'finished': false,
          'result': null,
        },
      });
      final repo = _SignedInAsyncDuelRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final answer = await repo.answerAsyncDuel(
        duelId: 'd-9',
        questionIndex: 2,
        choice: 'C',
        responseMs: 4300,
      );

      expect(httpClient.requestedPaths, ['/rest/v1/rpc/answer_async_duel']);
      expect(httpClient.requestBodies.single, {
        'p_duel_id': 'd-9',
        'p_question_index': 2,
        'p_choice': 'C',
        'p_response_ms': 4300,
      });
      expect(answer.correct, isTrue);
      expect(answer.correctOption, 'C');
    });

    test(
      'loadMyAsyncDuels doğru RPC adını çağırır ve satırları ayrıştırır',
      () async {
        final httpClient = _AsyncDuelHttpClient({
          'list_my_async_duels': [
            {
              'duel_id': 'd-5',
              'status': 'matched',
              'role': 'opponent',
              'opponent_name': 'Azad',
              'category_name': 'Ziman',
              'my_correct': null,
              'opponent_correct': null,
              'outcome': null,
              'created_at': '2026-09-01T10:00:00.000Z',
              'completed_at': null,
              'seen': false,
            },
          ],
        });
        final repo = _SignedInAsyncDuelRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: httpClient,
          ),
        );

        final summaries = await repo.loadMyAsyncDuels();

        expect(httpClient.requestedPaths, ['/rest/v1/rpc/list_my_async_duels']);
        expect(summaries, hasLength(1));
        expect(summaries.single.duelId, 'd-5');
        expect(summaries.single.status, AsyncDuelStatus.matched);
      },
    );

    test(
      'loadMyAsyncDuels sunucu hatasında boş liste uydurmaz, fırlatır',
      () async {
        final httpClient = _FailingRpcHttpClient();
        final repo = _SignedInAsyncDuelRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: httpClient,
          ),
        );

        await expectLater(
          repo.loadMyAsyncDuels(),
          throwsA(isA<PostgrestException>()),
        );
        expect(httpClient.requestedPaths, ['/rest/v1/rpc/list_my_async_duels']);
      },
    );

    test(
      'markAsyncDuelSeen doğru RPC adını ve p_duel_id parametresini gönderir',
      () async {
        final httpClient = _AsyncDuelHttpClient({'mark_async_duel_seen': null});
        final repo = _SignedInAsyncDuelRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: httpClient,
          ),
        );

        await repo.markAsyncDuelSeen('d-7');

        expect(httpClient.requestedPaths, [
          '/rest/v1/rpc/mark_async_duel_seen',
        ]);
        expect(httpClient.requestBodies.single, {'p_duel_id': 'd-7'});
      },
    );

    test(
      'claimAsyncDuelXp doğru RPC adını gönderir ve tam sayı sonucu okur',
      () async {
        final httpClient = _AsyncDuelHttpClient({'claim_async_duel_xp': 130});
        final repo = _SignedInAsyncDuelRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: httpClient,
          ),
        );

        final total = await repo.claimAsyncDuelXp('d-8');

        expect(httpClient.requestedPaths, ['/rest/v1/rpc/claim_async_duel_xp']);
        expect(httpClient.requestBodies.single, {'p_duel_id': 'd-8'});
        expect(total, 130);
      },
    );
  });
}
