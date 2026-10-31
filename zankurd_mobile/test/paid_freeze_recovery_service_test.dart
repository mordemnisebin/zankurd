import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/paid_freeze_intent.dart';
import 'package:zankurd_mobile/src/data/progress_sync.dart';
import 'package:zankurd_mobile/src/data/progress_snapshot.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/services/paid_freeze_recovery_service.dart';

const _intent = PaidFreezeIntent(
  ownerId: 'owner-a',
  roundId: 'solo:round-1',
  idempotencyKey: 'zankurd.quiz_result_progress_receipt.owner-a:solo:round-1',
  playedDay: '2026-06-15',
  previousLastDay: '2026-06-12',
  targetCurrent: 8,
  targetBest: 10,
  playedDays: ['2026-06-12', '2026-06-15'],
  frozenDays: ['2026-06-13', '2026-06-14'],
);

class _Repository extends MockZanKurdRepository {
  String owner = 'owner-a';
  bool loseFirstReply = false;
  Completer<StreakFreezeChargeResult>? gate;
  final keys = <String>[];
  final entered = Completer<void>();
  final charged = <String>{};
  @override
  String? get currentUserId => owner;
  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
    bool allowLegacyFallback = true,
  }) async {
    expect(allowLegacyFallback, isFalse);
    keys.add(idempotencyKey);
    if (!entered.isCompleted) entered.complete();
    if (gate != null) return gate!.future;
    final first = charged.add(idempotencyKey);
    return StreakFreezeChargeResult(
      outcome: loseFirstReply && keys.length == 1
          ? StreakFreezeChargeOutcome.failed
          : first
          ? StreakFreezeChargeOutcome.charged
          : StreakFreezeChargeOutcome.alreadyCharged,
      idempotent: true,
    );
  }
}

