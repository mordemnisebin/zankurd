import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';

/// Bir kategori isteği gelirse yerel bankadan bilinçli olarak farklı bir
/// sunucu cevabı üretir. Böylece test, yalnız çağrı sayısını değil oyuncuya
/// gösterilen kategori kaynağını da doğrular.
class _ServerCategoriesHttpClient extends http.BaseClient {
  _ServerCategoriesHttpClient({
    this.serverCategories = const ['Tenê li serverê'],
  });

  final List<String> serverCategories;
  int requestCount = 0;
  Uri? lastRequestUrl;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestCount++;
    lastRequestUrl = request.url;
    final bytes = utf8.encode(
      jsonEncode(serverCategories.map((name) => {'name': name}).toList()),
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

class _BlockedPlayersErrorHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(jsonEncode({'message': 'temporary failure'}));
    return http.StreamedResponse(
      Stream.value(bytes),
      503,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// `list_friends`in gerçek dönüş şekli: `user_id` YOK, `total_score` ve
/// `last_active_at` VAR (2026-08-14_list_friends_score_and_activity.sql).
/// Eski `Friend.fromJson` bu satırlarda çöküyordu; bu istemci canlı
/// sözleşmeyi taklit ederek o regresyonu bir daha mümkün kılmaz.
class _FriendsScoreHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(
      jsonEncode([
        {
          'id': 'f1',
          'friend_id': 'friend-1',
          'friend_name': 'Rojda',
          'friend_avatar_color': '#2AA6A1',
          'created_at': '2026-08-01T00:00:00Z',
          'total_score': 8420,
          'last_active_at': '2026-08-14T09:00:00Z',
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

/// `favorite_questions` + `get_my_favorite_questions` RPC uçlarını taklit
/// eder. Bir favori paketli bankada (`curated_movement_0001`), diğerleri
/// yalnız sunucuda (gerçek `questions.id` uuid'leri, oda maçında kaydedilmiş)
/// çözülür — 2026-08-14 denetimindeki "favoriler ekranı sunucu kaydını asla
/// çözmüyor" kusurunu taklit eder.
class _FavoriteQuestionsHttpClient extends http.BaseClient {
  _FavoriteQuestionsHttpClient({
    this.serverIds = const [serverOnlyId],
    this.rpcStatus = 200,
    this.rpcBody,
    this.rpcThrows,
  });

  static const serverOnlyId = '11111111-1111-4111-8111-111111111111';

  final List<String> serverIds;
  final int rpcStatus;
  final Object? rpcBody;
  final Object? rpcThrows;
  final requestedPaths = <String>[];
  final rpcBodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request.url.path == '/rest/v1/favorite_questions') {
      return _jsonResponse(request, [
        for (final id in serverIds) {'question_id': id},
        {'question_id': 'curated_movement_0001'},
      ]);
    }
    if (request.url.path == '/rest/v1/rpc/get_my_favorite_questions') {
      final body = jsonDecode(
        await (request as http.Request).finalize().bytesToString(),
      );
      rpcBodies.add(Map<String, dynamic>.from(body as Map));
      if (rpcThrows != null) throw rpcThrows!;
      if (rpcStatus != 200) {
        return _jsonResponse(request, rpcBody, statusCode: rpcStatus);
      }
      final asked = (body['p_ids'] as List).cast<String>();
      return _jsonResponse(request, [
        for (final id in asked)
          {
            'id': id,
            'category_name': 'Ziman',
            'prompt': 'Sunucu sorusu $id?',
            'option_a': 'A',
            'option_b': 'B',
            'option_c': 'C',
            'option_d': 'D',
            'question_type': 'multiple_choice',
            'image_url': null,
            'difficulty': 2,
            'language_code': 'ku',
          },
      ]);
    }
    return _jsonResponse(request, [], statusCode: 404);
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _RoomSnapshotHttpClient extends http.BaseClient {
  final requestedPaths = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    final Object body;
    if (request.url.path == '/rest/v1/rooms') {
      body = const {
        'id': '00000000-0000-0000-0000-000000000042',
        'code': 'ZK-R3AL',
        'host_id': 'host-id',
        'question_count': 7,
        'seconds_per_question': 45,
        'status': 'active',
        'categories': {'name': 'Çand'},
      };
    } else if (request.url.path == '/rest/v1/room_players') {
      body = const [
        {
          'player_id': 'host-id',
          'score': 90,
          'streak': 3,
          'is_ready': true,
          'profiles': {
            'display_name': 'Berfin',
            'avatar_icon': 'sun',
            'avatar_color': '#123456',
            'avatar_url': null,
            'avatar_frame': 'gold',
            'showcase_title': 'Dengbêj',
          },
        },
        {
          'player_id': 'guest-id',
          'score': 40,
          'streak': 1,
          'is_ready': true,
          'profiles': {
            'display_name': 'Berfin',
            'avatar_icon': null,
            'avatar_color': null,
            'avatar_url': null,
            'avatar_frame': null,
            'showcase_title': null,
          },
        },
      ];
    } else {
      throw StateError('Beklenmeyen istek: ${request.url}');
    }

    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _RoomSessionHttpClient extends http.BaseClient {
  _RoomSessionHttpClient({
    this.resumeResponse,
    this.resultResponse,
    this.leaveResponse = const {
      'status': 'finished',
      'reason': 'forfeit',
      'forfeited_by': 'host-id',
    },
    this.rpcErrorCode,
    this.joinRoomErrorMessage,
    this.markReadyResponse = const {'status': 'waiting'},
    this.answerProgressResponse = const {
      'question_index': 0,
      'answered': 3,
      'active': 8,
    },
    this.roomSnapshot = _roomRpcSnapshot,
    this.roomPlayersResponse = const [
      {
        'player_id': 'host-id',
        'score': 250,
        'streak': 2,
        'is_ready': true,
        'profiles': {'display_name': 'Berfin'},
      },
      {
        'player_id': 'guest-id',
        'score': 100,
        'streak': 1,
        'is_ready': true,
        'profiles': {'display_name': 'Rojda'},
      },
    ],
  });

  final Object? resumeResponse;
  final Object? resultResponse;
  final Object? leaveResponse;
  final String? rpcErrorCode;

  /// `mark_room_client_ready` cevabı (kalabalıkta düşenler 'left' alır).
  final Object? markReadyResponse;

  /// `get_room_answer_progress` cevabı.
  final Object? answerProgressResponse;

  /// `create_online_room` / `join_room_by_code` cevabı.
  final Object? roomSnapshot;

  /// Set edilirse `join_room_by_code` başarı yerine bu mesajla 400 döner
  /// (bkz. `join_room_by_code`'un `raise exception` metinleri,
  /// `supabase/2026-08-02_multiplayer_session_hardening.sql`).
  final String? joinRoomErrorMessage;
  final Object roomPlayersResponse;
  final requestedPaths = <String>[];
  final requestBodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request is http.Request && request.body.isNotEmpty) {
      final decoded = jsonDecode(request.body);
      if (decoded is Map) {
        requestBodies.add(Map<String, dynamic>.from(decoded));
      }
    }

    if (rpcErrorCode != null && request.url.path.startsWith('/rest/v1/rpc/')) {
      return _jsonResponse(request, {
        'code': rpcErrorCode,
        'message': 'RPC schema cache mismatch',
        'details': null,
        'hint': null,
      }, statusCode: 404);
    }

    switch (request.url.path) {
      case '/rest/v1/rpc/create_online_room':
        return _jsonResponse(request, roomSnapshot);
      case '/rest/v1/rpc/join_room_by_code':
        final message = joinRoomErrorMessage;
        if (message != null) {
          return _jsonResponse(request, {
            'code': null,
            'message': message,
            'details': null,
            'hint': null,
          }, statusCode: 400);
        }
        return _jsonResponse(request, roomSnapshot);
      case '/rest/v1/rpc/get_my_resumable_room':
        return _jsonResponse(request, resumeResponse);
      case '/rest/v1/rpc/get_my_pending_room_result':
        return _jsonResponse(request, resultResponse);
      case '/rest/v1/rpc/get_my_room_result':
        return _jsonResponse(request, resultResponse);
      case '/rest/v1/rpc/acknowledge_room_result':
        return _jsonResponse(request, const {'acknowledged': true});
      case '/rest/v1/rpc/mark_room_client_ready':
        return _jsonResponse(request, markReadyResponse);
      case '/rest/v1/rpc/get_room_answer_progress':
        return _jsonResponse(request, answerProgressResponse);
      case '/rest/v1/rpc/advance_room_question':
        return _jsonResponse(request, 1);
      case '/rest/v1/rpc/set_room_ready':
        return _jsonResponse(request, null);
      case '/rest/v1/rpc/leave_room':
        return _jsonResponse(request, leaveResponse);
      case '/rest/v1/rpc/touch_matchmaking':
        return _jsonResponse(request, const {
          'status': 'matched',
          'room_id': '00000000-0000-0000-0000-000000000099',
          'opponent_name': 'Rojda',
        });
      case '/rest/v1/rpc/cancel_matchmaking':
        return _jsonResponse(request, const {
          'status': 'matched',
          'room_id': '00000000-0000-0000-0000-000000000099',
        });
      case '/rest/v1/rooms':
        final isEndState = request.url.queryParameters['select']?.contains(
          'ended_reason',
        );
        if (isEndState ?? false) {
          return _jsonResponse(request, const {
            'status': 'finished',
            'ended_reason': 'forfeit',
            'forfeited_by': 'guest-id',
          });
        }
        return _jsonResponse(request, const {
          'id': '00000000-0000-0000-0000-000000000099',
          'code': 'ZK-ABCDEF0123',
          'host_id': 'host-id',
          'question_count': 10,
          'seconds_per_question': 20,
          'status': 'active',
          'categories': {'name': 'Ziman'},
        });
      case '/rest/v1/room_players':
        return _jsonResponse(request, roomPlayersResponse);
      default:
        throw StateError('Beklenmeyen istek: ${request.url}');
    }
  }

  http.StreamedResponse _jsonResponse(
    http.BaseRequest request,
    Object? body, {
    int statusCode = 200,
  }) {
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      statusCode,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

const _roomRpcSnapshot = {
  'room_id': '00000000-0000-0000-0000-000000000099',
  'code': 'ZK-ABCDEF0123',
  'host_id': 'host-id',
  'category_name': 'Ziman',
  'question_count': 10,
  'seconds_per_question': 20,
  'status': 'lobby',
};

const _completedRoomResult = {
  'room': {
    'id': '00000000-0000-0000-0000-000000000099',
    'code': 'ZK-ABCDEF0123',
    'host_id': 'host-id',
    'category_name': 'Ziman',
    'question_count': 2,
    'seconds_per_question': 20,
    'status': 'finished',
    'current_question_index': 2,
  },
  'own_player_id': 'host-id',
  'players': [
    {
      'player_id': 'host-id',
      'display_name': 'Berfin',
      'final_score': 250,
      'final_streak': 1,
    },
    {
      'player_id': 'guest-id',
      'display_name': 'Rojda',
      'final_score': 100,
      'final_streak': 0,
    },
  ],
  'question_ids': ['question-1', 'question-2'],
  'answers': [
    {
      'question_id': 'question-1',
      'question_index': 0,
      'selected_option': 'A',
      'correct_option': 'B',
      'is_correct': false,
      'points_awarded': 0,
      'response_ms': 4100,
      'explanation': 'Açıklama',
      'explanation_ku': 'Ravekirin',
      'explanation_tr': 'Açıklama',
    },
    {
      'question_id': 'question-2',
      'question_index': 1,
      'selected_option': 'C',
      'correct_option': 'C',
      'is_correct': true,
      'points_awarded': 250,
      'response_ms': 1200,
      'explanation': null,
      'explanation_ku': null,
      'explanation_tr': null,
    },
  ],
  'winner_id': 'host-id',
  'ended_reason': 'completed',
  'forfeited_by': null,
  'finished_at': '2026-08-02T12:01:00.000Z',
};

/// Kalabalık odanın sunucu cevabı: `rank` (eşitlikte ortak), `left` ve oda
/// düzeyinde `is_custom`/`max_players`. Eski istemcinin bilmediği alanlar.
Map<String, dynamic> _crowdRoomResult({
  int currentQuestionIndex = 2,
  List<Map<String, dynamic>>? answers,
}) => {
  ..._completedRoomResult,
  'room': {
    ...(_completedRoomResult['room'] as Map<String, dynamic>),
    'current_question_index': currentQuestionIndex,
    'is_custom': true,
    'max_players': 8,
  },
  'players': [
    {
      'player_id': 'host-id',
      'display_name': 'Berfin',
      'final_score': 250,
      'final_streak': 1,
      'rank': 1,
      'left': false,
    },
    {
      'player_id': 'guest-id',
      'display_name': 'Rojda',
      'final_score': 250,
      'final_streak': 0,
      'rank': 1,
      'left': false,
    },
    {
      'player_id': 'third-id',
      'display_name': 'Azad',
      'final_score': 100,
      'final_streak': 0,
      'rank': 3,
      'left': false,
    },
    {
      'player_id': 'gone-id',
      'display_name': 'Şêro',
      'final_score': 400,
      'final_streak': 0,
      'rank': null,
      'left': true,
    },
  ],
  // İlk iki soru: tepede eşitlik → kazanan yok.
  'winner_id': null,
  'answers': ?answers,
};

class _SignedInRoomSessionRepository extends SupabaseZanKurdRepository {
  _SignedInRoomSessionRepository(super.client);

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'host-id',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-08-02T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

void main() {
  group('kalabalık oda (2–50 kişi)', () {
    SupabaseZanKurdRepository repoFor(_RoomSessionHttpClient http) =>
        SupabaseZanKurdRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: http,
          ),
        );

    test('kapasite seçimi sunucuya p_max_players olarak gider', () async {
      final httpClient = _RoomSessionHttpClient(
        roomSnapshot: const {
          ..._roomRpcSnapshot,
          'max_players': 16,
          'is_custom': true,
        },
      );
      final repository = _SignedInRoomSessionRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final room = await repository.createOnlineRoom(maxPlayers: 16);

      expect(httpClient.requestBodies.first['p_max_players'], 16);
      expect(room.maxPlayers, 16);
      expect(room.isCustom, isTrue);
      expect(room.isCrowd, isTrue);
    });

    test('kapasite 2 iken istek eskisiyle birebir aynıdır', () async {
      final httpClient = _RoomSessionHttpClient();
      final repository = _SignedInRoomSessionRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final room = await repository.createOnlineRoom();

      expect(
        httpClient.requestBodies.first.containsKey('p_max_players'),
        isFalse,
      );
      // Eski sunucu max_players/is_custom döndürmez; create 2 kişilik özel
      // oda sayılır ama kalabalık değildir.
      expect(room.maxPlayers, 2);
      expect(room.isCrowd, isFalse);
      expect(room.name, '1vs1');
    });

    test('kodla katılma kapasiteyi ve kalabalık ayrımını taşır', () async {
      final httpClient = _RoomSessionHttpClient(
        roomSnapshot: const {
          ..._roomRpcSnapshot,
          'max_players': 30,
          'is_custom': true,
        },
      );
      final repository = _SignedInRoomSessionRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final room = await repository.joinOnlineRoom('ZK-ABCDEF0123');

      expect(room.maxPlayers, 30);
      expect(room.isCrowd, isTrue);
    });

    test('sonuç: eşit skor aynı sırayı paylaşır, ayrılan en sonda', () async {
      final repository = repoFor(
        _RoomSessionHttpClient(resultResponse: _crowdRoomResult()),
      );

      final result = await repository.loadMyPendingRoomResult();

      expect(result, isNotNull);
      expect(result!.room.isCrowd, isTrue);
      expect(result.room.maxPlayers, 8);
      expect(result.room.players.map((p) => p.rank), [1, 1, 3, null]);
      expect(result.room.players.map((p) => p.left), [
        false,
        false,
        false,
        true,
      ]);
      // Ayrılanın 400 puanı kazananı etkilemez; tepede eşitlik var.
      expect(result.winnerId, isNull);
    });

    test('sonuç: erken biten odada eksik cevap kabul edilir', () async {
      final full = (_completedRoomResult['answers'] as List)
          .cast<Map<String, dynamic>>();
      // Tek cevaplı oyuncu: skoru bu cevapların toplamı olmalı → 0.
      final repository = repoFor(
        _RoomSessionHttpClient(
          resultResponse: {
            ..._crowdRoomResult(currentQuestionIndex: 1, answers: [full.first]),
            'players': [
              {
                'player_id': 'host-id',
                'display_name': 'Berfin',
                'final_score': 0,
                'final_streak': 0,
                'rank': 1,
                'left': false,
              },
              {
                'player_id': 'gone-id',
                'display_name': 'Şêro',
                'final_score': 0,
                'final_streak': 0,
                'rank': null,
                'left': true,
              },
            ],
            'winner_id': 'host-id',
          },
        ),
      );

      final result = await repository.loadMyPendingRoomResult();

      expect(result!.answers, hasLength(1));
      expect(result.winnerId, 'host-id');
    });

    test('sonuç: odadan ayrılan çağıran (sıra yok, cevap yok) ayrıştırılır, '
        'sunucu answers yerine boş liste verir', () async {
      // 2026-10-16: ayrılan oyuncu da biten odanın sonucunu okuyabilir
      // (get_room_result_payload `left_at is null` şartını bıraktı). Çağıran
      // `left: true`, sırasız ve hiç cevapsız gelir; ekran bunu "Ayrıldı"
      // satırı ve son sıralamayla gösterir.
      final repository = repoFor(
        _RoomSessionHttpClient(
          resultResponse: {
            ..._crowdRoomResult(answers: const []),
            'players': [
              {
                'player_id': 'host-id',
                'display_name': 'Berfin',
                'final_score': 0,
                'final_streak': 0,
                'rank': null,
                'left': true,
              },
              {
                'player_id': 'guest-id',
                'display_name': 'Rojda',
                'final_score': 250,
                'final_streak': 1,
                'rank': 1,
                'left': false,
              },
              {
                'player_id': 'third-id',
                'display_name': 'Azad',
                'final_score': 100,
                'final_streak': 0,
                'rank': 2,
                'left': false,
              },
            ],
            'winner_id': 'guest-id',
          },
        ),
      );

      final result = await repository.loadMyPendingRoomResult();

      expect(result, isNotNull);
      final me = result!.room.players.singleWhere((p) => p.id == 'host-id');
      expect(me.left, isTrue);
      expect(me.rank, isNull);
      expect(result.answers, isEmpty);
      expect(result.winnerId, 'guest-id');
    });

    test('1v1 sonucu eksik cevabı hâlâ reddeder', () async {
      final answers = (_completedRoomResult['answers'] as List)
          .take(1)
          .toList();
      final repository = repoFor(
        _RoomSessionHttpClient(
          resultResponse: {..._completedRoomResult, 'answers': answers},
        ),
      );

      await expectLater(
        repository.loadMyPendingRoomResult(),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'kalabalık sonucunda sıra ile ayrılma tutarsızsa reddedilir',
      () async {
        final broken = _crowdRoomResult();
        (broken['players'] as List<Map<String, dynamic>>)[3]['rank'] = 4;
        final repository = repoFor(
          _RoomSessionHttpClient(resultResponse: broken),
        );

        await expectLater(
          repository.loadMyPendingRoomResult(),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('lobide host devri: leave_room yeni host kimliğini taşır', () async {
      final repository = repoFor(
        _RoomSessionHttpClient(
          leaveResponse: const {
            'status': 'left',
            'reason': 'host_transferred',
            'forfeited_by': null,
            'new_host_id': 'guest-id',
          },
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: 'crowd',
        code: 'ZK-ABCDEF0123',
        category: 'Ziman',
        players: [],
        status: RoomStatus.lobby,
        maxPlayers: 8,
        isCustom: true,
      );

      final outcome = await repository.leaveOnlineRoom(room);

      expect(outcome.hostTransferred, isTrue);
      expect(outcome.newHostId, 'guest-id');
      expect(outcome.completed, isFalse);
    });

    const crowdRoom = GameRoom(
      id: '00000000-0000-0000-0000-000000000099',
      name: 'crowd',
      code: 'ZK-ABCDEF0123',
      category: 'Ziman',
      players: [],
      status: RoomStatus.active,
      maxPlayers: 8,
      isCustom: true,
    );

    test(
      'cevap ilerlemesi yalnız oda kimliğiyle sorulur ve parse edilir',
      () async {
        final httpClient = _RoomSessionHttpClient();
        final repository = repoFor(httpClient);

        final progress = await repository.loadRoomAnswerProgress(crowdRoom);

        expect(progress!.questionIndex, 0);
        expect(progress.answered, 3);
        expect(progress.active, 8);
        expect(httpClient.requestedPaths, [
          '/rest/v1/rpc/get_room_answer_progress',
        ]);
        expect(httpClient.requestBodies, [
          {'p_room_id': crowdRoom.id},
        ]);
      },
    );

    test('bozuk ilerleme cevabı sayaçsız bırakır, hata fırlatmaz', () async {
      for (final bad in <Object?>[
        null,
        'x',
        const {'question_index': 0, 'answered': 3},
        const {'question_index': 0, 'answered': 3, 'active': 0},
      ]) {
        final repository = repoFor(
          _RoomSessionHttpClient(answerProgressResponse: bad),
        );
        expect(await repository.loadRoomAnswerProgress(crowdRoom), isNull);
      }
    });

    test(
      'RPC yoksa (PGRST202) null döner ve oturumda bir daha sorulmaz',
      () async {
        final httpClient = _RoomSessionHttpClient(rpcErrorCode: 'PGRST202');
        final repository = repoFor(httpClient);

        expect(await repository.loadRoomAnswerProgress(crowdRoom), isNull);
        expect(await repository.loadRoomAnswerProgress(crowdRoom), isNull);

        expect(
          httpClient.requestedPaths
              .where((p) => p.endsWith('get_room_answer_progress'))
              .length,
          1,
        );
      },
    );

    test('mark_room_client_ready left dönerse oyuncu düşmüştür', () async {
      final repository = repoFor(
        _RoomSessionHttpClient(
          markReadyResponse: const {
            'status': 'left',
            'current_question_remaining_ms': 0,
          },
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: 'crowd',
        code: 'ZK-ABCDEF0123',
        category: 'Ziman',
        players: [],
        status: RoomStatus.active,
        maxPlayers: 8,
        isCustom: true,
      );

      await expectLater(
        repository.markRoomClientReady(room),
        throwsA(isA<RoomMemberLeftException>()),
      );
    });
  });
  test('engel listesi okunamazsa hata boş listeye dönüştürülmez', () async {
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _BlockedPlayersErrorHttpClient(),
      ),
    );

    await expectLater(
      repository.loadBlockedPlayerIds(),
      throwsA(isA<PostgrestException>()),
    );
  });

  test(
    'list_friends user_id döndürmese de arkadaş listesi çökmez ve seviye xp\'den hesaplanır',
    () async {
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _FriendsScoreHttpClient(),
        ),
      );

      final friends = await repository.loadFriends();

      expect(friends, hasLength(1));
      final friend = friends.single;
      expect(friend.friendName, 'Rojda');
      expect(friend.totalScore, 8420);
      // XPStore.xpRequiredForLevel(5) = 7000, (6) = 10000 — 8420 tam
      // olarak seviye 5'i karşılar. Değer sabit değil: sunucudan hiç
      // gelmeyen bir alanın istemcide doğru hesaplandığını kanıtlıyor.
      expect(friend.level, 5);
      expect(friend.lastActiveAt, isNotNull);
    },
  );

  test(
    'kategoriler sunucudan farklı olsa bile yerel soru bankasıyla aynı kalır',
    () async {
      final httpClient = _ServerCategoriesHttpClient();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final categories = await repository.loadCategories();

      expect(categories, repository.categories);
      expect(categories, isNot(contains('Tenê li serverê')));
      expect(httpClient.requestCount, 0);
    },
  );

  test('eşleştirme yalnız sunucuda etkin olan kategorileri kullanır', () async {
    final httpClient = _ServerCategoriesHttpClient(
      serverCategories: const ['Ziman'],
    );
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    final categories = await repository.loadMatchmakingCategories();

    expect(repository.categories, contains('Sînema'));
    expect(categories, const ['Ziman']);
    expect(categories, isNot(contains('Sînema')));
    expect(httpClient.requestCount, 1);
    expect(httpClient.lastRequestUrl?.path, '/rest/v1/categories');
    expect(httpClient.lastRequestUrl?.queryParameters['is_active'], 'eq.true');
  });

  test('Supabase local room shell does not include mock opponents', () {
    final repository = SupabaseZanKurdRepository(
      SupabaseClient('https://example.supabase.co', 'sb_publishable_test_key'),
    );

    final room = repository.createRoom();
    final names = room.players.map((player) => player.name).toSet();

    expect(names, contains('Tu'));
    expect(names, isNot(contains('Rojda')));
    expect(names, isNot(contains('Baran')));
    expect(names, isNot(contains('Dilan')));
  });

  test('online room creation uses only the atomic RPC snapshot', () async {
    final httpClient = _RoomSessionHttpClient(
      roomPlayersResponse: const [
        {
          'player_id': 'host-id',
          'score': 0,
          'streak': 0,
          'is_ready': true,
          'profiles': {'display_name': 'Berfin'},
        },
      ],
    );
    final repository = _SignedInRoomSessionRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    final room = await repository.createOnlineRoom(
      category: 'Ziman',
      secondsPerQuestion: 20,
    );

    expect(room.id, '00000000-0000-0000-0000-000000000099');
    expect(room.code, 'ZK-ABCDEF0123');
    expect(room.hostId, 'host-id');
    // Katılan tarafın da göreceği ad budur — bkz. aşağıdaki
    // 'online room join trusts the RPC host snapshot' testi.
    expect(room.name, '1vs1');
    expect(room.category, 'Ziman');
    expect(room.secondsPerQuestion, 20);
    expect(room.status, RoomStatus.lobby);
    expect(room.players.map((player) => player.id), ['host-id']);
    expect(httpClient.requestedPaths, [
      '/rest/v1/rpc/create_online_room',
      '/rest/v1/room_players',
    ]);
    expect(httpClient.requestBodies.single, {
      'p_category_name': 'Ziman',
      'p_seconds_per_question': 20,
      'p_question_count': 10,
      'p_entry_fee': 0,
    });
  });

  test(
    'online room join trusts the RPC host snapshot without a room query',
    () async {
      final httpClient = _RoomSessionHttpClient();
      final repository = _SignedInRoomSessionRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final room = await repository.joinOnlineRoom('zk abcdef0123');

      expect(room.hostId, 'host-id');
      // `createRoom()` (yerel/solo oda) 'Hevalên Zanînê' adını taşır ve
      // `joinOnlineRoom` onu üzerine yazmazsa katılan, ev sahibinin
      // gördüğü '1vs1' yerine bu adı görürdü — aynı oda iki başlıkla
      // açılırdı (2026-08-14 denetimi).
      expect(room.name, '1vs1');
      // Listede `set_room_ready` YOK ve olmamalı: katılan oyuncu odaya
      // hazır DEĞİL girer, hazır olduğunu kendisi bildirir. O çağrı
      // 2026-08-13'te kaldırıldı; gerekçesi `room_ready_state_test.dart`
      // içinde yazılıdır.
      expect(httpClient.requestedPaths, [
        '/rest/v1/rpc/join_room_by_code',
        '/rest/v1/room_players',
      ]);
      expect(
        httpClient.requestedPaths,
        isNot(contains('/rest/v1/rpc/set_room_ready')),
        reason:
            'Katılma yolu hazır durumunu sunucuya yazıyor; oyuncu onayı '
            'olmadan hazır sayılır ve ev sahibi yarışı erken başlatabilir.',
      );
      expect(httpClient.requestedPaths, isNot(contains('/rest/v1/rooms')));
      expect(httpClient.requestBodies.first, {'p_code': 'ZK-ABCDEF0123'});
    },
  );

  /// Kusur: `joinOnlineRoom` sunucu RPC'sinin fırlattığı `PostgrestException`ı
  /// ham hâliyle yukarı fırlatıyordu; `play_hub_screen.dart` her hatayı
  /// (bu dahil) TEK bir "oda bulunamadı" metnine indirgiyordu. Düzeltme
  /// repository katmanında: `PostgrestException.message` ayrıştırılıp
  /// `RoomJoinException(reason)` olarak yeniden fırlatılıyor — UI katmanı
  /// artık gerçek sebebe göre farklı metin gösterebiliyor
  /// (bkz. `test/room_join_error_mapping_test.dart`).
  test(
    'sunucunun "oda dolu" reddi RoomJoinFailureReason.full olarak yükselir',
    () async {
      final httpClient = _RoomSessionHttpClient(
        joinRoomErrorMessage: 'Room is full',
      );
      final repository = _SignedInRoomSessionRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      await expectLater(
        repository.joinOnlineRoom('zk abcdef0123'),
        throwsA(
          isA<RoomJoinException>().having(
            (error) => error.reason,
            'reason',
            RoomJoinFailureReason.full,
          ),
        ),
      );
    },
  );

  test('sunucunun "zaten başka odada" reddi RoomJoinFailureReason.'
      'alreadyInAnotherRoom olarak yükselir', () async {
    final httpClient = _RoomSessionHttpClient(
      joinRoomErrorMessage: 'Player is already in another live room',
    );
    final repository = _SignedInRoomSessionRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    await expectLater(
      repository.joinOnlineRoom('zk abcdef0123'),
      throwsA(
        isA<RoomJoinException>().having(
          (error) => error.reason,
          'reason',
          RoomJoinFailureReason.alreadyInAnotherRoom,
        ),
      ),
    );
  });

  test('legacy room code stays joinable during the server cutover', () async {
    final httpClient = _RoomSessionHttpClient();
    final repository = _SignedInRoomSessionRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    await repository.joinOnlineRoom('zkab');

    expect(httpClient.requestBodies.first, {'p_code': 'ZK-ZKAB'});
  });

  test('malformed room code is rejected before auth or RPC work', () async {
    final httpClient = _RoomSessionHttpClient();
    final repository = _SignedInRoomSessionRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    await expectLater(
      repository.joinOnlineRoom('ZK-ABCDEF01234'),
      throwsA(isA<FormatException>()),
    );
    expect(httpClient.requestedPaths, isEmpty);
  });

  test(
    'oda snapshotı tüm sunucu alanlarını ve oyuncu kimliklerini taşır',
    () async {
      final httpClient = _RoomSnapshotHttpClient();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final room = await repository.loadRoomSnapshot(
        '00000000-0000-0000-0000-000000000042',
      );

      expect(room.id, '00000000-0000-0000-0000-000000000042');
      expect(room.code, 'ZK-R3AL');
      expect(room.hostId, 'host-id');
      expect(room.category, 'Çand');
      expect(room.questionCount, 7);
      expect(room.secondsPerQuestion, 45);
      expect(room.status, RoomStatus.active);
      expect(room.players.map((player) => player.id), ['host-id', 'guest-id']);
      expect(room.players.map((player) => player.name), ['Berfin', 'Berfin']);
      expect(httpClient.requestedPaths, [
        '/rest/v1/rooms',
        '/rest/v1/room_players',
      ]);
    },
  );

  test(
    'resume RPC geçmiş cevapları ve milisaniyelik süreyi parse eder',
    () async {
      final httpClient = _RoomSessionHttpClient(
        resumeResponse: const {
          'room_id': '00000000-0000-0000-0000-000000000099',
          'current_question_index': 2,
          'own_score': 250,
          'own_streak': 2,
          'own_best_streak': 4,
          'correct_count': 1,
          'wrong_count': 1,
          'server_now': '2026-08-02T12:00:15.000Z',
          'current_question_started_at': '2026-08-02T12:00:10.000Z',
          'current_question_deadline': '2026-08-02T12:00:30.000Z',
          'current_question_remaining_ms': 15000,
          'pending_answer': {
            'question_id': 'question-3',
            'question_index': 2,
            'selected_option': 'D',
            'response_ms': 2750,
          },
          'answers': [
            {
              'question_id': 'question-1',
              'question_index': 0,
              'selected_option': 'A',
              'correct_option': 'B',
              'is_correct': false,
              'points_awarded': 0,
              'response_ms': 4100,
              'explanation': 'Açıklama',
              'explanation_ku': 'Ravekirin',
              'explanation_tr': 'Açıklama',
            },
            {
              'question_id': 'question-2',
              'question_index': 1,
              'selected_option': 'C',
              'correct_option': 'C',
              'is_correct': true,
              'points_awarded': 250,
              'response_ms': 1200,
              'explanation': null,
              'explanation_ku': null,
              'explanation_tr': null,
            },
          ],
        },
      );
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final resume = await repository.loadMyResumableRoom();

      expect(resume, isNotNull);
      expect(resume!.room.id, '00000000-0000-0000-0000-000000000099');
      expect(resume.room.players.map((player) => player.id), [
        'host-id',
        'guest-id',
      ]);
      expect(resume.currentQuestionIndex, 2);
      expect(resume.ownScore, 250);
      expect(resume.streak, 2);
      expect(resume.bestStreak, 4);
      expect(resume.correctCount, 1);
      expect(resume.wrongCount, 1);
      expect(resume.remainingMs, 15000);
      expect(resume.serverNow, DateTime.utc(2026, 8, 2, 12, 0, 15));
      expect(resume.answers, hasLength(2));
      expect(resume.answers.first.questionId, 'question-1');
      expect(resume.answers.first.correctOptionKey, 'B');
      expect(resume.answers.first.explanationKu, 'Ravekirin');
      expect(resume.answers.last.pointsAwarded, 250);
      expect(resume.pendingAnswer, isNotNull);
      expect(resume.pendingAnswer!.questionId, 'question-3');
      expect(resume.pendingAnswer!.questionIndex, 2);
      expect(resume.pendingAnswer!.selectedOptionKey, 'D');
      expect(resume.pendingAnswer!.responseMs, 2750);
      expect(httpClient.requestedPaths, [
        '/rest/v1/rpc/get_my_resumable_room',
        '/rest/v1/rooms',
        '/rest/v1/room_players',
      ]);
    },
  );

  test('resume RPC null dönerse snapshot sorgulanmaz', () async {
    final httpClient = _RoomSessionHttpClient();
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    expect(await repository.loadMyResumableRoom(), isNull);
    expect(httpClient.requestedPaths, ['/rest/v1/rpc/get_my_resumable_room']);
  });

  test(
    'terminal sonuç RPCsi eksiksiz ve kanonik snapshotı parse eder',
    () async {
      final httpClient = _RoomSessionHttpClient(
        resultResponse: _completedRoomResult,
      );
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final result = await repository.loadMyPendingRoomResult();

      expect(result, isNotNull);
      expect(result!.room.id, '00000000-0000-0000-0000-000000000099');
      expect(result.room.status, RoomStatus.finished);
      expect(result.room.players.map((player) => player.id), [
        'host-id',
        'guest-id',
      ]);
      expect(result.room.players.map((player) => player.score), [250, 100]);
      expect(result.ownPlayerId, 'host-id');
      expect(result.questionIds, ['question-1', 'question-2']);
      expect(result.answers.map((answer) => answer.questionIndex), [0, 1]);
      expect(result.answers.last.correctOptionKey, 'C');
      expect(result.winnerId, 'host-id');
      expect(result.endedReason, 'completed');
      expect(result.forfeitedBy, isNull);
      expect(result.finishedAt, DateTime.utc(2026, 8, 2, 12, 1));
      expect(httpClient.requestedPaths, [
        '/rest/v1/rpc/get_my_pending_room_result',
      ]);
    },
  );

  test('terminal sonuç RPCsi null dönerse pending sonuç yoktur', () async {
    final httpClient = _RoomSessionHttpClient();
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    expect(await repository.loadMyPendingRoomResult(), isNull);
    expect(httpClient.requestedPaths, [
      '/rest/v1/rpc/get_my_pending_room_result',
    ]);
  });

  test('exact terminal sonuç yalnız istenen oda kimliğiyle yüklenir', () async {
    final httpClient = _RoomSessionHttpClient(
      resultResponse: _completedRoomResult,
    );
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );
    const room = GameRoom(
      id: '00000000-0000-0000-0000-000000000099',
      name: '1vs1',
      code: 'ZK-RSME',
      category: 'Ziman',
      players: [],
      status: RoomStatus.finished,
      questionCount: 2,
    );

    final result = await repository.loadRoomResult(room);

    expect(result?.room.id, room.id);
    expect(httpClient.requestedPaths, ['/rest/v1/rpc/get_my_room_result']);
    expect(httpClient.requestBodies, [
      {'p_room_id': room.id},
    ]);
  });

  test(
    'exact terminal sonuç null ve oda kimliği hatasını güvenli işler',
    () async {
      final httpClient = _RoomSessionHttpClient();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );
      const exactRoom = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: '1vs1',
        code: 'ZK-RSME',
        category: 'Ziman',
        players: [],
        status: RoomStatus.finished,
        questionCount: 2,
      );
      const localRoom = GameRoom(
        name: '1vs1',
        code: 'ZK-LOCAL',
        category: 'Ziman',
        players: [],
        status: RoomStatus.finished,
        questionCount: 2,
      );

      expect(await repository.loadRoomResult(exactRoom), isNull);
      await expectLater(
        repository.loadRoomResult(localRoom),
        throwsA(isA<ArgumentError>()),
      );
      expect(httpClient.requestedPaths, ['/rest/v1/rpc/get_my_room_result']);
    },
  );

  test('exact terminal sonuç başka oda veya bozuk payloadı reddeder', () async {
    const requestedRoom = GameRoom(
      id: '00000000-0000-0000-0000-000000000042',
      name: '1vs1',
      code: 'ZK-OTHR',
      category: 'Ziman',
      players: [],
      status: RoomStatus.finished,
      questionCount: 2,
    );
    const matchingRoom = GameRoom(
      id: '00000000-0000-0000-0000-000000000099',
      name: '1vs1',
      code: 'ZK-RSME',
      category: 'Ziman',
      players: [],
      status: RoomStatus.finished,
      questionCount: 2,
    );
    final mismatchedRepository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _RoomSessionHttpClient(
          resultResponse: _completedRoomResult,
        ),
      ),
    );
    final malformedRepository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _RoomSessionHttpClient(
          resultResponse: {
            for (final entry in _completedRoomResult.entries)
              if (entry.key != 'winner_id') entry.key: entry.value,
          },
        ),
      ),
    );

    await expectLater(
      mismatchedRepository.loadRoomResult(requestedRoom),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      malformedRepository.loadRoomResult(matchingRoom),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'terminal sonuç parserı eksik, tutarsız ve sızıntılı payloadı reddeder',
    () async {
      final malformedPayloads = <Map<String, Object?>>[
        {..._completedRoomResult, 'ended_reason': 'forfeit'},
        {
          ..._completedRoomResult,
          'room': {
            ..._completedRoomResult['room']! as Map<String, Object?>,
            'current_question_index': 1,
          },
        },
        {
          ..._completedRoomResult,
          'answers': (_completedRoomResult['answers']! as List<Object?>)
              .take(1)
              .toList(),
        },
        {
          ..._completedRoomResult,
          'question_ids': ['question-2', 'question-1'],
        },
        {
          for (final entry in _completedRoomResult.entries)
            if (entry.key != 'question_ids') entry.key: entry.value,
        },
        {
          ..._completedRoomResult,
          'players': [
            ..._completedRoomResult['players']! as List<Object?>,
            {
              'player_id': 'third-id',
              'display_name': 'Azad',
              'final_score': 0,
              'final_streak': 0,
            },
          ],
        },
        {
          ..._completedRoomResult,
          'players': [
            {
              ...(_completedRoomResult['players']! as List<Object?>).first
                  as Map<String, Object?>,
              'final_score': 251,
            },
            (_completedRoomResult['players']! as List<Object?>).last,
          ],
        },
        {
          ..._completedRoomResult,
          'answers': [
            {
              for (final entry
                  in ((_completedRoomResult['answers']! as List<Object?>).first
                          as Map<String, Object?>)
                      .entries)
                if (entry.key != 'correct_option') entry.key: entry.value,
            },
            (_completedRoomResult['answers']! as List<Object?>).last,
          ],
        },
        {..._completedRoomResult, 'winner_id': 'guest-id'},
      ];

      for (final payload in malformedPayloads) {
        final repository = SupabaseZanKurdRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: _RoomSessionHttpClient(resultResponse: payload),
          ),
        );

        await expectLater(
          repository.loadMyPendingRoomResult(),
          throwsA(isA<FormatException>()),
          reason: 'Bozuk terminal payload reddedilmelidir: $payload',
        );
      }
    },
  );

  test(
    'terminal sonuç acknowledge RPCsi yalnız oda kimliğini gönderir',
    () async {
      final httpClient = _RoomSessionHttpClient();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: '1vs1',
        code: 'ZK-RSME',
        category: 'Ziman',
        players: [],
        status: RoomStatus.finished,
        questionCount: 2,
      );

      await repository.acknowledgeRoomResult(room);

      expect(httpClient.requestedPaths, [
        '/rest/v1/rpc/acknowledge_room_result',
      ]);
      expect(httpClient.requestBodies, [
        {'p_room_id': '00000000-0000-0000-0000-000000000099'},
      ]);
    },
  );

  test(
    'resume RPC pending_answer alanını zorunlu ve tip güvenli parse eder',
    () async {
      const baseResume = {
        'room_id': '00000000-0000-0000-0000-000000000099',
        'current_question_index': 0,
        'own_score': 0,
        'own_streak': 0,
        'best_streak': 0,
        'correct_count': 0,
        'wrong_count': 0,
        'server_now': '2026-08-02T12:00:00.000Z',
        'current_question_started_at': null,
        'current_question_deadline': null,
        'current_question_remaining_ms': 0,
        'answers': <Object>[],
      };
      final missingClient = _RoomSessionHttpClient(resumeResponse: baseResume);
      final missingRepository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: missingClient,
        ),
      );

      await expectLater(
        missingRepository.loadMyResumableRoom(),
        throwsA(isA<FormatException>()),
      );

      final leakyClient = _RoomSessionHttpClient(
        resumeResponse: const {
          ...baseResume,
          'pending_answer': {
            'question_id': 'question-1',
            'question_index': 0,
            'selected_option': 'A',
            'response_ms': 1000,
            'is_correct': true,
          },
        },
      );
      final leakyRepository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: leakyClient,
        ),
      );

