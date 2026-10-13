import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sync_manager.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../services/quiz_reward_settlement_service.dart';
import '../services/room_result_presentation.dart';
import '../theme/app_icons.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/roj_mascot.dart';
import '../widgets/sahne/sahne.dart';
import 'quiz_result_screen.dart';

const Duration _roomResultRecoveryTimeout = Duration(seconds: 15);

class RoomResultRecoveryScreen extends StatefulWidget {
  const RoomResultRecoveryScreen({
    required this.repository,
    required this.snapshot,
    required this.expectedUserId,
    this.rewardSettlementService,
    super.key,
  });

  final ZanKurdRepository repository;
  final RoomResultSnapshot snapshot;
  final String expectedUserId;
  final QuizRewardSettlementService? rewardSettlementService;

  @override
  State<RoomResultRecoveryScreen> createState() =>
      _RoomResultRecoveryScreenState();
}

class _RoomResultRecoveryScreenState extends State<RoomResultRecoveryScreen> {
  bool _loading = true;
  bool _ownerMismatch = false;
  int _attempt = 0;
  RoomResultPresentation? _cachedPresentation;
  List<QuizQuestion>? _cachedQuestions;
  QuizRewardSettlement? _cachedSettlement;
  Future<QuizRewardSettlement>? _settlementInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_recover());
    });
  }

  String get _expectedUserId => widget.expectedUserId.trim();

  bool get _hasValidDeliveryContext {
    final currentUserId = widget.repository.currentUserId?.trim();
    final roomId = widget.snapshot.room.id?.trim();
    if (currentUserId == null || currentUserId != _expectedUserId) {
      return false;
    }
    try {
      validateRoomResultDeliveryContext(
        widget.snapshot,
        expectedUserId: _expectedUserId,
        expectedRoomId: roomId ?? '',
      );
      return true;
    } on FormatException {
      return false;
    }
  }

  Future<void> _recover() async {
    final attempt = ++_attempt;
    if (!_canContinue(attempt)) return;

    try {
      var presentation = _cachedPresentation;
      var questions = _cachedQuestions;
      if (presentation == null || questions == null) {
        final loadedQuestions = await widget.repository
            .loadRoomQuestions(widget.snapshot.room)
            .timeout(_roomResultRecoveryTimeout);
        if (!mounted || !_canContinue(attempt)) return;

        questions = List<QuizQuestion>.unmodifiable(loadedQuestions);
        presentation = buildRoomResultPresentation(
          widget.snapshot,
          questions,
          isKu: context.isKu,
        );
        _cachedQuestions = questions;
        _cachedPresentation = presentation;
        if (!_canContinue(attempt)) return;
      }

      var settlement = _cachedSettlement;
      if (settlement == null) {
        final reusedPendingSettlement = _settlementInFlight != null;
        final pendingSettlement = _settlementInFlight ??=
            (widget.rewardSettlementService ?? _defaultSettlementService())
                .settle(
                  room: presentation.room,
                  practice: false,
                  score: presentation.score,
                  correctCount: presentation.correctCount,
                  bestStreak: presentation.bestStreak,
                  totalQuestions: presentation.totalQuestions,
                );
        try {
          settlement = await pendingSettlement.timeout(
            _roomResultRecoveryTimeout,
          );
        } on TimeoutException {
          _showFailure(attempt);
          return;
        } catch (_) {
          if (identical(_settlementInFlight, pendingSettlement)) {
            _settlementInFlight = null;
          }
          rethrow;
        }
        if (!mounted || attempt != _attempt) return;
        if (identical(_settlementInFlight, pendingSettlement)) {
          _settlementInFlight = null;
        }
        if (settlement.isDurable) {
          _cachedSettlement = settlement;
        } else if (reusedPendingSettlement) {
          if (!_canContinue(attempt)) return;
          unawaited(_recover());
          return;
        }
      }
      if (!_canContinue(attempt)) return;
      _openResult(presentation, settlement, questions);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room result recovery');
      _showFailure(attempt);
    }
  }

  void _openResult(
    RoomResultPresentation presentation,
    QuizRewardSettlement settlement,
    List<QuizQuestion> questions,
  ) {
    unawaited(
      Navigator.of(context).pushReplacement(
        AppRoute.to(
          QuizResultScreen(
            repository: widget.repository,
            room: presentation.room,
            score: presentation.score,
            correctCount: presentation.correctCount,
            wrongCount: presentation.wrongCount,
            totalQuestions: presentation.totalQuestions,
            bestStreak: presentation.bestStreak,
            answerRecords: presentation.answerRecords,
            coinsAwarded: settlement.coinsAwarded,
            sourceQuestions: questions,
            opponents: presentation.opponents,
            rewardQueued: settlement.state == QuizRewardSettlementState.queued,
            resultOwnerUserId: _expectedUserId,
            rewardSettlementState: settlement.state,
          ),
        ),
      ),
    );
  }

  QuizRewardSettlementService _defaultSettlementService() {
    final sync = SyncManager.maybeInstance;
    return QuizRewardSettlementService(
      repository: widget.repository,
      queueReward: sync == null
          ? null
          : ({
              required score,
              required correctCount,
              required bestStreak,
              required totalQuestions,
              required roomId,
            }) async {
              await sync.queueQuizReward(
                score: score,
                correctCount: correctCount,
                bestStreak: bestStreak,
                totalQuestions: totalQuestions,
                roomId: roomId,
              );
            },
    );
  }

  bool _canContinue(int attempt) {
    if (!mounted || attempt != _attempt) return false;
    if (ModalRoute.of(context)?.isCurrent != true) {
      _showFailure(attempt);
      return false;
    }
    if (_hasValidDeliveryContext) return true;
    _showFailure(attempt, ownerMismatch: true);
    return false;
  }

  void _showFailure(int attempt, {bool ownerMismatch = false}) {
    if (!mounted || attempt != _attempt) return;
    setState(() {
      _loading = false;
      _ownerMismatch = ownerMismatch;
    });
  }

  void _retry() {
    setState(() {
      _loading = true;
      _ownerMismatch = false;
    });
    unawaited(_recover());
  }

  void _leaveRecovery() {
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    // 2026-09-29 Şahnê: B iskeleti (açılan sayfa). Geri düğmesi bu ekranda
    // "yığını boşalt" demektir (`_leaveRecovery`); başlık çubukta, içerik
    // yalnız durumu anlatır. Yükleme ve hata aynı ortalı düzende durur:
    // logo işareti plakası + köşede durum karosu (şekil de ayrıştırır) +
    // tek cümle + tek birincil eylem.
    final t = SahneTokens.of(context);
    final Widget body;
    if (_loading) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 44,
            child: CircularProgressIndicator(strokeWidth: 3, color: t.raceTx),
          ),
          const SizedBox(height: SahneSpace.x4),
          Text(
            context.t(K.resultRecoveryLoading),
            textAlign: TextAlign.center,
            style: SahneType.body.copyWith(color: t.tx2),
          ),
        ],
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RecoveryPlate(
            icon: _ownerMismatch ? AppIcons.shield : AppIcons.cloud,
          ),
          const SizedBox(height: SahneSpace.x4),
          Text(
            context.t(
              _ownerMismatch
                  ? K.resultRecoveryOwnerChanged
                  : K.resultRecoveryFailed,
            ),
            textAlign: TextAlign.center,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x6),
          SahneButton.primary(
            label: context.t(K.retry),
            icon: AppIcons.arrowsRotate,
            arrow: false,
            onPressed: _retry,
          ),
        ],
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveRecovery();
      },
      child: SahnePushedPage(
        title: context.t(K.resultTitle),
        backLabel: context.t(K.back),
        onBack: _leaveRecovery,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(SahneSpace.x6),
              child: Align(alignment: const Alignment(0, -0.3), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

/// Logo işareti plakası + köşede durum karosu (dekoratif).
///
/// Ortak boş/hata durumunun (`AppErrorState`) görsel dili; burada başlık
/// yok çünkü sayfa adı çubukta, durumu tek cümle anlatır.
class _RecoveryPlate extends StatelessWidget {
  const _RecoveryPlate({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: 76,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned(left: 0, top: 0, child: BrandMarkPlate()),
            Positioned(
              right: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.goldTint,
                  shape: SahneShape.withSide(
                    SahneShape.s,
                    t.bg,
                    width: SahneRing.r2,
                  ),
                ),
                child: SizedBox.square(
                  dimension: 28,
                  child: Icon(icon, size: 16, color: t.goldTx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
