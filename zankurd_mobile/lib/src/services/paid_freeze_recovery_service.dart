import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_progress_scope.dart';
import '../data/offline_zankurd_repository.dart';
import '../data/paid_freeze_intent.dart';
import '../data/quiz_result_progress_receipt_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../utils/error_reporter.dart';

enum PaidFreezeReconciliation { applied, insufficient, pending }

/// İlk tahsilat, ekran tekrarı ve soğuk açılış aynı makbuzu uzlaştırır.
class PaidFreezeRecoveryService {
  PaidFreezeRecoveryService._();
  static final Map<String, Future<void>> _tails = {};
  static final Map<String, Future<bool>> _scans = {};

  static Future<bool> recoverPendingSolo(ZanKurdRepository repository) {
    final owner = repository.currentUserId?.trim() ?? '';
    if (repository is OfflineZanKurdRepository ||
        owner.isEmpty ||
        owner == LocalProgressScope.offlineUserId ||
        LocalProgressScope.activeUserId != owner) {
      return Future.value(false);
    }
    final running = _scans[owner];
    if (running != null) return running;
    late final Future<bool> tracked;
    tracked = _recoverPendingSolo(repository, owner).whenComplete(() {
      if (identical(_scans[owner], tracked)) _scans.remove(owner);
    });
    _scans[owner] = tracked;
    return tracked;
  }

  static Future<bool> _recoverPendingSolo(
    ZanKurdRepository repository,
    String owner,
  ) async {
    var applied = false;
    try {
      final receipts = QuizResultProgressReceiptStore(
        await SharedPreferences.getInstance(),
      );
      final intents = await receipts.pendingSoloIntents(owner);
      for (final intent in intents) {
        if (repository.currentUserId != owner ||
            LocalProgressScope.activeUserId != owner) {
          break;
        }
        final result = await reconcile(
          repository: repository,
          intent: intent,
          receipts: receipts,
        );
        applied = applied || result == PaidFreezeReconciliation.applied;
      }
    } catch (error, stack) {
      ErrorReporter.record(
        error,
        stack,
        reason: 'paid freeze startup recovery',
      );
    }
    return applied;
  }

  static Future<PaidFreezeReconciliation> reconcile({
    required ZanKurdRepository repository,
    required PaidFreezeIntent intent,
    required QuizResultProgressReceiptStore receipts,
    bool Function()? isCurrentRepository,
  }) async {
    final owner = intent.ownerId;
    final scope = LocalProgressScope.activeUserId;
    if (scope != owner ||
        owner == LocalProgressScope.offlineUserId ||
        repository is OfflineZanKurdRepository) {
      return PaidFreezeReconciliation.pending;
    }
    final previous = _tails[owner] ?? Future<void>.value();
    final release = Completer<void>();
    _tails[owner] = release.future;
    bool owns() =>
        repository.currentUserId == owner &&
        LocalProgressScope.activeUserId == scope &&
        (isCurrentRepository?.call() ?? true);
    await previous;
    try {
      if (!owns()) return PaidFreezeReconciliation.pending;
      final receipt = await receipts.read(
        userId: owner,
        roomId: intent.roundId,
      );
      if (!owns()) return PaidFreezeReconciliation.pending;
      final saved = receipt?.paidFreezeIntent;
      if (saved == null ||
          saved.idempotencyKey != intent.idempotencyKey ||
          saved.ownerId != owner ||
          saved.roundId != intent.roundId) {
        return PaidFreezeReconciliation.pending;
      }
      if (receipt!.stage == QuizResultReceiptStage.freezeApplied) {
        return PaidFreezeReconciliation.applied;
      }
      if (receipt.stage != QuizResultReceiptStage.freezeChargePending ||
          !receipt.freezeRequested) {
        return PaidFreezeReconciliation.pending;
      }
      for (var attempt = 0; attempt < 2; attempt++) {
        if (!owns()) return PaidFreezeReconciliation.pending;
        StreakFreezeChargeResult charge;
        try {
          charge = await repository
              .spendStreakFreeze(
                idempotencyKey: saved.idempotencyKey,
                allowLegacyFallback: false,
              )
              .timeout(const Duration(seconds: 8));
        } catch (error, stack) {
          ErrorReporter.record(error, stack, reason: 'paid freeze claim');
          continue;
        }
        if (!owns()) return PaidFreezeReconciliation.pending;
        if (charge.outcome == StreakFreezeChargeOutcome.failed) {
          if (!charge.idempotent) break;
          continue;
        }
        if (!charge.succeeded) {
          await receipts.write(
            userId: owner,
            roomId: saved.roundId,
            receipt: QuizResultReceipt(
              stage: QuizResultReceiptStage.freezeSkipped,
              paidFreezeIntent: saved,
            ),
          );
          return owns()
              ? PaidFreezeReconciliation.insufficient
              : PaidFreezeReconciliation.pending;
        }
        final store = await StreakStore.load();
        if (!owns()) return PaidFreezeReconciliation.pending;
        await store.applyPaidFreezeIntent(saved);
        if (!owns()) return PaidFreezeReconciliation.pending;
        await receipts.write(
          userId: owner,
          roomId: saved.roundId,
          receipt: QuizResultReceipt(
            stage: QuizResultReceiptStage.freezeApplied,
            paidFreezeIntent: saved,
          ),
        );
        return owns()
            ? PaidFreezeReconciliation.applied
            : PaidFreezeReconciliation.pending;
      }
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'paid freeze reconcile');
    } finally {
      release.complete();
      if (identical(_tails[owner], release.future)) _tails.remove(owner);
    }
    return PaidFreezeReconciliation.pending;
  }
}
