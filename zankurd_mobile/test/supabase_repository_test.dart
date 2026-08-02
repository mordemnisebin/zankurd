import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
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
  _RoomSessionHttpClient({this.resumeResponse, this.rpcErrorCode});

  final Object? resumeResponse;
  final String? rpcErrorCode;
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
      case '/rest/v1/rpc/get_my_resumable_room':
        return _jsonResponse(request, resumeResponse);
      case '/rest/v1/rpc/leave_room':
        return _jsonResponse(request, const {
          'status': 'finished',
          'reason': 'forfeit',
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
          'code': 'ZK-RSME',
          'host_id': 'host-id',
          'question_count': 10,
          'seconds_per_question': 20,
          'status': 'active',
          'categories': {'name': 'Ziman'},
        });
      case '/rest/v1/room_players':
        return _jsonResponse(request, const [
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
        ]);
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

void main() {
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

      await repository.leaveOnlineRoom(room);
      final cancellation = await repository.cancelMatchmaking();

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
      'join_room_by_code',
      'start_room_game',
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
    expect(source, contains('photoUrl: _opponentIdentity.photoUrl'));
    expect(source, contains('iconId: _opponentIdentity.iconId'));
    expect(source, contains('colorHex: _opponentIdentity.colorHex'));
    expect(source, contains('frameId: _opponentIdentity.frameId'));
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
}
