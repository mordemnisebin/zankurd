/// 2.1.2 W3 bekçileri: favori kuyruğu ve çevrimdışı aktarım
/// (ChatGPT Pro denetimi alan 3 #7, #8, #9, #10).
///
/// #9: tur başladıktan sonra kullanıcı kararını doğrudan yazımla değiştirirse
/// (`supersedeQueuedFavorite`) tur o kaydı YİNE gönderiyor, eski karar yenisini
/// sunucuda eziyordu (kaldırdığı favori geri geliyordu). Hata vermez: iki
/// istek de "başarılı" döner, yalnız son yazan sonuç yanlıştır.
///
/// #8: çevrimdışı favorileri kuyruğa alan yöntem hiçbir açılış akışında
/// çağrılmıyordu; kaydedilen sorular sunucuya hiç taşınmıyordu.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

class _NoNetwork extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      throw Exception('injected: ağ erişilemez');
}

class _Online implements ConnectivityMonitor {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => const [
    ConnectivityResult.wifi,
  ];
}

class _FavRepo extends SupabaseZanKurdRepository {
  _FavRepo(this.userId)
    : super(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _NoNetwork(),
        ),
      );

  String? userId;
  final calls = <(String, bool)>[];

  /// Doluysa ilk istek bu tamamlanana dek uçuşta kalır.
  Completer<void>? gate;

  @override
  String? get currentUserId => userId;

  @override
  Future<bool> toggleFavoriteQuestion(
    QuizQuestion question,
    bool favorite,
  ) async {
    calls.add((question.id, favorite));
    final wait = gate;
    if (wait != null && calls.length == 1) await wait.future;
    return favorite;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
    await SyncManager.resetForTesting();
  });

  test('tur başladıktan sonra doğrudan yazımla geçersiz kılınan favori '
      'GÖNDERİLMEZ (#9)', () async {
    final repo = _FavRepo('user-a');
    final manager = await SyncManager.initialize(
      repo,
      connectivityMonitor: _Online(),
    );
    // Kuyruğa iki farklı soru: ilk gönderim sürerken q2'nin kararı değişir.
    repo.gate = Completer<void>();
    await manager.retainFavorite(questionId: 'q1', favorite: true);
    await manager.retainFavorite(questionId: 'q2', favorite: true);
    // Kayıtlar zaten sync() tetikledi; ilk istek (q1) kapıda bekliyor.
    await pumpEventQueue();
    expect(repo.calls, [('q1', true)]);

    // Kullanıcı q2'yi kaldırır; doğrudan yazım başarılı, kuyruk kaydı düşer.
    await manager.supersedeQueuedFavorite('q2', favorite: false);
    repo.gate!.complete();
    await manager.sync();
    await pumpEventQueue();

    expect(
      repo.calls.where((c) => c.$1 == 'q2' && c.$2 == true),
      isEmpty,
      reason: 'eski `true` kararı kaldırılan favoriyi sunucuda geri getirirdi',
    );
  });

  test('gönderim SIRASINDA değişen karar yeniden bildirilir (#9)', () async {
    final repo = _FavRepo('user-a');
    final manager = await SyncManager.initialize(
      repo,
      connectivityMonitor: _Online(),
    );
    repo.gate = Completer<void>();
    await manager.retainFavorite(questionId: 'q1', favorite: true);
    await pumpEventQueue();
    expect(repo.calls, [('q1', true)]); // uçuşta

    // Kullanıcı kararı doğrudan yazımla değiştirir; uçuştaki istek eskidir.
    await manager.supersedeQueuedFavorite('q1', favorite: false);
    repo.gate!.complete();
    await manager.sync();
    await pumpEventQueue();

    expect(
      repo.calls.last,
      ('q1', false),
      reason: 'son karar uçuştaki eski isteğin ardından yeniden gönderilmeli',
    );
  });

  test('çevrimdışı favoriler hesabın kuyruğuna aktarılır (#8)', () async {
    LocalProgressScope.bind('user-a');
    final key = LocalProgressScope.physicalFor(
      'user-a',
      'zankurd.offline.favoriteQuestionIds',
    );
    SharedPreferences.setMockInitialValues({
      key: ['qa', 'qb'],
    });
    final repo = _FavRepo('user-a');
    final manager = await SyncManager.initialize(
      repo,
      connectivityMonitor: _Online(),
    );
    await manager.importScopedOfflineState();
    await manager.sync();
    await pumpEventQueue();

    expect(
      repo.calls.map((c) => c.$1).toSet(),
      containsAll(['qa', 'qb']),
      reason: 'açılışta çevrimdışı favoriler sunucuya taşınmalı',
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(key) ?? const [], isEmpty);
  });
}
