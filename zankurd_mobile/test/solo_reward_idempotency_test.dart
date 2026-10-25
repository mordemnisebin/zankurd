/// Solo tur ödülü TEKİL olmalı: yeniden gönderim ikinci kez ödememeli.
///
/// Kusur: `claim_solo_reward` tekillik anahtarı taşımıyordu. İlk çağrı
/// sunucuda işlenmiş ama yanıtı kaybolmuşsa (kopan bağlantı) tur kuyruğa
/// alınıyor ve yeniden gönderim ikinci kez jeton yazıyordu (günlük tavana
/// kadar). Oda turlarında bu yok (`quiz_complete:room=…` aranır), yalnız solo
/// açıktı.
///
/// Niçin sessizdi: ödeme başarılı sayılıp tutarlı görünüyordu; çifte yazım
/// yalnız defterde (coin_transactions) ve yalnız ağ tam o ânı vurduğunda
/// ortaya çıkar. İstemci tarafı: tur kimliği turun İLK denemesinde üretilir,
/// kuyruğa yazılır ve her yeniden denemede aynen gider.
library;

import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/durable_write.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/utils/client_round_id.dart';

class _RpcRecorder extends http.BaseClient {
  _RpcRecorder({this.missingNewSignature = false});

  /// Göç uygulanmamış sunucu: 4 argümanlı imza yok (PGRST202).
  final bool missingNewSignature;
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.path.endsWith('/rpc/claim_solo_reward')) {
      throw StateError('Beklenmeyen istek: ${request.url.path}');
    }
    final body =
        jsonDecode(await (request as http.Request).finalize().bytesToString())
            as Map<String, dynamic>;
    bodies.add(body);
    if (missingNewSignature && body.containsKey('p_client_round_id')) {
      final bytes = utf8.encode(
        jsonEncode({
          'code': 'PGRST202',
          'message': 'Could not find the function',
          'details': null,
          'hint': null,
        }),
      );
      return http.StreamedResponse(Stream.value(bytes), 404, request: request);
    }
    final bytes = utf8.encode(
      jsonEncode({'amount': 12, 'daily_cap': 45, 'cap_reached': false}),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _SignedInRepo extends SupabaseZanKurdRepository {
  _SignedInRepo(super.client);

  @override
  String? get currentUserId => 'solo-user';

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'solo-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-10-15T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

_SignedInRepo _repo(_RpcRecorder http) => _SignedInRepo(
  SupabaseClient(
    'https://example.supabase.co',
    'sb_publishable_test_key',
    httpClient: http,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tur kimliği', () {
    test('v4 UUID biçiminde ve benzersiz', () {
      final ids = {for (var i = 0; i < 200; i++) newClientRoundId()};
      expect(ids, hasLength(200));
      for (final id in ids) {
        expect(isClientRoundId(id), isTrue, reason: id);
        expect(id[14], '4');
      }
      expect(isClientRoundId('x'), isFalse);
      expect(isClientRoundId(null), isFalse);
    });
  });

  group('SupabaseZanKurdRepository.awardSoloQuizCoins', () {
    test('kimlik p_client_round_id olarak sunucuya gider', () async {
      final recorder = _RpcRecorder();
      final id = newClientRoundId();
      final claim = await _repo(recorder).awardSoloQuizCoins(
        score: 200,
        correctCount: 7,
        bestStreak: 3,
        totalQuestions: 10,
        clientRoundId: id,
      );
      expect(claim.amount, 12);
      expect(recorder.bodies, hasLength(1));
      expect(recorder.bodies.single['p_client_round_id'], id);
      expect(recorder.bodies.single['p_correct_count'], 7);
    });

    test('aynı kimlik her denemede aynen gider', () async {
      final recorder = _RpcRecorder();
      final repo = _repo(recorder);
      final id = newClientRoundId();
      for (var i = 0; i < 2; i++) {
        await repo.awardSoloQuizCoins(
          score: 200,
          correctCount: 7,
          bestStreak: 3,
          totalQuestions: 10,
          clientRoundId: id,
        );
      }
      expect(recorder.bodies.map((b) => b['p_client_round_id']), [id, id]);
    });

    test('kimlik sonraki sıradan çağrıya sızmaz', () async {
      final recorder = _RpcRecorder();
      final repo = _repo(recorder);
      await repo.awardSoloQuizCoins(
        score: 1,
        correctCount: 1,
        bestStreak: 1,
        totalQuestions: 5,
        clientRoundId: newClientRoundId(),
      );
      await repo.awardQuizCoins(
        score: 1,
        correctCount: 1,
        bestStreak: 1,
        totalQuestions: 5,
      );
      expect(recorder.bodies.last.containsKey('p_client_round_id'), isFalse);
    });

    test('göç yokken (PGRST202) eski 3 argümanlı imzaya düşer', () async {
      final recorder = _RpcRecorder(missingNewSignature: true);
      final claim = await _repo(recorder).awardSoloQuizCoins(
        score: 1,
        correctCount: 4,
        bestStreak: 2,
        totalQuestions: 5,
        clientRoundId: newClientRoundId(),
      );
      expect(claim.amount, 12);
      expect(recorder.bodies, hasLength(2));
      expect(recorder.bodies.first.containsKey('p_client_round_id'), isTrue);
      expect(recorder.bodies.last.containsKey('p_client_round_id'), isFalse);
    });

    test(
      'geçersiz kimlik eski imzayla gider (sunucu uuid reddetmesin)',
      () async {
        final recorder = _RpcRecorder();
        await _repo(recorder).awardSoloQuizCoins(
          score: 1,
          correctCount: 1,
          bestStreak: 1,
          totalQuestions: 5,
          clientRoundId: 'not-a-uuid',
        );
        expect(
          recorder.bodies.single.containsKey('p_client_round_id'),
          isFalse,
        );
      },
    );
  });

  group('SyncManager kuyruğu kimliği korur', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SyncManager.resetForTesting();
    });
    tearDown(() => SyncManager.resetForTesting());

    test('kuyruktaki solo ödül aynı kimlikle yeniden gönderilir', () async {
      final repo = _RecordingRepo();
      final sync = await SyncManager.initialize(
        repo,
        connectivityMonitor: _OnlineMonitor(),
      );
      final id = newClientRoundId();

      await sync.queueQuizReward(
        score: 100,
        correctCount: 5,
        bestStreak: 2,
        totalQuestions: 10,
        clientRoundId: id,
      );
      await sync.sync();
      await sync.sync();

      expect(repo.soloIds, [id]);
      expect(repo.roomCalls, 0);
    });

    test('kuyruk kaydı kimliği JSON olarak taşır, miktar taşımaz', () async {
      final repo = _RecordingRepo();
      final sync = await SyncManager.initialize(
        repo,
        connectivityMonitor: _OnlineMonitor(online: false),
      );
      final id = newClientRoundId();
      await sync.queueQuizReward(
        score: 100,
        correctCount: 5,
        bestStreak: 2,
        totalQuestions: 10,
        clientRoundId: id,
      );
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs
          .getKeys()
          .map(prefs.getString)
          .whereType<String>()
          .join();
      expect(raw, contains('"clientRoundId":"$id"'));
      expect(raw.contains('"amount"'), isFalse);
    });

    test('quiz ekranı ilk deneme ve kuyruk için AYNI kimliği kullanır', () {
      final source = File(
        'lib/src/screens/quiz_screen.dart',
      ).readAsStringSync();
      expect(
        RegExp(
          r'final String _soloRoundId = newClientRoundId\(\);',
        ).allMatches(source).length,
        1,
        reason: 'kimlik durum nesnesinde BİR kez üretilir',
      );
      expect(
        RegExp(r'clientRoundId:[^\n]*_soloRoundId').allMatches(source).length,
        greaterThanOrEqualTo(2),
        reason: 'hem ilk talep hem kuyruk kaydı aynı alanı kullanmalı',
      );
    });

    test('oda turu kimliksizdir ve awardQuizCoins ile gider', () async {
      final repo = _RecordingRepo();
      final sync = await SyncManager.initialize(
        repo,
        connectivityMonitor: _OnlineMonitor(),
      );
      await sync.queueQuizReward(
        score: 100,
        correctCount: 5,
        bestStreak: 2,
        totalQuestions: 10,
        roomId: 'room-1',
        clientRoundId: newClientRoundId(),
      );
      await sync.sync();
      await sync.sync();
      expect(repo.roomCalls, 1);
      expect(repo.soloIds, isEmpty);
    });

    test(
      'kimliksiz eski solo kayda kalıcı kimlik yazılır, tekil yoldan gider',
      () async {
        // Kimlik alanı eklenmeden önce kuyruğa girmiş kayıt.
        SharedPreferences.setMockInitialValues({
          'zankurd.syncQueue.v2.solo-user': jsonEncode([
            {
              'queueId': 'legacy-1',
              'type': 'sync_quiz_reward',
              'score': 100,
              'correctCount': 5,
              'bestStreak': 2,
              'totalQuestions': 10,
              'roomId': null,
              'playerId': 'solo-user',
              'timestamp': 1,
              'retries': 0,
            },
          ]),
        });
        // İlk yanıt kaybolur: kayıt kuyrukta kalır, kimliği diskte durur.
        final repo = _RecordingRepo()..failSolo = true;
        final sync = await SyncManager.initialize(
          repo,
          connectivityMonitor: _OnlineMonitor(),
        );

        await sync.sync();
        expect(repo.soloIds, isNotEmpty);
        final id = repo.soloIds.first;
        expect(isClientRoundId(id), isTrue);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('zankurd.syncQueue.v2.solo-user'),
          contains('"clientRoundId":"$id"'),
        );

        repo.failSolo = false;
        await sync.sync();
        expect(repo.soloIds.toSet(), {id});
        expect(repo.plainSoloCalls, 0);
        expect(sync.pendingCount, 0);
      },
    );
  });

  group('SyncManager kalıcı coin reddi', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SyncManager.resetForTesting();
    });
    tearDown(() => SyncManager.resetForTesting());

    test(
      'yetersiz bakiye sessizce düşmez, başarısız listesine girer',
      () async {
        final repo = _RecordingRepo()
          ..spendResult = const DurableCoinSpend(
            success: false,
            retryable: false,
          );
        final sync = await SyncManager.initialize(
          repo,
          connectivityMonitor: _OnlineMonitor(),
        );
        await sync.queueCoinSpend(
          amount: 500,
          reason: 'purchase_avatar_frame_gold',
          idempotencyKey: 'purchase_avatar_frame_gold_1',
        );
        await sync.sync();

        expect(repo.spendKeys, ['purchase_avatar_frame_gold_1']);
        expect(sync.pendingCount, 0);
        expect(sync.failedCount, 1);
      },
    );
  });
}

