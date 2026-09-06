import 'dart:async';

import 'package:flutter/material.dart';

import '../data/sync_manager.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/room.dart';
import '../services/quiz_reward_settlement_service.dart';
import '../services/room_result_presentation.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
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
      if (presentation == null) {
        final questions = await widget.repository
            .loadRoomQuestions(widget.snapshot.room)
            .timeout(_roomResultRecoveryTimeout);
        if (!mounted || !_canContinue(attempt)) return;

        presentation = buildRoomResultPresentation(
          widget.snapshot,
          questions,
          isKu: context.isKu,
        );
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
      _openResult(presentation, settlement);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'room result recovery');
      _showFailure(attempt);
    }
  }

  void _openResult(
    RoomResultPresentation presentation,
    QuizRewardSettlement settlement,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leaveRecovery();
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            onPressed: _leaveRecovery,
            tooltip: context.t(K.back),
            icon: const Icon(AppIcons.arrowLeft),
          ),
          title: Text(context.t(K.resultTitle)),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _loading
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.t(K.resultRecoveryLoading),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _ownerMismatch ? AppIcons.shield : AppIcons.cloud,
                          size: 42,
                          color: AppTheme.gold,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          context.t(
                            _ownerMismatch
                                ? K.resultRecoveryOwnerChanged
                                : K.resultRecoveryFailed,
                          ),
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        FilledButton.icon(
                          onPressed: _retry,
                          icon: const Icon(AppIcons.arrowsRotate),
                          label: Text(context.t(K.retry)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
