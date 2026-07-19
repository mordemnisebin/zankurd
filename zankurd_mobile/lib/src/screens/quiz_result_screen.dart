import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:provider/provider.dart';

import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../data/sync_manager.dart';
import '../utils/error_reporter.dart';
import '../l10n/lang.dart';
import '../providers/child_safety_provider.dart';
import '../models/achievement.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../data/daily_mission_store.dart';
import '../data/xp_store.dart';
import '../services/review_service.dart';
import '../utils/result_sharer.dart';
import '../widgets/mission_toast.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/player_avatar.dart';
import 'leaderboard_screen.dart';
import 'review_screen.dart';

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    required this.repository,
    required this.room,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.bestStreak,
    required this.answerRecords,
    required this.coinsAwarded,
    this.opponents = const [],
    this.practice = false,
    this.dailyQuiz = false,
    this.contestId,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int bestStreak;
  final List<AnswerRecord> answerRecords;
  final int coinsAwarded;

  /// Bot yarışındaki rakiplerin son durumu; boşsa panel gizlenir.
  final List<Player> opponents;
  final bool practice;
  final bool dailyQuiz;
  final String? contestId;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  ZanKurdRepository get repository => widget.repository;
  GameRoom get room => widget.room;
  int get score => widget.score;
  int get correctCount => widget.correctCount;
  int get wrongCount => widget.wrongCount;
  int get totalQuestions => widget.totalQuestions;
  int get bestStreak => widget.bestStreak;
  List<AnswerRecord> get answerRecords => widget.answerRecords;
  int get coinsAwarded => widget.coinsAwarded;
  List<Player> get opponents => widget.opponents;
  bool get practice => widget.practice;
  bool get dailyQuiz => widget.dailyQuiz;

  int _dailyStreak = 0;
  List<Achievement> _newAchievements = const [];
  Map<String, MasteryLevel> _promotions = const {};
  int _earnedXP = 0;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _recordProgress();
    repository.logAnalyticsEvent('quiz_complete', {
      'category': widget.room.category,
      'correct_count': widget.correctCount,
      'total_questions': widget.totalQuestions,
      'score': widget.score,
    });
    if (widget.contestId != null) {
      _claimContestReward();
    }
  }

  Future<void> _claimContestReward() async {
    final id = widget.contestId;
    if (id == null) return;
    try {
      // Skoru kaydet + sıralama; sonra rank/badge ödülünü talep et.
      await repository.submitContestEntry(
        contestId: id,
        correctCount: widget.correctCount,
      );
      await repository.claimContestReward(id);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz_result_save');
      // Silent fail — reward already claimed or network issue
    }
  }

  Future<void> _recordProgress() async {
    final streakStore = await StreakStore.load();
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final isNewDay = streakStore.lastDay != todayKey;

    final streak = await streakStore.recordPlay();
    final mistakeStore = await MistakeStore.load();
    final achievementStore = await AchievementStore.load();
    final newAchievements = await achievementStore.recordQuizResult(
      category: room.category,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      bestStreak: bestStreak,
      dailyStreak: streak,
      userScore: score,
      practice: practice,
      dailyQuiz: dailyQuiz,
      remainingMistakes: mistakeStore.count,
      opponents: opponents,
    );

    final masteryStore = await MasteryStore.load();
    final correctByCategory = <String, int>{};
    for (final record in answerRecords) {
      if (record.isCorrect) {
        correctByCategory[record.category] =
            (correctByCategory[record.category] ?? 0) + 1;
      }
    }
    final promotions = <String, MasteryLevel>{};
    for (final entry in correctByCategory.entries) {
      final newLevel = await masteryStore.addCorrect(entry.key, entry.value);
      if (newLevel != null) promotions[entry.key] = newLevel;
    }

    final missionStore = await DailyMissionStore.load();
    final completedMissions = await missionStore.reportQuizCompleted(
      correctAnswers: correctCount,
      category: room.category,
      streakAlive: streak > 0,
    );
    for (final mission in completedMissions) {
      await repository.claimMissionReward(
        missionKey: mission.missionKey,
        fallbackReward: mission.coinReward,
      );
    }

    // XP ve Seviye Hesaplaması
    int earnedXP = (correctCount * 10) + 50;
    if (isNewDay) earnedXP += 30;
    earnedXP += completedMissions.length * 100;
    earnedXP += promotions.length * 200;

    final xpStore = await XPStore.load();
    final leveledUp = await xpStore.addXP(earnedXP);
    try {
      await repository.updateProfileXP(xpStore.totalXP);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz_result_reward');
      SyncManager.instance.queueXP(xpStore.totalXP);
    }

    // Doğru anda (yeterli quiz + iyi skor) bir kez mağaza değerlendirmesi iste.
    final accuracyPercent = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();
    final reviewService = await ReviewService.load();
    await reviewService.recordQuizCompletion(accuracyPercent: accuracyPercent);

    if (mounted) {
      setState(() {
        _dailyStreak = streak;
        _newAchievements = newAchievements;
        _promotions = promotions;
        _earnedXP = earnedXP;
        _showConfetti = promotions.isNotEmpty;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        for (final mission in completedMissions) {
          MissionToast.show(context, mission);
        }
        if (leveledUp) {
          _showLevelUpDialog(context, xpStore.currentLevel);
        }
      });
    }
  }

  void _showLevelUpDialog(BuildContext context, int newLevel) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Level Up',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final curve = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curve,
          child: FadeTransition(
            opacity: anim1,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.surfaceHiColor(context),
                      AppTheme.surfaceColor(context),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.gold, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.gold.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.military_tech_rounded,
                        color: AppTheme.gold,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.isKu ? 'Asta Te Bilind Bû!' : 'Seviyen Yükseldi!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.isKu
                          ? 'Te asteke nû bi dest xist!'
                          : 'Yeni bir seviyeye ulaştın!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gold,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.gold.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        context.isKu ? 'Ast $newLevel' : 'Seviye $newLevel',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.gold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pop({'score': score, 'correct': correctCount}),
                        child: Text(
                          context.isKu ? 'Berdawam bike' : 'Devam Et',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unanswered = (totalQuestions - correctCount - wrongCount).clamp(
      0,
      totalQuestions,
    );
    final wrongRecords = answerRecords
        .where((record) => !record.isCorrect && !record.isUnanswered)
        .toList(growable: false);
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    final is1v1 = opponents.length == 1;
    bool isWinner = false;
    bool isDraw = false;
    if (is1v1) {
      final opp = opponents.first;
      if (score > opp.score) {
        isWinner = true;
      } else if (score == opp.score) {
        isDraw = true;
      }
    }

    final headerGradient = is1v1
        ? (isWinner
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.correct.withValues(alpha: 0.92),
                    const Color(0xFF1B5E20),
                  ],
                )
              : isDraw
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.surfaceHiColor(context),
                    AppTheme.surfaceColor(context),
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.wrong.withValues(alpha: 0.88),
                    const Color(0xFF7F1D1D),
                  ],
                ))
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.isLight(context)
                ? [
                    Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.12),
                      AppTheme.brandGreen,
                    ),
                    Color.alphaBlend(
                      Colors.black.withValues(alpha: 0.18),
                      AppTheme.brandGreenDeep,
                    ),
                  ]
                : [AppTheme.brandGreen, AppTheme.brandGreenDeep],
          );

    final borderColor = is1v1
        ? (isWinner
              ? AppTheme.correct.withValues(alpha: 0.55)
              : isDraw
              ? AppTheme.borderColor(context)
              : AppTheme.wrong.withValues(alpha: 0.55))
        : AppTheme.brandGreen.withValues(alpha: 0.45);

    final headerTitle = is1v1
        ? (isWinner
              ? context.s('Tu bi ser ketî!', 'Kazandın!')
              : isDraw
              ? context.s('Beramberî!', 'Berabere!')
              : context.s('Te winda kir...', 'Kaybettin...'))
        : context.s('Pêşbirk qediya', 'Yarış tamamlandı');

    final headerIcon = is1v1
        ? (isWinner
              ? Icons.emoji_events_outlined
              : isDraw
              ? Icons.balance_outlined
              : Icons.sentiment_very_dissatisfied_outlined)
        : Icons.flag_outlined;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.isLight(context)
                  ? AppTheme.lightTextPrimary.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppTheme.isLight(context)
                    ? AppTheme.lightTextPrimary.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: BackButton(
              color: AppTheme.isLight(context)
                  ? AppTheme.lightTextPrimary
                  : Colors.white,
            ),
          ),
        ),
        title: Text(context.s('Encam', 'Sonuç')),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.lg,
                ),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    child: Container(
                      key: const ValueKey('result-score-header'),
                      decoration: BoxDecoration(
                        gradient: headerGradient,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                        border: Border.all(color: borderColor, width: 1.2),
                        boxShadow: AppTheme.glowShadow(
                          is1v1
                              ? (isWinner
                                    ? AppTheme.correct
                                    : isDraw
                                    ? AppTheme.borderColor(context)
                                    : AppTheme.wrong)
                              : AppTheme.brandGreen,
                          intensity: 0.18,
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.md,
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: KilimPatternPainter(
                                  drawPattern: true,
                                  color: Colors.white,
                                  opacity: 0.05,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: -8,
                            top: -38,
                            child: IgnorePointer(
                              child: Icon(
                                headerIcon,
                                size: 130,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Header row: icon + title
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.xs,
                                      ),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.22,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      headerIcon,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      headerTitle.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.caption.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.82,
                                        ),
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              // Mockup 8: doğruluk kademesine göre 3 yıldız
                              // (bu boşluk daha önce boştu, net yükseklik
                              // artışı yok — ~450px doğrulanmış).
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < 3; i++)
                                    Icon(
                                      Icons.star_rounded,
                                      size: i == 1 ? 30 : 22,
                                      color:
                                          i <
                                              (accuracy >= 80
                                                  ? 3
                                                  : accuracy >= 50
                                                  ? 2
                                                  : 1)
                                          ? AppTheme.gold
                                          : Colors.white.withValues(
                                              alpha: 0.18,
                                            ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              // BIG score number
                              Text(
                                '$score',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display.copyWith(
                                  color: Colors.white,
                                  fontSize: 72,
                                  height: 0.95,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              // Category & accuracy on one line
                              Text(
                                '${CategoryNames.localized(room.category, context.isKu)} · %$accuracy ${context.s('rastbûn', 'doğruluk')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.72),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              // Reward chips row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (coinsAwarded > 0)
                                    _ResultRewardChip(
                                      icon: Icons.monetization_on_outlined,
                                      label: '+${coinsAwarded}c',
                                      color: AppTheme.gold,
                                    ),
                                  if (coinsAwarded > 0 && _earnedXP > 0)
                                    const SizedBox(width: 8),
                                  if (_earnedXP > 0)
                                    _ResultRewardChip(
                                      icon: Icons.bolt_rounded,
                                      label: '+$_earnedXP XP',
                                      // Koyu sonuç kartında accent (koyu
                                      // yeşil) soluk kalıyordu; kazanım
                                      // hissi için aydınlatılmış yeşil.
                                      color: Color.alphaBlend(
                                        Colors.white.withValues(alpha: 0.35),
                                        AppTheme.accent,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Divider(
                                color: Colors.white.withValues(alpha: 0.15),
                                height: 1,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              // Compact stats row: ✅ 17  ❌ 3  ⏱ 0  🔥 12
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.xs,
                                children: [
                                  _StatPill(
                                    icon: Icons.check_circle,
                                    value: '$correctCount',
                                    label: context.s('Rast', 'Doğru'),
                                    color: AppTheme.correct,
                                  ),
                                  _StatPill(
                                    icon: Icons.cancel,
                                    value: '$wrongCount',
                                    label: context.s('Şaş', 'Yanlış'),
                                    color: AppTheme.wrong,
                                  ),
                                  if (unanswered > 0)
                                    _StatPill(
                                      icon: Icons.hourglass_empty_rounded,
                                      value: '$unanswered',
                                      label: context.s('Vala', 'Boş'),
                                      color: AppTheme.textMutedColor(context),
                                    ),
                                  if (bestStreak > 0)
                                    _StatPill(
                                      icon: Icons.local_fire_department_rounded,
                                      value: '$bestStreak',
                                      label: context.s('Serî', 'Seri'),
                                      color: AppTheme.gold,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (opponents.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _RaceStandings(
                      userScore: score,
                      userIdentity: room.players.isNotEmpty
                          ? room.players.first
                          : null,
                      opponents: opponents,
                    ),
                  ],
                  if (_newAchievements.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _AchievementUnlocks(achievements: _newAchievements),
                  ],
                  if (_promotions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _MasteryPromotions(promotions: _promotions),
                  ],
                  if (_dailyStreak > 0) ...[
                    const SizedBox(height: 16),
                    AppPanel(
                      cardType: CardType.secondary,
                      color: AppTheme.surfaceHiColor(context),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: AppTheme.accent,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.s(
                                    'Seriya rojane: $_dailyStreak roj',
                                    'Günlük seri: $_dailyStreak gün',
                                  ),
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.s(
                                    'Sibê jî bilîze û seriyê bidomîne!',
                                    'Yarın da oyna, seriyi sürdür!',
                                  ),
                                  style: TextStyle(
                                    color: AppTheme.textMutedColor(context),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // ── Actions ──────────────────────────────────────────
                  const SizedBox(height: 12),
                  // Dalga 5: tek baskın CTA. Birincil dolgulu "Dîsa bilîze";
                  // Vekolîn + Parve bike yanında ikon buton, değerlendirme
                  // text butona indi.
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            key: const ValueKey('result-play-again-button'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.brandGreen,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              if (room.id != null) {
                                Navigator.of(context).pop();
                              } else {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            },
                            icon: const Icon(Icons.replay_rounded, size: 20),
                            label: Text(
                              context.s('Dîsa bilîze', 'Tekrar oyna'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        key: const ValueKey('result-review-button'),
                        tooltip: context.s('Vekolîn', 'İncele'),
                        onPressed: answerRecords.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                AppRoute.to(
                                  ReviewScreen(
                                    records: answerRecords,
                                    room: room,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.fact_check_outlined),
                      ),
                      if (context
                          .watch<ChildSafetyProvider>()
                          .allowExternalShare)
                        IconButton(
                          key: const ValueKey('result-share-button'),
                          tooltip: context.s('Parve bike', 'Paylaş'),
                          onPressed: () => ResultSharer.share(
                            context,
                            isKu: context.isKu,
                            score: score,
                            correctCount: correctCount,
                            totalQuestions: totalQuestions,
                            bestStreak: bestStreak,
                            category: room.category,
                          ),
                          icon: const Icon(Icons.share_rounded),
                        ),
                    ],
                  ),
                  // İkincil CTA: mağaza değerlendirmesi text buton.
                  Center(
                    child: TextButton.icon(
                      key: const ValueKey('result-rate-button'),
                      onPressed: () => InAppReview.instance.openStoreListing(),
                      icon: const Icon(Icons.star_rounded, size: 18),
                      label: Text(
                        context.s('Binirxîne', 'Değerlendir'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Subtle secondary links
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        TextButton(
                          key: const ValueKey('result-home-button'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          child: Text(
                            context.s('Sereke', 'Ana Sayfa'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '·',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(
                              context,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: wrongRecords.isEmpty
                              ? null
                              : () => Navigator.of(context).push(
                                  AppRoute.to(
                                    ReviewScreen(
                                      records: wrongRecords,
                                      room: room,
                                    ),
                                  ),
                                ),
                          child: Text(
                            context.s(
                              'Tenê şaşiyan bibîne',
                              'Sadece yanlışlar',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          '·',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(
                              context,
                            ).withValues(alpha: 0.4),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              AppRoute.to(
                                LeaderboardScreen(repository: repository),
                              ),
                            );
                          },
                          child: Text(
                            context.s('Tabloya pêşderçûnê', 'Liderlik tablosu'),
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMutedColor(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showConfetti)
                ConfettiOverlay(
                  onFinished: () {
                    setState(() {
                      _showConfetti = false;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RaceStandings extends StatelessWidget {
  const _RaceStandings({
    required this.userScore,
    required this.opponents,
    this.userIdentity,
  });

  final int userScore;
  final Player? userIdentity;
  final List<Player> opponents;

  @override
  Widget build(BuildContext context) {
    // Repository katmanı yerel oyuncu için sabit 'Tu' adı üretir (i18n
    // katmanı değil); bu widget "sen" etiketini burada, gösterim anında
    // yerelleştirir — userIdentity'nin ham adı görmezden gelinir.
    final user = (userIdentity ?? const Player(name: '', score: 0, state: ''))
        .copyWith(
          name: context.s('Tu', 'Sen'),
          score: userScore,
          state: 'Player',
        );
    final standings = [user, ...opponents]
      ..sort((a, b) => b.score.compareTo(a.score));
    final userRank =
        standings.indexWhere((player) => player.state == 'Player') + 1;
    final leader = standings.first;
    final title = context.s(
      'Bi reqîban re beramber bike',
      'Rakiplerle Karşılaştırma',
    );
    final summary = leader.state == 'Player'
        ? context.s(
            'Te yarış di rêza $userRank. de qedand.',
            'Yarışı $userRank. sırada tamamladın.',
          )
        : context.s(
            '${leader.name} pêşî qediya; tu di rêza $userRank. de yî.',
            '${leader.name} önde bitirdi; sen $userRank. sıradasın.',
          );

    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.groups_2_outlined, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          for (var i = 0; i < standings.length; i++)
            _RaceStandingRow(rank: i + 1, player: standings[i]),
        ],
      ),
    );
  }
}

class _AchievementUnlocks extends StatelessWidget {
  const _AchievementUnlocks({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    // Sonuç kartından görsel olarak daha zayıf: tam gold gradyan blok yerine
    // sade yüzey + ince gold sınır; rozet bilgisi ikincil kalır.
    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppTheme.gold,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.s('Rozeta Nû', 'Yeni Rozet'),
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      achievement.icon,
                      color: AppTheme.gold,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title(context.isKu),
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          achievement.description(context.isKu),
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MasteryPromotions extends StatelessWidget {
  const _MasteryPromotions({required this.promotions});

  final Map<String, MasteryLevel> promotions;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Column(
      children: [
        for (final entry in promotions.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppPanel(
              color: entry.value.badgeColor.withValues(alpha: 0.12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: entry.value.badgeColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      entry.value.icon,
                      color: entry.value.badgeColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku
                              ? '${CategoryNames.localized(entry.key, true)} — ${entry.value.titleKu}!'
                              : '${CategoryNames.localized(entry.key, false)} — ${entry.value.titleTr}!',
                          style: TextStyle(
                            color: entry.value.badgeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          ku ? 'Unvana nû stend!' : 'Yeni unvan kazandın!',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ResultRewardChip extends StatelessWidget {
  const _ResultRewardChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _RaceStandingRow extends StatelessWidget {
  const _RaceStandingRow({required this.rank, required this.player});

  final int rank;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final isUser = player.state == 'Player';
    final color = isUser ? AppTheme.accent : AppTheme.gold;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isUser
            ? AppTheme.accent.withValues(alpha: 0.12)
            : AppTheme.bgOf(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16), // AppRadius.lg
        border: Border.all(
          color: isUser
              ? AppTheme.accent.withValues(alpha: 0.45)
              : AppTheme.borderColor(context).withValues(alpha: 0.5),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$rank',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          PlayerAvatar(
            radius: 15,
            photoUrl: player.avatarUrl,
            iconId: player.avatarIcon,
            colorHex: player.avatarColor,
            frameId: player.avatarFrame,
            displayName: player.name,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (player.streak > 0) ...[
            Icon(
              Icons.local_fire_department_outlined,
              color: AppTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              '${player.streak}',
              style: TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '${player.score}',
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact inline stat: icon + value + label, used in the score hero.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          value,
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textMutedColor(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// Analytics tracking will be added in next iteration
// AnalyticsTracker.trackQuizComplete(category, correctCount, totalQuestions);
