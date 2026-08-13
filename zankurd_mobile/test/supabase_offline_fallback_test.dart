import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';

/// Her isteği anında ağ hatasıyla reddeden sahte HTTP client. Gerçek bir
/// soket açmaz — bu yüzden gerçek-ağ testlerinin aksine (bkz. ilk deneme:
/// 127.0.0.1:1'e bağlanmak GoTrue'nun retry/backoff'u yüzünden 45sn'den
/// uzun sürdü) deterministik ve anında başarısız olur.
class _AlwaysFailingHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw Exception('injected: ağ erişilemez');
  }
}

class _QuizRewardHttpClient extends http.BaseClient {
  _QuizRewardHttpClient(this.response);

  final Object response;
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request.url.path != '/rest/v1/rpc/claim_quiz_reward') {
      throw StateError('Beklenmeyen istek: ${request.url.path}');
    }
    final bytes = utf8.encode(jsonEncode(response));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _SignedInSupabaseRepository extends SupabaseZanKurdRepository {
  _SignedInSupabaseRepository(super.client);

  @override
  String? get currentUserId => 'test-user';
}

class _SignedInQuizRewardRepository extends SupabaseZanKurdRepository {
  _SignedInQuizRewardRepository(super.client);

  String activeUserId = 'test-user';

  @override
  String? get currentUserId => activeUserId;

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'test-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-08-02T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

class _IdentityChangingQuizRewardRepository
    extends _SignedInQuizRewardRepository {
  _IdentityChangingQuizRewardRepository(super.client);

  @override
  Future<void> ensureProfile() async {
    activeUserId = 'other-user';
  }
}

class _RoomQuestionsHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.path.endsWith('/rpc/get_room_questions')) {
      throw StateError('Beklenmeyen istek: ${request.url.path}');
    }
    final bytes = utf8.encode(
      jsonEncode([
        {
          'id': 'server-question-1',
          'category_name': 'Ziman',
          'prompt': 'Pirtûk çi ye?',
          'option_a': 'Kitap',
          'option_b': 'Masa',
          'option_c': 'Su',
          'option_d': 'Ev',
          'question_type': 'multiple_choice',
          'image_url': null,
          'difficulty': 2,
        },
      ]),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _EmptyRoomQuestionsHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.path.endsWith('/rpc/get_room_questions')) {
      throw StateError('Beklenmeyen istek: ${request.url.path}');
    }
    final bytes = utf8.encode('[]');
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// 2026-07-21 denetiminde bulunan test boşluğu: repository'nin Supabase
/// erişilemez olduğunda gerçekten güvenli davrandığını (ne çökme ne de
/// sahte skor/coin/oda üretimi) hiçbir test doğrulamıyordu.
void main() {
  SupabaseZanKurdRepository unreachableRepo() => SupabaseZanKurdRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_test_key',
      httpClient: _AlwaysFailingHttpClient(),
    ),
  );

  test(
    'loadQuestions ağ hatasında throw etmez, offline bankaya düşer',
    () async {
      final repo = unreachableRepo();
      final questions = await repo.loadQuestions(limit: 5);
      expect(questions, isNotEmpty);
    },
  );

  test('loadCoinBalance ağ hatasında throw etmez, 0 döner', () async {
    final repo = unreachableRepo();
    expect(await repo.loadCoinBalance(), 0);
  });

  test(
    'spendCoins ağ hatasında false döner — coin sahte harcanmış sayılmaz',
    () async {
      final repo = unreachableRepo();
      expect(await repo.spendCoins(20, 'wildcard_fifty_fifty'), isFalse);
    },
  );

  test(
    'soru önerisi canlı insert ağ hatasında false döner — sahte başarı yok',
    () async {
      final repo = _SignedInSupabaseRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _AlwaysFailingHttpClient(),
        ),
      );

      final submitted = await repo.submitSuggestedQuestion(
        category: 'Ziman',
        prompt: 'Pirtûk çi ye?',
        optionA: 'Kitap',
        optionB: 'Masa',
        optionC: 'Av',
        optionD: 'Mal',
        correctOption: 'A',
      );

      expect(submitted, isFalse);
    },
  );

  test('awardQuizCoins ağ hatasını yeniden deneme için yukarı taşır', () async {
    final repo = unreachableRepo();
    await expectLater(
      repo.awardQuizCoins(
        score: 500,
        correctCount: 8,
        bestStreak: 5,
        totalQuestions: 10,
      ),
      throwsA(anything),
    );
  });

  test(
    'awardQuizCoins açık başarı işaretli amount 0 yanıtını normal sayar',
    () async {
      final httpClient = _QuizRewardHttpClient(const {
        'amount': 0,
        'already_claimed': false,
      });
      final repo = _SignedInQuizRewardRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      // Bu testler ODA ödül yolunu (doğrulanan tur) sınıyor. `room`
      // verilmezse çağrı 2026-08-10'dan beri SOLO sayılır ve
      // `claim_solo_reward`a gider — yani sınanan yol değişir.
      final claim = await repo.awardQuizCoins(
        score: 100,
        correctCount: 2,
        bestStreak: 1,
        totalQuestions: 10,
        room: repo.createRoom().copyWith(id: 'room-under-test'),
      );

      expect(claim.amount, 0);
      // Oda yolunda tavan kavramı yok; bayrak yalnız solo talepte anlamlı.
      // Sunucu söylemediği sürece yanlış kalmalı — "bilmiyorum"u "tavana
      // vardın" diye göstermek olmayan bir sebep uydurmaktır.
      expect(claim.dailyCapReached, isFalse);
      expect(httpClient.requestedPaths, ['/rest/v1/rpc/claim_quiz_reward']);
    },
  );

  test(
    'awardQuizCoins guard amount 0 yanıtını başarı saymadan yukarı taşır',
    () async {
      final httpClient = _QuizRewardHttpClient(const {
        'amount': 0,
        'room_not_finished': true,
      });
      final repo = _SignedInQuizRewardRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      await expectLater(
        repo.awardQuizCoins(
          score: 100,
          correctCount: 2,
          bestStreak: 1,
          totalQuestions: 10,
          room: repo.createRoom().copyWith(id: 'room-under-test'),
        ),
        throwsStateError,
      );
      expect(httpClient.requestedPaths, ['/rest/v1/rpc/claim_quiz_reward']);
    },
  );

  test(
    'awardQuizCoins profile awaitinde hesap değişirse reward RPC çağırmaz',
    () async {
      final httpClient = _QuizRewardHttpClient(const {
        'amount': 0,
        'already_claimed': false,
      });
      final repo = _IdentityChangingQuizRewardRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      await expectLater(
        repo.awardQuizCoins(
          score: 100,
          correctCount: 2,
          bestStreak: 1,
          totalQuestions: 10,
        ),
        throwsStateError,
      );
      expect(httpClient.requestedPaths, isEmpty);
    },
  );

  test(
    'createOnlineRoom ağ hatasında throw eder — sessizce sahte oda üretmez',
    () async {
      final repo = unreachableRepo();
      await expectLater(repo.createOnlineRoom(), throwsA(anything));
    },
  );

  test(
    'gerçek oda soru RPC hata veya boş sonuçta açıkça başarısız olur',
    () async {
      final failingRepo = unreachableRepo();
      final emptyRepo = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _EmptyRoomQuestionsHttpClient(),
        ),
      );
      final onlineRoom = failingRepo
          .createRoom(category: 'Ziman')
          .copyWith(id: '00000000-0000-0000-0000-000000000001');

      for (final repo in [failingRepo, emptyRepo]) {
        await expectLater(repo.loadRoomQuestions(onlineRoom), throwsStateError);
      }

      final offlineRoom = failingRepo.createRoom(category: 'Ziman');
      final offlineQuestions = await failingRepo.loadRoomQuestions(offlineRoom);
      expect(offlineQuestions, isNotEmpty);
      expect(
        offlineQuestions.every((question) => question.correctAnswer.isNotEmpty),
        isTrue,
      );
    },
  );

  test('sunucu cevabı gizli oda sorusu offline havuza düşmez', () async {
    final repo = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _RoomQuestionsHttpClient(),
      ),
    );
    final room = repo
        .createRoom(category: 'Ziman')
        .copyWith(id: '00000000-0000-0000-0000-000000000001');

    final questions = await repo.loadRoomQuestions(room);

    expect(questions.map((question) => question.id), ['server-question-1']);
    expect(questions.single.correctAnswer, isEmpty);
  });
}
