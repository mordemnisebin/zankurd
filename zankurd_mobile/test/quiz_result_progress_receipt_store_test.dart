import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('ardisik cagrilarda yerel etki yalniz bir kez calisir', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);
    var actionCount = 0;

    final first = await store.runOnce(
      userId: 'user-1',
      roomId: 'room-1',
      action: () async {
        actionCount++;
      },
    );
    final second = await store.runOnce(
      userId: 'user-1',
      roomId: 'room-1',
      action: () async {
        actionCount++;
      },
    );

    expect(first, QuizResultProgressReceiptOutcome.executed);
    expect(second, QuizResultProgressReceiptOutcome.skippedCompleted);
    expect(actionCount, 1);
  });

  test('eszamanli cagrilar ayni Future ile tek action paylasir', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);
    final actionStarted = Completer<void>();
    final finishAction = Completer<void>();
    var actionCount = 0;

    final first = store.runOnce(
      userId: 'user-concurrent',
      roomId: 'room-concurrent',
      action: () async {
        actionCount++;
        actionStarted.complete();
        await finishAction.future;
      },
    );
    await actionStarted.future;
    final second = store.runOnce(
      userId: 'user-concurrent',
      roomId: 'room-concurrent',
      action: () async {
        actionCount++;
      },
    );

    expect(identical(first, second), isTrue);
    expect(actionCount, 1);

    finishAction.complete();
    expect(await first, QuizResultProgressReceiptOutcome.executed);
    expect(await second, QuizResultProgressReceiptOutcome.executed);
    expect(actionCount, 1);
  });

  test(
    'farkli kullanici veya oda anahtarlari birbirinden bagimsizdir',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final store = QuizResultProgressReceiptStore(preferences);
      var actionCount = 0;

      for (final ids in const [
        ('user-a', 'room-1'),
        ('user-b', 'room-1'),
        ('user-a', 'room-2'),
      ]) {
        expect(
          await store.runOnce(
            userId: ids.$1,
            roomId: ids.$2,
            action: () async {
              actionCount++;
            },
          ),
          QuizResultProgressReceiptOutcome.executed,
        );
      }

      expect(actionCount, 3);
    },
  );

  test('kullanici ve oda kimlikleri kirpilmis anahtar kullanir', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);
    var actionCount = 0;

    expect(
      await store.runOnce(
        userId: '  user-trim  ',
        roomId: '  room-trim  ',
        action: () async {
          actionCount++;
        },
      ),
      QuizResultProgressReceiptOutcome.executed,
    );
    expect(
      await store.runOnce(
        userId: 'user-trim',
        roomId: 'room-trim',
        action: () async {
          actionCount++;
        },
      ),
      QuizResultProgressReceiptOutcome.skippedCompleted,
    );
    expect(actionCount, 1);
  });

  test('kalici completed kaydi yeni store tarafindan atlanir', () async {
    final preferences = await SharedPreferences.getInstance();
    final firstStore = QuizResultProgressReceiptStore(preferences);
    var actionCount = 0;
    await firstStore.runOnce(
      userId: 'user-persisted',
      roomId: 'room-persisted',
      action: () async {
        actionCount++;
      },
    );

    final secondStore = QuizResultProgressReceiptStore(preferences);
    final outcome = await secondStore.runOnce(
      userId: 'user-persisted',
      roomId: 'room-persisted',
      action: () async {
        actionCount++;
      },
    );

    expect(outcome, QuizResultProgressReceiptOutcome.skippedCompleted);
    expect(actionCount, 1);
  });

  // Bu test bir zamanlar "sonraki turlar teslimatı ENGELLER" diyordu ve
  // engellemeyi bir güvenlik özelliği sayıyordu. Koruduğu asıl özellik
  // doğruydu: yarıda kalmış bir yazım TEKRARLANMAMALI, çünkü yerel depolar
  // (XP, rozet, ustalık) idempotent değil.
  //
  // Ama "tekrarlama" ile "sonsuza dek kilitle" aynı şey değil. Eski
  // sözleşme ikincisini yapıyordu: makbuz kalıcı `processing` kalıyor,
  // `acknowledgeRoomResult` hiç çağrılamıyor ve kurtarma ekranı her soğuk
  // açılışta geri geliyordu — hiçbir şeyi kurtarmadan.
  //
  // Yeni sözleşme aynı korumayı veri kaybı olmadan verir: adım yine
  // atlanır (çift XP yok), fakat akış onay aşamasına taşınır. Onay
  // sunucuda idempotenttir, bu yüzden ileri gitmek güvenlidir.
  test('action hatasi ilerlemeyi tekrarlamaz ama akisi kilitlemez', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);
    var actionCount = 0;

    await expectLater(
      store.runOnce(
        userId: 'user-action-error',
        roomId: 'room-action-error',
        action: () async {
          actionCount++;
          throw StateError('injected: action failed');
        },
      ),
      throwsStateError,
    );

    final resolved = await store.runOnce(
      userId: 'user-action-error',
      roomId: 'room-action-error',
      action: () async {
        actionCount++;
      },
    );
    final afterResolution = await store.runOnce(
      userId: 'user-action-error',
      roomId: 'room-action-error',
      action: () async {
        actionCount++;
      },
    );

    // Kesilen yazım atlandı.
    expect(resolved, QuizResultProgressReceiptOutcome.blockedProcessing);
    // Ve ileri çözüldü: ikinci tur artık "belirsiz" değil, "tamamlanmış".
    expect(afterResolution, QuizResultProgressReceiptOutcome.skippedCompleted);
    // Asıl güvence: yerel etki tam bir kez.
    expect(actionCount, 1);

    final receipt = await store.read(
      userId: 'user-action-error',
      roomId: 'room-action-error',
    );
    expect(receipt!.stage, QuizResultReceiptStage.acknowledgementPending);
  });

  test('bilinmeyen kalici durum action calistirmaz', () async {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_result_progress_receipt.user-unknown:room-unknown':
          'unknown-state',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);
    var actionCount = 0;

    await expectLater(
      store.runOnce(
        userId: 'user-unknown',
        roomId: 'room-unknown',
        action: () async {
          actionCount++;
        },
      ),
      throwsFormatException,
    );
    expect(actionCount, 0);
  });

  for (final failure in _WriteFailure.values) {
    test(
      'ilk ${failure.label} kalici yazimi action baslatmadan hata verir',
      () async {
        final harness = _PreferenceChannelHarness(
          failure: failure,
          failingWrite: 1,
        );
        harness.install();
        final preferences = await SharedPreferences.getInstance();
        final store = QuizResultProgressReceiptStore(preferences);
        var actionCount = 0;

        await expectLater(
          store.runOnce(
            userId: 'user-first-${failure.label}',
            roomId: 'room-first-${failure.label}',
            action: () async {
              actionCount++;
            },
          ),
          failure.matcher,
        );

        expect(actionCount, 0);

        harness.disableFailure();
        expect(
          await store.runOnce(
            userId: 'user-first-${failure.label}',
            roomId: 'room-first-${failure.label}',
            action: () async {
              actionCount++;
            },
          ),
          QuizResultProgressReceiptOutcome.executed,
        );
        expect(actionCount, 1);
      },
    );

    test('completed ${failure.label} yazimi tamamlanmis sayilmaz', () async {
      final harness = _PreferenceChannelHarness(
        failure: failure,
        failingWrite: 2,
        failReloadAfterWrite: true,
      );
      harness.install();
      var preferences = await SharedPreferences.getInstance();
      var store = QuizResultProgressReceiptStore(preferences);
      var actionCount = 0;

      await expectLater(
        store.runOnce(
          userId: 'user-complete-${failure.label}',
          roomId: 'room-complete-${failure.label}',
          action: () async {
            actionCount++;
          },
        ),
        failure.matcher,
      );
      expect(actionCount, 1);

      await expectLater(
        store.runOnce(
          userId: 'user-complete-${failure.label}',
          roomId: 'room-complete-${failure.label}',
          action: () async {
            actionCount++;
          },
        ),
        _reloadFailureMatcher,
      );
      expect(actionCount, 1);

      harness.disableFailure();

      expect(
        await store.runOnce(
          userId: 'user-complete-${failure.label}',
          roomId: 'room-complete-${failure.label}',
          action: () async {
            actionCount++;
          },
        ),
        QuizResultProgressReceiptOutcome.blockedProcessing,
      );
      expect(actionCount, 1);
    });

    test(
      'reload hatasi ilk ${failure.label} yazma hatasini maskelemez',
      () async {
        final harness = _PreferenceChannelHarness(
          failure: failure,
          failingWrite: 1,
          failReloadAfterWrite: true,
        );
        harness.install();
        final preferences = await SharedPreferences.getInstance();
        final store = QuizResultProgressReceiptStore(preferences);

        await expectLater(
          store.runOnce(
            userId: 'user-reload-${failure.label}',
            roomId: 'room-reload-${failure.label}',
            action: () async {},
          ),
          failure.originalErrorMatcher,
        );

        var actionCount = 0;
        await expectLater(
          store.runOnce(
            userId: 'user-reload-${failure.label}',
            roomId: 'room-reload-${failure.label}',
            action: () async {
              actionCount++;
            },
          ),
          _reloadFailureMatcher,
        );
        expect(actionCount, 0);

        harness.disableFailure();
        expect(
          await store.runOnce(
            userId: 'user-reload-${failure.label}',
            roomId: 'room-reload-${failure.label}',
            action: () async {
              actionCount++;
            },
          ),
          QuizResultProgressReceiptOutcome.executed,
        );
        expect(actionCount, 1);
      },
    );
  }

  test('bos kullanici veya oda kimligi reddedilir', () async {
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);

    expect(
      () => store.runOnce(userId: '', roomId: 'room', action: () async {}),
      throwsArgumentError,
    );
    expect(
      () => store.runOnce(userId: 'user', roomId: '   ', action: () async {}),
      throwsArgumentError,
    );
  });
}

