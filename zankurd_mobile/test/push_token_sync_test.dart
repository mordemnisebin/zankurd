import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/push_token_sync.dart';
import 'package:zankurd_mobile/src/providers/repository_holder.dart';

class _FixedTokenSource implements PushTokenSource {
  const _FixedTokenSource(this.token);
  final String? token;
  @override
  Future<String?> currentToken() async => token;
}

class _NoSessionRepository extends MockZanKurdRepository {
  @override
  String? get currentUserId => null;
}

class _DeferredTokenSource implements PushTokenSource {
  final result = Completer<String?>();
  @override
  Future<String?> currentToken() => result.future;
}

class _RefreshingTokenSource
    implements PushTokenSource, PushTokenRefreshSource {
  final refreshes = StreamController<String>.broadcast();
  String token = 'first';
  Future<String?> Function()? read;
  int reads = 0;

  @override
  Future<String?> currentToken() {
    reads++;
    return read?.call() ?? Future.value(token);
  }

  @override
  Stream<String> get onTokenRefresh => refreshes.stream;
}

class _MutableSessionRepository extends MockZanKurdRepository {
  String? userId = 'first-user';
  @override
  String? get currentUserId => userId;
}

class _HeldWriteRepository extends MockZanKurdRepository {
  final writeStarted = Completer<void>();
  final finishWrite = Completer<void>();
  final operations = <String>[];

  @override
  Future<void> setFcmToken(String token) async {
    operations.add('write-start');
    writeStarted.complete();
    await finishWrite.future;
    await super.setFcmToken(token);
    operations.add('write-finish');
  }
}

