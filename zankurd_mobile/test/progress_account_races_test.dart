import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/badge_service.dart';
import 'package:zankurd_mobile/src/data/lesson_completion_store.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/local_progress_write_lock.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';

class _Remote implements ProgressRemote {
  _Remote(this.snapshot);
  final ProgressSnapshot snapshot;
  Map<String, dynamic>? saved;
  @override
  Future<RemoteProgress?> fetch() async =>
      RemoteProgress(snapshot: snapshot.toJson());
  @override
  Future<bool> save(
    Map<String, dynamic> snapshot, {
    DateTime? expectedUpdatedAt,
  }) async {
    saved = snapshot;
    return true;
  }
}

class _LessonHttp extends http.BaseClient {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    entered.complete();
    await release.future;
    return http.StreamedResponse(
      Stream.value(utf8.encode('[{"lesson_id":"a-private"}]')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

class _LessonRepository extends SupabaseZanKurdRepository {
  _LessonRepository(super.client);
  String owner = 'a';
  @override
  String? get currentUserId => owner;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/shared_preferences');
  setUp(() {
    SharedPreferences.resetStatic();
    final storage = <String, Object>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getAll') {
            return Map<String, Object>.of(storage);
          }
          final args = Map<String, Object?>.from(call.arguments as Map);
          final key = args['key'] as String;
          if (call.method == 'remove') {
            storage.remove(key);
          } else {
            storage[key] = args['value']!;
          }
          return true;
        });
    LocalProgressScope.debugReset();
    LocalProgressScope.bind('a');
    XPStore.resetInstance();
    BadgeService.resetInstance();
  });
  tearDown(() {
    ProgressSyncService.unbind();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    SharedPreferences.resetStatic();
    LocalProgressScope.debugReset();
    XPStore.resetInstance();
    BadgeService.resetInstance();
  });