final _reloadFailureMatcher = throwsA(
  isA<PlatformException>().having(
    (error) => error.code,
    'code',
    'reload_failed',
  ),
);

enum _WriteFailure {
  returnsFalse,
  throwsException;

  String get label => switch (this) {
    returnsFalse => 'false',
    throwsException => 'exception',
  };

  Matcher get matcher => switch (this) {
    returnsFalse => throwsStateError,
    throwsException => throwsA(isA<PlatformException>()),
  };

  Matcher get originalErrorMatcher => switch (this) {
    returnsFalse => throwsStateError,
    throwsException => throwsA(
      isA<PlatformException>().having(
        (error) => error.code,
        'code',
        'write_failed',
      ),
    ),
  };
}

class _PreferenceChannelHarness extends SharedPreferencesStorePlatform {
  _PreferenceChannelHarness({
    required this.failure,
    required this.failingWrite,
    this.failReloadAfterWrite = false,
  });

  final _WriteFailure failure;
  bool failReloadAfterWrite;
  final Map<String, Object> _persisted = {};
  int? failingWrite;
  int _writeCount = 0;

  void install() {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = this;
  }

  void disableFailure() {
    failingWrite = null;
    failReloadAfterWrite = false;
  }

  @override
  Future<Map<String, Object>> getAll() async {
    if (failReloadAfterWrite && _writeCount > 0) {
      throw PlatformException(
        code: 'reload_failed',
        message: 'injected: reload failed',
      );
    }
    return Map<String, Object>.from(_persisted);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    _writeCount++;
    if (_writeCount == failingWrite) {
      switch (failure) {
        case _WriteFailure.returnsFalse:
          return false;
        case _WriteFailure.throwsException:
          throw PlatformException(
            code: 'write_failed',
            message: 'injected: persistence failed',
          );
      }
    }
    _persisted[key] = value;
    return true;
  }

  @override
  Future<bool> remove(String key) async {
    _persisted.remove(key);
    return true;
  }

  @override
  Future<bool> clear() async {
    _persisted.clear();
    return true;
  }
}