void main() {
  test(
    'yazı beş saniyede bitmezse çıkış başlamaz; sonra tekrar denenebilir',
    () {
      fakeAsync((clock) {
        final repo = _HeldWriteRepository();
        final sync = PushTokenSync(
          source: const _FixedTokenSource('pending-token'),
          repository: repo,
        );
        unawaited(sync.sync());
        clock.flushMicrotasks();
        expect(repo.operations, ['write-start']);
        Object? failure;
        var cleared = false;
        unawaited(
          PushTokenSync.suspendRegistrationsDuring(() async {
            cleared = true;
          }).then<void>(
            (_) {},
            onError: (Object error, StackTrace _) {
              failure = error;
            },
          ),
        );
        clock.elapse(const Duration(seconds: 5));
        expect(failure, isA<TimeoutException>());
        expect(cleared, isFalse);
        repo.finishWrite.complete();
        clock.flushMicrotasks();
        final recoveredRepo = MockZanKurdRepository();
        unawaited(
          PushTokenSync(
            source: const _FixedTokenSource('fresh-token'),
            repository: recoveredRepo,
          ).sync(),
        );
        clock.flushMicrotasks();
        expect(recoveredRepo.lastFcmToken, 'fresh-token');
        unawaited(
          PushTokenSync.suspendRegistrationsDuring(() async {
            cleared = true;
          }),
        );
        clock.flushMicrotasks();
        expect(cleared, isTrue);
      });
    },
  );

  test('çıkış başlamış RPC tamamlanmadan token temizlemez', () async {
    final repo = _HeldWriteRepository();
    final sync = PushTokenSync(
      source: const _FixedTokenSource('old-token'),
      repository: repo,
    );
    final pending = sync.sync();
    await repo.writeStarted.future;
    final logout = PushTokenSync.suspendRegistrationsDuring(() async {
      repo.operations.add('clear');
      await sync.sync();
      repo.operations.add('signed-out');
    });
    await Future<void>.delayed(Duration.zero);
    expect(repo.operations, ['write-start']);
    repo.finishWrite.complete();
    await pending;
    await logout;
    expect(repo.operations, [
      'write-start',
      'write-finish',
      'clear',
      'signed-out',
    ]);
  });

  test(
    'çıkış tamamlandıktan sonra dönen eski token yeniden yazılmaz',
    () async {
      final source = _DeferredTokenSource();
      final repo = MockZanKurdRepository();
      final pending = PushTokenSync(source: source, repository: repo).sync();
      await PushTokenSync.suspendRegistrationsDuring(() async {});
      source.result.complete('old-token');
      await pending;
      expect(repo.lastFcmToken, isNull);
    },
  );

  test('daha eski token okuması yeni kaydı geri alamaz', () async {
    final source = _DeferredTokenSource();
    final repo = MockZanKurdRepository();
    final old = PushTokenSync(source: source, repository: repo).sync();
    await PushTokenSync(
      source: const _FixedTokenSource('new-token'),
      repository: repo,
    ).sync();
    source.result.complete('old-token');
    await old;
    expect(repo.lastFcmToken, 'new-token');
  });

  test(
    'token beklerken hesap değişirse eski işlem yeni hesaba yazmaz',
    () async {
      final source = _DeferredTokenSource();
      final repo = _MutableSessionRepository();
      final pending = PushTokenSync(source: source, repository: repo).sync();
      repo.userId = 'second-user';
      source.result.complete('old-token');
      await pending;
      expect(repo.lastFcmToken, isNull);
    },
  );

  test(
    'token beklerken depo değişirse eski işlem yeni depoya yazmaz',
    () async {
      final source = _DeferredTokenSource();
      final first = MockZanKurdRepository();
      final next = MockZanKurdRepository();
      final holder = RepositoryHolder(first);
      final pending = PushTokenSync(
        source: source,
        repository: first,
        repositoryHolder: holder,
      ).sync();
      holder.switchTo(next);
      source.result.complete('old-token');
      await pending;
      expect(first.lastFcmToken, isNull);
      expect(next.lastFcmToken, isNull);
      holder.dispose();
    },
  );

  for (final unavailable in ['null', 'throw', 'pending']) {
    test(
      'yenileme payloadı getToken $unavailable olsa da kaydedilir',
      () async {
        final source = _RefreshingTokenSource();
        source.read = switch (unavailable) {
          'null' => () async => null,
          'throw' => () async => throw StateError('APNs not ready'),
          _ => () => Completer<String?>().future,
        };
        final repo = MockZanKurdRepository();
        final subscription = PushTokenSync(
          source: source,
          repository: repo,
        ).watchTokenRefresh();
        source.refreshes.add('  event-token  ');
        await Future<void>.delayed(Duration.zero);
        expect(repo.lastFcmToken, 'event-token');
        expect(source.reads, 0);
        await subscription?.cancel();
        await source.refreshes.close();
      },
    );
  }

  test(
    'yenileme eski bekleyen token okumasının sonucunu geçersiz kılar',
    () async {
      final oldToken = Completer<String?>();
      final source = _RefreshingTokenSource()..read = () => oldToken.future;
      final repo = MockZanKurdRepository();
      final sync = PushTokenSync(source: source, repository: repo);
      final subscription = sync.watchTokenRefresh();
      final pending = sync.sync();
      source.refreshes.add('new-token');
      await Future<void>.delayed(Duration.zero);
      expect(repo.lastFcmToken, 'new-token');
      oldToken.complete('old-token');
      await pending;
      expect(repo.lastFcmToken, 'new-token');
      await subscription?.cancel();
      await source.refreshes.close();
    },
  );

  test('çıkış bariyeri sırasında gelen yenileme kaydedilmez', () async {
    final source = _RefreshingTokenSource();
    final repo = MockZanKurdRepository();
    final subscription = PushTokenSync(
      source: source,
      repository: repo,
    ).watchTokenRefresh();
    await PushTokenSync.suspendRegistrationsDuring(() async {
      source.refreshes.add('during-signout');
      await Future<void>.delayed(Duration.zero);
    });
    expect(repo.lastFcmToken, isNull);
    await subscription?.cancel();
    await source.refreshes.close();
  });

  test(
    'yazım sırasında sıraya giren yenileme hesap değişince yazılmaz',
    () async {
      final blocker = _HeldWriteRepository();
      final oldWrite = PushTokenSync(
        source: const _FixedTokenSource('blocker'),
        repository: blocker,
      ).sync();
      await blocker.writeStarted.future;
      final source = _RefreshingTokenSource();
      final repo = _MutableSessionRepository();
      final subscription = PushTokenSync(
        source: source,
        repository: repo,
      ).watchTokenRefresh();
      source.refreshes.add('first-user-token');
      await Future<void>.delayed(Duration.zero);
      repo.userId = 'second-user';
      blocker.finishWrite.complete();
      await oldWrite;
      await Future<void>.delayed(Duration.zero);
      expect(repo.lastFcmToken, isNull);
      await subscription?.cancel();
      await source.refreshes.close();
    },
  );

  for (final unavailable in ['null', 'throw', 'pending']) {
    test(
      'sonuçsuz $unavailable okuması sıradaki geçerli yenilemeyi iptal etmez',
      () async {
        final blocker = _HeldWriteRepository();
        final blockingWrite = PushTokenSync(
          source: const _FixedTokenSource('blocking-token'),
          repository: blocker,
        ).sync();
        await blocker.writeStarted.future;
        final pendingRead = Completer<String?>();
        final source = _RefreshingTokenSource();
        source.read = switch (unavailable) {
          'null' => () async => null,
          'throw' => () async => throw StateError('getToken unavailable'),
          _ => () => pendingRead.future,
        };
        final repo = MockZanKurdRepository();
        final sync = PushTokenSync(source: source, repository: repo);
        final subscription = sync.watchTokenRefresh();
        source.refreshes.add('queued-event-token');
        await Future<void>.delayed(Duration.zero);
        final laterRead = sync.sync();
        await Future<void>.delayed(Duration.zero);
        blocker.finishWrite.complete();
        await blockingWrite;
        await Future<void>.delayed(Duration.zero);
        expect(repo.lastFcmToken, 'queued-event-token');
        pendingRead.complete(null);
        await laterRead;
        await subscription?.cancel();
        await source.refreshes.close();
      },
    );
  }

  test('açık uygulamada dönen token güncel oturuma kaydedilir', () async {
    final source = _RefreshingTokenSource();
    final repo = MockZanKurdRepository();
    final sync = PushTokenSync(source: source, repository: repo);
    final subscription = sync.watchTokenRefresh();
    source.token = 'renewed-token';
    source.refreshes.add('renewed-token');
    await Future<void>.delayed(Duration.zero);
    expect(repo.lastFcmToken, 'renewed-token');
    await subscription?.cancel();
    source.token = 'after-dispose';
    source.refreshes.add('after-dispose');
    await Future<void>.delayed(Duration.zero);
    expect(repo.lastFcmToken, 'renewed-token');
    await source.refreshes.close();
  });

  test('token yenilenirken oturum yoksa sunucuya yazılmaz', () async {
    final source = _RefreshingTokenSource();
    final repo = _NoSessionRepository();
    final subscription = PushTokenSync(
      source: source,
      repository: repo,
    ).watchTokenRefresh();
    source.refreshes.add('renewed-token');
    await Future<void>.delayed(Duration.zero);
    expect(repo.lastFcmToken, isNull);
    await subscription?.cancel();
    await source.refreshes.close();
  });

  test('FCM token senkronizasyonu kullanıcıdan bildirim izni istemez', () {
    final source = File(
      'lib/src/services/firebase_push_token_source.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(contains('.requestPermission(')),
      reason:
          'AppShell token sync ilk açılışta çalışır; izin yalnız kullanıcının '
          'bildirim özelliğini açtığı bağlamsal akışta istenmeli.',
    );
    expect(source, contains('FirebaseMessaging.instance.getToken()'));
  });

  test('boş token RPC çağırmaz', () async {
    final repo = MockZanKurdRepository();
    await PushTokenSync(
      source: const _FixedTokenSource(null),
      repository: repo,
    ).sync();
    expect(repo.lastFcmToken, isNull);
  });

  test('dolu token depoya yazılır', () async {
    final repo = MockZanKurdRepository();
    await PushTokenSync(
      source: const _FixedTokenSource('  device-token  '),
      repository: repo,
    ).sync();
    expect(repo.lastFcmToken, 'device-token');
  });

  test('debug no-token nedenini bildirir', () async {
    final debugLines = <String>[];
    await PushTokenSync(
      source: const _FixedTokenSource(null),
      repository: MockZanKurdRepository(),
      debugLog: debugLines.add,
    ).sync();

    expect(debugLines, contains(contains('no token')));
  });

  test('oturum yoksa token RPC çağırmadan nedeni bildirir', () async {
    final debugLines = <String>[];
    final repo = _NoSessionRepository();
    await PushTokenSync(
      source: const _FixedTokenSource('device-token'),
      repository: repo,
      debugLog: debugLines.add,
    ).sync();

    expect(repo.lastFcmToken, isNull);
    expect(debugLines, contains(contains('no session')));
  });
}
