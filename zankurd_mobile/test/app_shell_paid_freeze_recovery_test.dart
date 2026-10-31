import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';

import 'support/widget_test_helpers.dart';

class _RecoveryRepository extends TestMockZanKurdRepository {
  String userId = 'account-a';
  bool failCharge = false;
  final charges = <({String owner, String key, bool legacy})>[];

  @override
  String get currentUserId => userId;

  @override
  Future<StreakFreezeChargeResult> spendStreakFreeze({
    required String idempotencyKey,
    bool allowLegacyFallback = true,
  }) async {
    charges.add((
      owner: userId,
      key: idempotencyKey,
      legacy: allowLegacyFallback,
    ));
    return StreakFreezeChargeResult(
      outcome: failCharge
          ? StreakFreezeChargeOutcome.failed
          : StreakFreezeChargeOutcome.alreadyCharged,
      idempotent: true,
    );
  }
}

class _RecoveryAuth extends FakeAuthProvider {
  void accountChanged() => notifyListeners();
}

const _round = 'solo:historical-freeze';

String _receiptKey(String owner) =>
    'zankurd.quiz_result_progress_receipt.$owner:$_round';

String _streakKey(String owner, String field) =>
    LocalProgressScope.physicalFor(owner, 'zankurd.streak.$field');

Future<void> _seedPending(SharedPreferences preferences, String owner) async {
  // Gerçek v3 disk biçimi: uygulama eski bir ödemenin yanıtından önce kapanmış.
  await preferences.setString(
    _receiptKey(owner),
    jsonEncode({
      'v': 3,
      'stage': 'freezeChargePending',
      'freeze': true,
      'paidFreezeIntent': {
        'ownerId': owner,
        'roundId': _round,
        'idempotencyKey': _receiptKey(owner),
        'playedDay': '2026-06-15',
        'previousLastDay': '2026-06-12',
        'targetCurrent': 8,
        'targetBest': 8,
        'playedDays': ['2026-06-12', '2026-06-15'],
        'frozenDays': ['2026-06-13', '2026-06-14'],
      },
    }),
  );
  await preferences.setInt(_streakKey(owner, 'current'), 7);
  await preferences.setInt(_streakKey(owner, 'best'), 7);
  await preferences.setString(_streakKey(owner, 'lastDay'), '2026-06-12');
  await preferences.setStringList(_streakKey(owner, 'playedDays'), [
    '2026-06-12',
  ]);
  await preferences.setBool('zankurd.profileName.completed.$owner', true);
}

QuizResultReceiptStage? _stage(SharedPreferences preferences, String owner) =>
    QuizResultReceipt.decode(preferences.getString(_receiptKey(owner)))?.stage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _RecoveryRepository repository;
  late _RecoveryAuth auth;
  late SharedPreferences preferences;

  setUp(() async {
    freshMockRepository();
    LocalProgressScope.debugReset();
    QuizResultProgressReceiptStore.debugResetInFlight();
    preferences = await SharedPreferences.getInstance();
    repository = _RecoveryRepository();
    auth = _RecoveryAuth();
  });

  tearDown(() {
    StreakStore.resetInstance();
    LocalProgressScope.debugReset();
    QuizResultProgressReceiptStore.debugResetInFlight();
  });

  Future<void> pumpShell(WidgetTester tester) async {
    await tester.pumpWidget(
      testShell(
        authProvider: auth,
        reducedMotion: true,
        child: AppShell(
          repository: repository,
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('açılış eski ücretli günü kurtarır, bugünü oynanmış saymaz', (
    tester,
  ) async {
    await _seedPending(preferences, 'account-a');
    LocalProgressScope.bind('account-a');

    await pumpShell(tester);

    expect(
      _stage(preferences, 'account-a'),
      QuizResultReceiptStage.freezeApplied,
    );
    expect(preferences.getInt(_streakKey('account-a', 'current')), 8);
    expect(
      preferences.getString(_streakKey('account-a', 'lastDay')),
      '2026-06-15',
    );
    expect(preferences.getStringList(_streakKey('account-a', 'playedDays')), [
      '2026-06-12',
      '2026-06-15',
    ]);
    expect(preferences.getStringList(_streakKey('account-a', 'frozenDays')), [
      '2026-06-13',
      '2026-06-14',
    ]);
    expect(
      (await StreakStore.load()).playedToday(now: DateTime(2026, 6, 20)),
      isFalse,
    );
    expect(repository.charges.single.key, _receiptKey('account-a'));
    expect(repository.charges.single.legacy, isFalse);
  });

  testWidgets(
    'ön plana dönüş başarısız kalan makbuzu aynı anahtarla kurtarır',
    (tester) async {
      await _seedPending(preferences, 'account-a');
      LocalProgressScope.bind('account-a');
      repository.failCharge = true;
      await pumpShell(tester);

      expect(
        _stage(preferences, 'account-a'),
        QuizResultReceiptStage.freezeChargePending,
      );
      expect(preferences.getInt(_streakKey('account-a', 'current')), 7);
      final startupAttempts = repository.charges.length;
      expect(startupAttempts, greaterThan(0));
      repository.failCharge = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(
        _stage(preferences, 'account-a'),
        QuizResultReceiptStage.freezeApplied,
      );
      expect(preferences.getInt(_streakKey('account-a', 'current')), 8);
      expect(repository.charges.length, greaterThan(startupAttempts));
      expect(
        repository.charges.every(
          (call) => call.key == _receiptKey('account-a') && !call.legacy,
        ),
        isTrue,
      );
    },
  );

  testWidgets('kapsam uyuşmazlığı ödeme yapmaz; aynı kabuk yeni sahibi tarar', (
    tester,
  ) async {
    await _seedPending(preferences, 'account-a');
    await _seedPending(preferences, 'account-b');
    LocalProgressScope.bind('account-b');
    await pumpShell(tester);
    final shellState = tester.state(find.byType(AppShell));

    expect(repository.charges, isEmpty);
    expect(
      _stage(preferences, 'account-a'),
      QuizResultReceiptStage.freezeChargePending,
    );
    expect(
      _stage(preferences, 'account-b'),
      QuizResultReceiptStage.freezeChargePending,
    );

    repository.userId = 'account-b';
    auth.accountChanged();
    await tester.pumpAndSettle();

    expect(tester.state(find.byType(AppShell)), same(shellState));
    expect(
      _stage(preferences, 'account-b'),
      QuizResultReceiptStage.freezeApplied,
    );
    expect(
      _stage(preferences, 'account-a'),
      QuizResultReceiptStage.freezeChargePending,
    );
    expect(preferences.getInt(_streakKey('account-a', 'current')), 7);
    expect(preferences.getInt(_streakKey('account-b', 'current')), 8);
    expect(repository.charges.single.owner, 'account-b');
    expect(repository.charges.single.key, _receiptKey('account-b'));
  });
}