  test(
    'G1 eski görüntü XP/rozeti ezerdi; yalnız ağ öncesi yarış sınandığı için kilit kuyruğu sessiz kaldı',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final xp = await XPStore.load();
      final badges = await BadgeService.load();
      await xp.addXP(100);
      final entered = Completer<void>();
      final release = Completer<void>();
      final held = LocalProgressWriteLock.run('a', () async {
        entered.complete();
        await release.future;
      });
      await entered.future;
      final earned = xp.addXP(50);
      final badge = badges.evaluatePerfectGame(5, 5);
      final remote = _Remote(
        const ProgressSnapshot(xp: 120, badges: {'speed_demon'}),
      );
      final service = ProgressSyncService(
        remote: remote,
        userId: 'a',
        preferences: prefs,
      );
      final sync = service.syncNow();
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait([held, earned, badge, sync]);
      final result = LocalProgressSnapshot.read(prefs);
      expect(result.xp, 150);
      expect(result.badges, {'perfect_game', 'speed_demon'});
      expect(ProgressSnapshot.tryParse(remote.saved!)?.xp, 150);
      expect(ProgressSnapshot.tryParse(remote.saved!)?.badges, result.badges);
    },
  );

  test(
    'G1 bekleyen eski snapshot yeni XP ve rozeti silerdi; yazım anındaki yerel durum sınanmıyordu',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final xp = await XPStore.load();
      final badge = await BadgeService.load();
      await xp.addXP(150);
      await badge.evaluatePerfectGame(5, 5);
      await LocalProgressSnapshot.write(
        prefs,
        const ProgressSnapshot(xp: 100, badges: {'speed_demon'}),
      );
      expect(LocalProgressSnapshot.read(prefs).xp, 150);
      expect(LocalProgressSnapshot.read(prefs).badges, {
        'perfect_game',
        'speed_demon',
      });
    },
  );

  test(
    'G4 reddedilen rozet yazımı başarı sayılırdı; yalnız exception test edildiği için sessizdi',
    () async {
      final storage = <String, Object>{};
      var fail = true;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getAll') return Map<String, Object>.of(storage);
            final args = Map<String, Object?>.from(call.arguments as Map);
            final key = args['key'] as String;
            if (fail && key.endsWith('badges.unlocked')) {
              fail = false;
              return false;
            }
            storage[key] = args['value']!;
            return true;
          });
      final badge = await BadgeService.load();
      await expectLater(badge.evaluatePerfectGame(5, 5), throwsStateError);
      expect(badge.isUnlocked('perfect_game'), isFalse);
      expect(await badge.evaluatePerfectGame(5, 5), isTrue);
      expect(storage['flutter.zankurd.scope.a.zankurd.badges.unlocked'], [
        'perfect_game',
      ]);
    },
  );

  for (final switchAccount in [false, true]) {
    test(
      'G${switchAccount ? 2 : 1} platform yazımı await yarışı; yalnız kilit öncesi denetlendiği için sessizdi ($switchAccount)',
      () async {
        SharedPreferences.resetStatic();
        final entered = Completer<void>();
        final release = Completer<void>();
        final storage = <String, Object>{
          'flutter.zankurd.scope.a.zankurd.xp.total': 100,
        };
        var blocked = false;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'getAll') {
                return Map<String, Object>.of(storage);
              }
              final args = Map<String, Object?>.from(call.arguments as Map);
              final key = args['key'] as String;
              if (!blocked && key.endsWith('xp.total')) {
                blocked = true;
                entered.complete();
                await release.future;
              }
              if (call.method == 'remove') {
                storage.remove(key);
              } else {
                storage[key] = args['value']!;
              }
              return true;
            });
        final prefs = await SharedPreferences.getInstance();
        final xp = await XPStore.load();
        final badge = await BadgeService.load();
        final remote = _Remote(
          const ProgressSnapshot(xp: 120, badges: {'speed_demon'}),
        );
        final service = ProgressSyncService(
          remote: remote,
          userId: 'a',
          preferences: prefs,
        );
        final sync = service.syncNow();
        await entered.future;
        Future<bool>? earned;
        Future<bool>? awarded;
        if (switchAccount) {
          LocalProgressScope.bind('b');
          service.close();
        } else {
          earned = xp.addXP(50);
          awarded = badge.evaluatePerfectGame(5, 5);
        }
        release.complete();
        await sync;
        if (switchAccount) {
          expect(remote.saved, isNull);
          expect(
            storage.keys.where((key) => key.contains('.scope.b.')),
            isEmpty,
          );
        } else {
          await earned;
          await awarded;
          expect(storage['flutter.zankurd.scope.a.zankurd.xp.total'], 170);
          expect(LocalProgressSnapshot.read(prefs).badges, {
            'speed_demon',
            'perfect_game',
          });
        }
      },
    );
  }

  test(
    'G2 V2 geri düşüşünde hesap değişirse eski payload B yetkisi alırdı; yalnız başarılı RPC sınanmıştı',
    () async {
      var signups = 0;
      final sentOwners = <String>[];
      late SupabaseClient client;
      final expiry =
          DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch ~/
          1000;
      String segment(Object value) =>
          base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      final tokens = <String, String>{};
      final transport = MockClient((request) async {
        if (request.url.path.endsWith('/signup')) {
          final owner = ++signups == 1 ? 'a' : 'b';
          final token =
              '${segment({'alg': 'HS256'})}.${segment({'sub': owner, 'exp': expiry})}.test';
          tokens[owner] = token;
          return http.Response(
            jsonEncode({
              'access_token': token,
              'refresh_token': 'fixture-$owner',
              'token_type': 'bearer',
              'expires_in': 86400,
              'expires_at': expiry,
              'user': {
                'id': owner,
                'aud': 'authenticated',
                'created_at': '2026-11-01T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        sentOwners.add(request.headers['authorization']!);
        // v3 (2026-11-10) henüz yok sayılır: v2 geri düşüşü yarışı sınanır.
        if (request.url.path.endsWith('/save_my_progress_v3')) {
          return http.Response(
            jsonEncode({'code': 'PGRST202', 'message': 'function missing'}),
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/save_my_progress_v2')) {
          await client.auth.signInAnonymously();
          // Local scope deliberately lags auth: remote adapter must check auth too.
          return http.Response(
            jsonEncode({'code': 'PGRST202', 'message': 'function missing'}),
            404,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          '{}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_test',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      addTearDown(client.dispose);
      await client.auth.signInAnonymously();
      final remote = SupabaseProgressRemote(client, expectedUserId: 'a');
      await expectLater(
        remote.save(const ProgressSnapshot(xp: 100).toJson()),
        throwsStateError,
      );
      expect(client.auth.currentUser?.id, 'b');
      // v3 isteği (yok) + v2 isteği (yok) A ile gitti; legacy B ile gitmedi.
      expect(sentOwners, ['Bearer ${tokens['a']}', 'Bearer ${tokens['a']}']);
    },
  );

  for (final returnToA in [false, true]) {
    test(
      'G3 geciken ders yanıtı başka oturuma sızardı; hesap değişmeyen HTTP testleri sessizdi (A-B-A=$returnToA)',
      () async {
        final transport = _LessonHttp();
        final client = SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test',
          httpClient: transport,
        );
        addTearDown(client.dispose);
        final repository = _LessonRepository(client);
        await LessonCompletionStore.cacheServer({'b-only'}, owner: 'b');
        final request = repository.loadCompletedLessonIds();
        await transport.entered.future;
        repository.owner = 'b';
        LocalProgressScope.bind('b');
        if (returnToA) {
          repository.owner = 'a';
          LocalProgressScope.bind('a');
        }
        transport.release.complete();
        expect(await request, isEmpty);
        expect(await LessonCompletionStore.loadLocal(owner: 'b'), {'b-only'});
        expect(await LessonCompletionStore.loadLocal(owner: 'a'), isEmpty);
      },
    );
  }

  test(
    'G4 bekleyen günlük hesap taşınırken genel alana yazardı; yalnız tamamlanmış taşıma sınandığı için sessizdi',
    () async {
      LocalProgressScope.debugReset();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('zankurd.xp.total', 100);
      await prefs.setString(
        'zankurd.xp.total.resultJournal.round',
        jsonEncode({
          'values': {'zankurd.xp.total': 150},
          'result': {'leveledUp': false},
          'done': false,
        }),
      );
      expect(
        await LocalProgressScope.migrateLegacy(prefs, incomingUserId: 'a'),
        isTrue,
      );
      LocalProgressScope.bind('a');
      final xp = await XPStore.load();
      expect(xp.totalXP, 150);
      await xp.addXP(50, operationId: 'round');
      expect(xp.totalXP, 150);
      expect(prefs.containsKey('zankurd.xp.total'), isFalse);
    },
  );

  test(
    'G3 explicit owner genel anahtara düşerdi; kapsam kapanırken yazım sınanmamıştı',
    () async {
      LocalProgressScope.debugReset();
      await LessonCompletionStore.cacheServer({'a-only'}, owner: 'a');
      expect(await LessonCompletionStore.loadLocal(owner: 'a'), {'a-only'});
      expect(await LessonCompletionStore.loadLocal(owner: 'b'), isEmpty);
      expect(await LessonCompletionStore.loadLocal(), isEmpty);
    },
  );
}