class _RejectAck extends QuizResultProgressReceiptStore {
  _RejectAck(super.preferences);
  @override
  Future<void> write({
    required String userId,
    required String roomId,
    required QuizResultReceipt receipt,
  }) {
    if (receipt.stage == QuizResultReceiptStage.freezeApplied) {
      throw StateError('injected acknowledgement persistence failure');
    }
    return super.write(userId: userId, roomId: roomId, receipt: receipt);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String k(String logical) =>
      LocalProgressScope.physicalFor('owner-a', logical);
  Future<SharedPreferences> seed({
    String lastDay = '2026-06-12',
    int current = 7,
  }) async {
    SharedPreferences.resetStatic();
    StreakStore.resetInstance();
    LocalProgressScope.bind('owner-a');
    SharedPreferences.setMockInitialValues({
      k('zankurd.streak.current'): current,
      k('zankurd.streak.best'): 10,
      k('zankurd.streak.lastDay'): lastDay,
      k('zankurd.streak.freeze'): 1,
      k('zankurd.xp.total'): 77,
      _intent.idempotencyKey: jsonEncode(
        const QuizResultReceipt(
          stage: QuizResultReceiptStage.freezeChargePending,
          freezeRequested: true,
          paidFreezeIntent: _intent,
        ).toJson(),
      ),
    });
    return SharedPreferences.getInstance();
  }

  tearDown(() {
    LocalProgressScope.debugReset();
    StreakStore.resetInstance();
  });

  test(
    'cold start resolves lost charge on original day without replaying XP',
    () async {
      final prefs = await seed();
      final repository = _Repository()..loseFirstReply = true;
      expect(
        await PaidFreezeRecoveryService.recoverPendingSolo(repository),
        isTrue,
      );
      expect(repository.keys, [_intent.idempotencyKey, _intent.idempotencyKey]);
      expect(repository.charged, hasLength(1));
      expect(prefs.getString(k('zankurd.streak.lastDay')), '2026-06-15');
      expect(prefs.getInt(k('zankurd.streak.current')), 8);
      expect(prefs.getInt(k('zankurd.streak.freeze')), 1);
      expect(prefs.getInt(k('zankurd.xp.total')), 77);
      expect(
        await PaidFreezeRecoveryService.recoverPendingSolo(repository),
        isFalse,
      );
    },
  );

  test(
    'ack failure can replay old intent without extending newer streak',
    () async {
      final prefs = await seed();
      final repository = _Repository();
      expect(
        await PaidFreezeRecoveryService.reconcile(
          repository: repository,
          intent: _intent,
          receipts: _RejectAck(prefs),
        ),
        PaidFreezeReconciliation.pending,
      );
      final store = await StreakStore.load();
      expect(await store.recordPlay(now: DateTime(2026, 6, 16)), 9);
      StreakStore.resetInstance();
      expect(
        await PaidFreezeRecoveryService.recoverPendingSolo(repository),
        isTrue,
      );
      expect(repository.charged, hasLength(1));
      expect(prefs.getInt(k('zankurd.streak.current')), 9);
      expect(prefs.getString(k('zankurd.streak.lastDay')), '2026-06-16');
    },
  );

  test('historical intent preserves newer state and merges calendar', () async {
    final prefs = await seed(lastDay: '2026-06-20', current: 3);
    expect(
      await PaidFreezeRecoveryService.recoverPendingSolo(_Repository()),
      isTrue,
    );
    expect(prefs.getInt(k('zankurd.streak.current')), 3);
    expect(prefs.getString(k('zankurd.streak.lastDay')), '2026-06-20');
    expect(
      prefs.getStringList(k('zankurd.streak.frozenDays')),
      contains('2026-06-14'),
    );
    expect(prefs.getInt(k('zankurd.streak.freeze')), 1);
  });

  test(
    'concurrent snapshot write and recovery retain newer snapshot',
    () async {
      final prefs = await seed();
      final repository = _Repository();
      await Future.wait([
        PaidFreezeRecoveryService.recoverPendingSolo(repository),
        LocalProgressSnapshot.write(
          prefs,
          const ProgressSnapshot(
            xp: 77,
            streak: SnapshotStreak(
              current: 4,
              best: 11,
              lastDay: '2026-06-20',
              freeze: 1,
              playedDays: {'2026-06-20'},
            ),
          ),
        ),
      ]);
      expect(prefs.getInt(k('zankurd.streak.current')), 4);
      expect(prefs.getString(k('zankurd.streak.lastDay')), '2026-06-20');
      expect(prefs.getInt(k('zankurd.streak.best')), 11);
      expect(
        prefs.getStringList(k('zankurd.streak.playedDays')),
        contains('2026-06-15'),
      );
    },
  );

  test(
    'owner switch while claiming never retries or writes the new account',
    () async {
      final prefs = await seed();
      final gate = Completer<StreakFreezeChargeResult>();
      final repository = _Repository()..gate = gate;
      final pending = PaidFreezeRecoveryService.recoverPendingSolo(repository);
      await repository.entered.future;
      repository.owner = 'owner-b';
      LocalProgressScope.bind('owner-b');
      gate.complete(
        const StreakFreezeChargeResult(
          outcome: StreakFreezeChargeOutcome.charged,
          idempotent: true,
        ),
      );
      expect(await pending, isFalse);
      expect(repository.keys, hasLength(1));
      expect(
        prefs.getInt(
          LocalProgressScope.physicalFor('owner-b', 'zankurd.streak.current'),
        ),
        isNull,
      );
      expect(
        QuizResultReceipt.decode(
          prefs.getString(_intent.idempotencyKey),
        )!.stage,
        QuizResultReceiptStage.freezeChargePending,
      );
    },
  );

  test(
    'v2, legacy stage and malformed v3 never trigger automatic charges',
    () async {
      final prefs = await seed();
      final repository = _Repository();
      for (final raw in [
        '{"v":2,"stage":"freezeChargePending","freeze":true}',
        '{"v":2,"stage":"freezeApplying","freeze":true}',
        '{"v":3,"stage":"freezeChargePending","freeze":true,"paidFreezeIntent":{}}',
      ]) {
        await prefs.setString(_intent.idempotencyKey, raw);
        expect(
          await PaidFreezeRecoveryService.recoverPendingSolo(repository),
          isFalse,
        );
      }
      expect(repository.keys, isEmpty);
    },
  );
}