      await expectLater(
        leakyRepository.loadMyResumableRoom(),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test(
    'client-ready ve CAS advance RPC parametreleri sunucuya taşınır',
    () async {
      final httpClient = _RoomSessionHttpClient();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: '1vs1',
        code: 'ZK-RSME',
        category: 'Ziman',
        players: [],
        status: RoomStatus.active,
        questionCount: 10,
      );

      expect(await repository.markRoomClientReady(room), isNull);
      expect(
        await repository.advanceRoomQuestion(room, expectedQuestionIndex: 2),
        isNull,
      );
      expect(httpClient.requestedPaths, [
        '/rest/v1/rpc/mark_room_client_ready',
        '/rest/v1/rpc/get_my_resumable_room',
        '/rest/v1/rpc/advance_room_question',
        '/rest/v1/rpc/get_my_resumable_room',
      ]);
      expect(httpClient.requestBodies, [
        {'p_room_id': '00000000-0000-0000-0000-000000000099'},
        {
          'p_room_id': '00000000-0000-0000-0000-000000000099',
          'p_expected_question_index': 2,
        },
      ]);
    },
  );

  test('RPC sonrası farklı oda snapshotı kabul edilmez', () async {
    final httpClient = _RoomSessionHttpClient(
      resumeResponse: const {
        'room_id': '00000000-0000-0000-0000-000000000099',
        'current_question_index': 0,
        'own_score': 0,
        'own_streak': 0,
        'best_streak': 0,
        'correct_count': 0,
        'wrong_count': 0,
        'server_now': '2026-08-02T12:00:00.000Z',
        'current_question_started_at': null,
        'current_question_deadline': null,
        'current_question_remaining_ms': 0,
        'pending_answer': null,
        'answers': [],
      },
    );
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );
    const wrongRoom = GameRoom(
      id: '00000000-0000-0000-0000-000000000042',
      name: '1vs1',
      code: 'ZK-OTHR',
      category: 'Ziman',
      players: [],
      status: RoomStatus.active,
      questionCount: 10,
    );

    await expectLater(
      repository.markRoomClientReady(wrongRoom),
      throwsA(isA<FormatException>()),
    );
  });

  test('leave room atomik RPC sonucunu parse eder', () async {
    for (final expectation in [
      (
        payload: const {
          'status': 'finished',
          'reason': 'completed',
          'forfeited_by': null,
        },
        status: 'finished',
        reason: 'completed',
        forfeitedBy: null,
        completed: true,
      ),
      (
        payload: const {
          'status': 'finished',
          'reason': 'forfeit',
          'forfeited_by': 'guest-id',
        },
        status: 'finished',
        reason: 'forfeit',
        forfeitedBy: 'guest-id',
        completed: false,
      ),
      (
        payload: const {
          'status': 'left',
          'reason': 'guest_left',
          'forfeited_by': null,
        },
        status: 'left',
        reason: 'guest_left',
        forfeitedBy: null,
        completed: false,
      ),
    ]) {
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _RoomSessionHttpClient(
            leaveResponse: expectation.payload,
          ),
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: '1vs1',
        code: 'ZK-RSME',
        category: 'Ziman',
        players: [],
        status: RoomStatus.active,
        questionCount: 10,
      );

      final outcome = await repository.leaveOnlineRoom(room);

      expect(outcome.status, expectation.status);
      expect(outcome.reason, expectation.reason);
      expect(outcome.forfeitedBy, expectation.forfeitedBy);
      expect(outcome.completed, expectation.completed);
    }
  });

  test('leave room eksik veya yanlış tipli cevabı reddeder', () async {
    // Fazlalık alan artık reddedilmez: kalabalık lobide host devrinde sunucu
    // `new_host_id` ekler ve gelecekte yeni alanlar eklenebilir. Zorunlu üç
    // alanın varlığı ve tipi hâlâ denetlenir.
    final malformed = <Object?>[
      const {'status': 'finished', 'reason': 'completed'},
      const {'status': 'finished', 'reason': 3, 'forfeited_by': null},
    ];
    const room = GameRoom(
      id: '00000000-0000-0000-0000-000000000099',
      name: '1vs1',
      code: 'ZK-RSME',
      category: 'Ziman',
      players: [],
      status: RoomStatus.active,
      questionCount: 10,
    );

    for (final payload in malformed) {
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _RoomSessionHttpClient(leaveResponse: payload),
        ),
      );
      await expectLater(
        repository.leaveOnlineRoom(room),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test(
    'leave room, terminal sonuç ve resume fazla anahtarı yok sayar',
    () async {
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: '1vs1',
        code: 'ZK-RSME',
        category: 'Ziman',
        players: [],
        status: RoomStatus.active,
        questionCount: 10,
      );
      final leaveRepository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _RoomSessionHttpClient(
            leaveResponse: const {
              'status': 'finished',
              'reason': 'completed',
              'forfeited_by': null,
              'yeni_alan': 100,
            },
          ),
        ),
      );
      expect((await leaveRepository.leaveOnlineRoom(room)).status, 'finished');

      final resultRepository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _RoomSessionHttpClient(
            resultResponse: {
              ..._completedRoomResult,
              'yeni_alan': true,
              'room': {
                ..._completedRoomResult['room']! as Map<String, Object?>,
                'yeni_alan': 1,
              },
              'players': [
                for (final player
                    in _completedRoomResult['players']! as List<Object?>)
                  {...player! as Map<String, Object?>, 'yeni_alan': 'x'},
              ],
              'answers': [
                for (final answer
                    in _completedRoomResult['answers']! as List<Object?>)
                  {...answer! as Map<String, Object?>, 'yeni_alan': 'x'},
              ],
            },
          ),
        ),
      );
      expect(await resultRepository.loadMyPendingRoomResult(), isNotNull);
    },
  );

  test(
    'leave room ve cancel matchmaking yetkili RPC sözleşmesini kullanır',
    () async {
      final httpClient = _RoomSessionHttpClient();
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );
      const room = GameRoom(
        id: '00000000-0000-0000-0000-000000000099',
        name: '1vs1',
        code: 'ZK-RSME',
        category: 'Ziman',
        players: [],
        status: RoomStatus.active,
        questionCount: 10,
      );

      final outcome = await repository.leaveOnlineRoom(room);
      final cancellation = await repository.cancelMatchmaking();

      expect(outcome.reason, 'forfeit');
      expect(outcome.forfeitedBy, 'host-id');
      expect(cancellation['status'], 'matched');
      expect(httpClient.requestedPaths, [
        '/rest/v1/rpc/leave_room',
        '/rest/v1/rpc/cancel_matchmaking',
      ]);
      expect(httpClient.requestBodies.first, {
        'p_room_id': '00000000-0000-0000-0000-000000000099',
      });
    },
  );

  test('oda bitiş nedeni normal finish ile forfeiti ayırır', () async {
    final httpClient = _RoomSessionHttpClient();
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );
    const room = GameRoom(
      id: '00000000-0000-0000-0000-000000000099',
      name: '1vs1',
      code: 'ZK-RSME',
      category: 'Ziman',
      players: [],
      status: RoomStatus.active,
      questionCount: 10,
    );

    final state = await repository.loadRoomEndState(room);

    expect(state.status, RoomStatus.finished);
    expect(state.endedReason, 'forfeit');
    expect(state.forfeitedBy, 'guest-id');
  });

  test('RPC şema uyumsuzluğu sessizce yutulmaz', () async {
    final httpClient = _RoomSessionHttpClient(rpcErrorCode: 'PGRST202');
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: httpClient,
      ),
    );

    await expectLater(
      repository.cancelMatchmaking(),
      throwsA(
        isA<PostgrestException>().having(
          (error) => error.code,
          'code',
          'PGRST202',
        ),
      ),
    );
  });

  // touch_matchmaking göçten ÖNCE yayınlanan derlemede 404/PGRST202 verir;
  // bekleme ekranı bunu hata saymayıp eski yola (akış + 20 sn) düşmeli ve
  // her 3 saniyede ölü bir RPC'ye vurmamalı.
  test(
    'touch_matchmaking RPC yoksa sessizce unknown döner ve bir daha sormaz',
    () async {
      final httpClient = _RoomSessionHttpClient(rpcErrorCode: 'PGRST202');
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: httpClient,
        ),
      );

      final first = await repository.touchMatchmaking();
      final second = await repository.touchMatchmaking();

      expect(first.status, MatchmakingTouchStatus.unknown);
      expect(second.status, MatchmakingTouchStatus.unknown);
      expect(
        httpClient.requestedPaths.where((p) => p.endsWith('touch_matchmaking')),
        hasLength(1),
      );
    },
  );

  test('touch_matchmaking eşleşme özetini tipli sonuca çevirir', () async {
    final repository = SupabaseZanKurdRepository(
      SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test_key',
        httpClient: _RoomSessionHttpClient(),
      ),
    );

    final touch = await repository.touchMatchmaking();

    expect(touch.status, MatchmakingTouchStatus.matched);
    expect(touch.roomId, '00000000-0000-0000-0000-000000000099');
    expect(touch.opponentName, 'Rojda');
    expect(
      MatchmakingTouch.fromJson(const {'status': 'waiting'}).status,
      MatchmakingTouchStatus.waiting,
    );
    expect(
      MatchmakingTouch.fromJson(const {'status': 'matched'}).status,
      MatchmakingTouchStatus.unknown,
      reason: 'room_id eksik eşleşme cevabı odaya çevrilmemeli',
    );
    expect(
      MatchmakingTouch.fromJson(const {'status': 'none'}).status,
      MatchmakingTouchStatus.none,
    );
  });

  test('online room join uses the room-code RPC contract', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'join_room_by_code'"));
    expect(
      source,
      isNot(contains(".from('rooms')\n        .select('id, code")),
    );
  });

  // Bu test eskiden tek bir dosyayı (`online_multiplayer_ready.sql`)
  // okuyup dört RPC'nin orada tanımlı olduğunu doğruluyordu. O dosya
  // 2026-08-01'de `supabase/archive/` altına alındı: tarihsizdi ve
  // alfabetik sırada tarihli göçlerden sonra geldiği için
  // sertleştirilmiş `submit_answer` sürümünü ezebiliyordu.
  //
  // Sözleşme artık daha güçlü: her RPC'nin TARİHLİ bir göçte tanımlı
  // olması gerekiyor. Böylece hangi dosyada durduğu değil, uygulama
  // sırasının onu koruduğu ölçülüyor.
  test('çok oyunculu RPC ler tarihli göçlerde tanımlı', () {
    final dated = Directory('supabase')
        .listSync()
        .whereType<File>()
        .where((file) => RegExp(r'/\d{4}-\d{2}-\d{2}_').hasMatch(file.path))
        .map((file) => file.readAsStringSync())
        .join('\n');

    for (final rpc in [
      'create_online_room',
      'join_room_by_code',
      'start_room_game',
      'mark_room_client_ready',
      'advance_room_question',
      'finish_room_game',
      'submit_answer',
    ]) {
      expect(
        dated,
        contains('function public.$rpc'),
        reason:
            '$rpc yalnız tarihsiz bir dosyada tanımlıysa, klasörü sırayla '
            'çalıştıran biri onu sertleştirilmiş sürümün üzerine yazar.',
      );
    }
    expect(
      dated,
      contains('grant execute on function public.join_room_by_code'),
    );
  });

  test('solo question loaders never fetch answer-bearing database rows', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("from('quiz_eligible_questions')")));
    expect(source, isNot(contains("select('questions(")));
    expect(source, isNot(contains('_questionColumns')));
  });

  test('submit answer forwards measured response time to the RPC', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'p_response_ms': responseMs"));
    expect(source, isNot(contains("'p_response_ms': 2000")));
  });

  test('shared room broadcast channel keeps listener ref-counts', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains('class _ManagedRoomChannel'));
    expect(source, contains('managed.listenerCount++'));
    expect(source, contains('managed.listenerCount--'));
    expect(source, contains('_disposeUnretainedRoomChannel'));
    expect(source, contains('_retainRoomChannel(roomId).onBroadcast('));
  });

  test(
    'multiplayer integrity migration closes direct answer and score access',
    () {
      final sql = File(
        'supabase/2026-07-22_multiplayer_integrity_hardening.sql',
      ).readAsStringSync();

      expect(sql, contains('function public.get_room_questions'));
      expect(sql, contains('function public.set_room_ready'));
      expect(sql, contains('revoke select on public.questions'));
      expect(sql, contains('revoke select on public.quiz_eligible_questions'));
      expect(
        sql,
        contains(
          'drop policy if exists "Players update their own room membership"',
        ),
      );
      expect(
        sql,
        contains('drop policy if exists "Hosts can update their own rooms"'),
      );
      expect(sql, contains('from public.room_questions rq'));
      expect(sql, contains('rq.question_id = p_question_id'));
      expect(sql, contains("r.status = 'active'"));
      expect(sql, contains('for update'));
      expect(
        'v_points integer := 0;'.allMatches(sql).length,
        1,
        reason: 'submit_answer PL/pgSQL değişkeni iki kez tanımlanmamalı.',
      );
      expect(sql, contains("nullif(p_selected_option, ''), 'TIMEOUT'"));
      expect(sql, contains("'A', 'B', 'C', 'D', 'TIMEOUT'"));
    },
  );

  test('room question and ready flows use hardened RPCs', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final roomLoader = source.substring(
      source.indexOf('Future<List<QuizQuestion>> loadRoomQuestions'),
      source.indexOf('Future<List<QuizQuestion>> loadDailyQuestions'),
    );
    final readySetter = source.substring(
      source.indexOf('Future<void> updateReady'),
      source.indexOf('Future<void> startGame'),
    );

    expect(roomLoader, contains("'get_room_questions'"));
    expect(roomLoader, isNot(contains("from('room_questions')")));
    expect(readySetter, contains("'set_room_ready'"));
    expect(readySetter, isNot(contains('.update(')));
  });

  test('room player queries preserve avatar showcase fields', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(
      source,
      contains('profiles(display_name, avatar_icon, avatar_color'),
    );
    expect(source, contains("avatarIcon: profile?['avatar_icon'] as String?"));
    expect(
      source,
      contains("avatarColor: profile?['avatar_color'] as String?"),
    );
    expect(source, contains("avatarUrl: profile?['avatar_url'] as String?"));
    expect(
      source,
      contains("avatarFrame: profile?['avatar_frame'] as String?"),
    );
    expect(
      source,
      contains("showcaseTitle: profile?['showcase_title'] as String?"),
    );
  });

  test('matchmaking screen renders matched opponent with avatar identity', () {
    final source = File(
      'lib/src/screens/matchmaking_screen.dart',
    ).readAsStringSync();

    expect(source, contains('_opponentIdentity'));
    expect(source, contains('AvatarIdentity _identityFromPlayer'));
    expect(
      RegExp(r'photoUrl\s*:\s*_opponentIdentity\.photoUrl').hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'iconId\s*:\s*_opponentIdentity\.iconId').hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'colorHex\s*:\s*_opponentIdentity\.colorHex').hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(r'frameId\s*:\s*_opponentIdentity\.frameId').hasMatch(source),
      isTrue,
    );
  });

  test('live scoreboard renders player avatar identity', () {
    final source = File(
      'lib/src/screens/quiz/quiz_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('PlayerAvatar('));
    expect(source, contains('photoUrl: player.avatarUrl'));
    expect(source, contains('iconId: player.avatarIcon'));
    expect(source, contains('colorHex: player.avatarColor'));
    expect(source, contains('frameId: player.avatarFrame'));
  });

  test('duel score header renders both player avatars', () {
    final source = File(
      'lib/src/screens/quiz/quiz_widgets.dart',
    ).readAsStringSync();

    expect(source, contains('required this.player'));
    expect(source, contains('required this.opponent'));
    expect(source, contains('photoUrl: player.avatarUrl'));
    expect(source, contains('photoUrl: opponent.avatarUrl'));
    expect(source, isNot(contains('Icons.android')));
  });

  test('quiz result standings render player avatar identity', () {
    final source = File(
      'lib/src/screens/quiz_result_screen.dart',
    ).readAsStringSync();

    expect(source, contains('PlayerAvatar('));
    expect(source, contains('photoUrl: player.avatarUrl'));
    expect(source, contains('iconId: player.avatarIcon'));
    expect(source, contains('colorHex: player.avatarColor'));
    expect(source, contains('frameId: player.avatarFrame'));
  });

  test(
    'avatar showcase SQL migration defines profile fields and storage policy',
    () {
      final sql = File(
        'supabase/2026-07-05_avatar_showcase.sql',
      ).readAsStringSync();

      expect(sql, contains('alter table public.profiles'));
      expect(sql, contains('avatar_icon'));
      expect(sql, contains('avatar_url'));
      expect(sql, contains('avatar_frame'));
      expect(sql, contains('showcase_title'));
      expect(sql, contains('Users update their own profile'));
      expect(sql, contains('using (id = auth.uid())'));
      expect(sql, contains("insert into storage.buckets"));
      expect(sql, contains("id = 'avatars'"));
      expect(sql, contains('bucket_id = \'avatars\''));
      expect(sql, contains('storage.foldername(name)'));
      expect(sql, contains('drop function if exists public.get_leaderboard'));
      expect(sql, contains('function public.get_leaderboard'));
      expect(sql, contains('avatar_color'));
      expect(sql, contains('grant execute on function public.get_leaderboard'));
    },
  );

  // Yol 2026-07-31'de değişti. `delete_my_account_rpc.sql` tarihsizdi ve
  // alfabetik sırada tarihli göçlerden SONRA geldiği için, sırayla
  // çalıştırılan bir kurulumda 2026-07-29 sertleştirmesinin üzerine eski
  // sürümü yazıyordu; `supabase/archive/` altına alındı. Bekçi artık
  // yetkili tanımı okuyor — arşivlenmiş kopyayı değil.
  test('account deletion SQL removes user avatar storage objects', () {
    final sql = File(
      'supabase/2026-07-29_client_reward_authority_fix.sql',
    ).readAsStringSync();

    expect(sql, contains('delete from storage.objects'));
    expect(sql, contains("bucket_id = 'avatars'"));
    expect(sql, contains('storage.foldername(name)'));
    expect(sql, contains('v_user_id::text'));
  });

  test('Supabase çarkı satın alınmış ekstra hakkı RPC ile kullanır', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("client.rpc<bool>('can_spin_today')"));
    expect(source, contains("client.rpc<dynamic>('claim_extra_spin')"));
    expect(source, contains("'spin_wheel_extra'"));
    expect(
      source,
      contains(".from('shop_purchases')"),
      reason:
          'Sahiplik yalnız sunucunun değiştirilemez hak kaydından okunmalı.',
    );
  });

  test(
    'turnuva bütünlüğü migrationı stage sıçramasını ve erken şampiyonluğu engeller',
    () {
      final sql = File(
        'supabase/2026-07-14_tournament_integrity_hardening.sql',
      ).readAsStringSync();

      expect(sql, contains('v_current_stage'));
      expect(sql, contains('v_requested_rank > v_current_rank + 1'));
      expect(sql, contains("p_stage <> 'lost'"));
      expect(sql, contains("p_stage = 'won'"));
      expect(sql, contains("v_current_stage <> 'final'"));
      expect(sql, contains('RETURN QUERY SELECT FALSE'));
      expect(sql, contains('ON CONFLICT (user_id, tournament_date) DO UPDATE'));
    },
  );

  test('question reports also update the live content-quality counter', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    expect(source, contains("'report_question'"));
    expect(source, contains("'p_question_id': question.id"));
    expect(source, contains("reason: 'report_question RPC failed'"));
  });

  test('solo quiz questions come from the embedded approved bank', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();

    final loaders = source.substring(
      source.indexOf('Future<List<QuizQuestion>> loadQuestions({'),
      source.indexOf('Future<List<QuizQuestion>> loadRoomQuestions'),
    );
    expect(loaders, contains('_offline.loadQuestions'));
    expect(loaders, contains('_offline.loadLevelQuestions'));
    expect(loaders, isNot(contains('.from(')));
  });

  // Bu test eskiden sayının SUNUCUDAN, `quiz_public_questions` görünümünden
  // exact count ile geldiğini doğruluyordu. Niyeti güvenlikti: cevap taşıyan
  // `questions` tablosu okunmasın.
  //
  // 2026-07-31 denetiminde daha derin bir kusur çıktı: sayı sunucudan,
  // sorular ise YEREL bankadan geliyordu. İki kaynak kopuktu ve sonuç
  // yalnız yanlış bir etiket değildi — `categories_tab` bir kategoriyi
  // `questionCount! < 20` olduğunda "Yakında" diye KİLİTLİYOR. Sunucuda az
  // kayıt olan bir kategori, yerel bankada 200 sorusu olduğu hâlde
  // oynanamaz görünebiliyordu.
  //
  // Sayı artık soruların geldiği bankadan okunuyor. Güvenlik niyeti de
  // korunuyor, hatta güçleniyor: sunucudan hiç okuma yapılmıyor.
  test('kategori sayısı soruların geldiği kaynaktan okunur', () {
    final source = File(
      'lib/src/data/supabase_zankurd_repository.dart',
    ).readAsStringSync();
    final method = source.substring(
      source.indexOf('Future<Map<String, int>> loadCategoryQuestionCounts()'),
      source.indexOf('Future<List<QuizQuestion>> loadQuestions({'),
    );

    expect(
      method,
      contains('_offline.loadCategoryQuestionCounts()'),
      reason:
          'Sayı ve sorular aynı kaynaktan gelmeli; aksi hâlde etiket ve '
          '"Yakında" kilidi oyuncunun karşılaşacağı havuzu tarif etmez.',
    );
    expect(
      method,
      isNot(contains("from('questions')")),
      reason: 'Cevap taşıyan tablo hiçbir koşulda okunmaz.',
    );
    expect(
      method,
      isNot(contains('.from(')),
      reason: 'Sunucudan okuma yok: kaynak birliği tek yerde tutulur.',
    );
  });

  test(
    'suggested questions migration exposes a service-role moderation RPC',
    () {
      final source = File(
        'supabase/2026-07-13_suggested_questions_moderation.sql',
      ).readAsStringSync();

      expect(source, contains('moderate_suggested_question'));
      expect(source, contains("p_status NOT IN ('approved', 'rejected')"));
      expect(source, contains("auth.role() <> 'service_role'"));
      expect(source, contains('reviewed_at'));
    },
  );

  test('curated question wave is idempotent and approved', () {
    final source = File(
      'supabase/2026-07-13_curated_question_wave_1.sql',
    ).readAsStringSync();

    expect(source, contains("source_url = 'curated_movement_wave_1'"));
    expect(source, contains("language_code, prompt"));
    expect(source, contains("is_approved, question_type, image_url"));
    expect(source, contains("'curated_movement_wave_1'"));
  });

  test(
    'MockZanKurdRepository implements subscribeRoomBroadcast and sendRoomBroadcast',
    () async {
      final repository = SupabaseZanKurdRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
        ),
      );

      expect(
        () => repository.subscribeRoomBroadcast('room_123'),
        returnsNormally,
      );
      await expectLater(
        repository.sendRoomBroadcast('room_123', {'test': 'data'}),
        completes,
      );
    },
  );

  group('loadFavoriteQuestions', () {
    _SignedInRoomSessionRepository repositoryFor(http.BaseClient httpClient) =>
        _SignedInRoomSessionRepository(
          SupabaseClient(
            'https://example.supabase.co',
            'sb_publishable_test_key',
            httpClient: httpClient,
          ),
        );

    test('oda maçı favorisi RPC ile çözülür, cevapsız işaretlenir ve ölü '
        'quiz_public_questions görünümüne gidilmez', () async {
      // 2026-08-14'te oda maçında kaydedilmiş favoriler `quiz_public_questions`
      // görünümünden çözülüyordu. Görünüm istemciye hep "permission denied"
      // veriyordu (altındaki `questions` tablosunda SELECT yok), hata
      // yutuluyor ve favori yine görünmüyordu; çağrı ve görünüm 2026-10-15'te
      // kaldırıldı. Çözüm `get_my_favorite_questions` RPC'sidir (cevap
      // taşımaz). Bekçi: paketli favori yerelden, oda favorisi RPC'den gelir;
      // sunucuya `favorite_questions` ve RPC dışında gidilmez.
      final httpClient = _FavoriteQuestionsHttpClient();

      final questions = await repositoryFor(httpClient).loadFavoriteQuestions();

      expect(questions.map((q) => q.id), [
        _FavoriteQuestionsHttpClient.serverOnlyId,
        'curated_movement_0001',
      ]);
      expect(questions.first.hasHiddenAnswer, isTrue);
      expect(questions.first.category, 'Ziman');
      expect(questions.first.answers, ['A', 'B', 'C', 'D']);
      expect(questions.last.hasHiddenAnswer, isFalse);
      expect(httpClient.requestedPaths, [
        '/rest/v1/favorite_questions',
        '/rest/v1/rpc/get_my_favorite_questions',
      ]);
      expect(httpClient.rpcBodies.single, {
        'p_ids': [_FavoriteQuestionsHttpClient.serverOnlyId],
      });
      expect(
        File(
          'lib/src/data/supabase_zankurd_repository.dart',
        ).readAsStringSync().contains("from('quiz_public_questions')"),
        isFalse,
      );
    });

    test(
      'paketli bankadaki ve uuid olmayan kimlikler RPC\'ye gönderilmez',
      () async {
        final httpClient = _FavoriteQuestionsHttpClient(serverIds: const []);

        final questions = await repositoryFor(
          httpClient,
        ).loadFavoriteQuestions();

        expect(questions.map((q) => q.id), ['curated_movement_0001']);
        expect(httpClient.requestedPaths, ['/rest/v1/favorite_questions']);
      },
    );

    test('çözülemeyen kimlikler 50\'lik parçalarla sorulur', () async {
      final ids = [
        for (var i = 0; i < 120; i++)
          '00000000-0000-4000-8000-${i.toString().padLeft(12, '0')}',
      ];
      final httpClient = _FavoriteQuestionsHttpClient(serverIds: ids);

      final questions = await repositoryFor(httpClient).loadFavoriteQuestions();

      expect(httpClient.rpcBodies.map((b) => (b['p_ids'] as List).length), [
        50,
        50,
        20,
      ]);
      expect(questions, hasLength(121));
      expect(questions.take(120).map((q) => q.id), ids);
    });

    test(
      'RPC henüz yoksa (PGRST202) sessizce atlanır, yerel favori gelir',
      () async {
        final httpClient = _FavoriteQuestionsHttpClient(
          rpcStatus: 404,
          rpcBody: const {
            'code': 'PGRST202',
            'message': 'Could not find the function',
          },
        );

        final questions = await repositoryFor(
          httpClient,
        ).loadFavoriteQuestions();

        expect(questions.map((q) => q.id), ['curated_movement_0001']);
      },
    );

    test(
      'taşıma hatası yukarı çıkar: ekran hata + yeniden dene gösterir',
      () async {
        final httpClient = _FavoriteQuestionsHttpClient(
          rpcThrows: const SocketException('Network is unreachable'),
        );

        await expectLater(
          repositoryFor(httpClient).loadFavoriteQuestions(),
          throwsA(anything),
        );
      },
    );
  });
}