class _OnlineMonitor implements ConnectivityMonitor {
  _OnlineMonitor({this.online = true});

  final bool online;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    online ? ConnectivityResult.wifi : ConnectivityResult.none,
  ];
}

class _RecordingRepo extends SupabaseZanKurdRepository {
  _RecordingRepo()
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _RpcRecorder(),
        ),
      );

  final soloIds = <String>[];
  final spendKeys = <String>[];
  int roomCalls = 0;
  int plainSoloCalls = 0;
  bool failSolo = false;
  DurableCoinSpend spendResult = const DurableCoinSpend(
    success: true,
    retryable: false,
  );

  @override
  String? get currentUserId => 'solo-user';

  @override
  Future<QuizRewardClaim> awardSoloQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    required String clientRoundId,
  }) async {
    soloIds.add(clientRoundId);
    if (failSolo) throw StateError('yanıt kayboldu');
    return (amount: 9, dailyCapReached: false);
  }

  @override
  Future<DurableCoinSpend> spendCoinsDurable(
    int amount,
    String reason,
    String idempotencyKey,
  ) async {
    spendKeys.add(idempotencyKey);
    return spendResult;
  }

  @override
  Future<QuizRewardClaim> awardQuizCoins({
    required int score,
    required int correctCount,
    required int bestStreak,
    required int totalQuestions,
    GameRoom? room,
  }) async {
    if (room != null) {
      roomCalls++;
    } else {
      plainSoloCalls++;
    }
    return (amount: 9, dailyCapReached: false);
  }
}
