import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/achievement_store.dart';
import '../data/mastery_store.dart';
import '../models/mastery_level.dart';
import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../data/sync_manager.dart';
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
    } catch (_) {
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
    } catch (_) {
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
                      context.isKu ? 'Asta Te Bilind Bû!' : 'Tebrikler!',
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
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.brandOrange, AppTheme.brandOrangeWarm],
          );

    final borderColor = is1v1
        ? (isWinner
              ? AppTheme.correct.withValues(alpha: 0.55)
              : isDraw
              ? AppTheme.borderColor(context)
              : AppTheme.wrong.withValues(alpha: 0.55))
        : AppTheme.brandOrange.withValues(alpha: 0.45);

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
                              : AppTheme.brandOrange,
                          intensity: 0.18,
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
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
                            right: -14,
                            top: -18,
                            child: IgnorePointer(
                              child: Icon(
                                headerIcon,
                                size: 112,
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.sm,
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
                                      size: 18,
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
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                '$score',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.display.copyWith(
                                  color: Colors.white,
                                  fontSize: 56,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                '${CategoryNames.localized(room.category, context.isKu)} · ${room.code}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xxs + 1,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.pill,
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Text(
                                  context.s(
                                    'Rastbûn: %$accuracy',
                                    'Doğruluk: %$accuracy',
                                  ),
                                  style: AppTypography.caption.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              if (coinsAwarded > 0) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _ResultRewardChip(
                                      icon: Icons.monetization_on_outlined,
                                      label: '+${coinsAwarded}c',
                                      color: AppTheme.gold,
                                    ),
                                    if (_earnedXP > 0) ...[
                                      const SizedBox(width: 8),
                                      _ResultRewardChip(
                                        icon: Icons.bolt_rounded,
                                        label: '+$_earnedXP XP',
                                        color: AppTheme.accent,
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md,
                                ),
                                child: Divider(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  height: 1,
                                ),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: _MetricItemCompact(
                                      icon: Icons.check_circle_outline,
                                      label: context.s('Rast', 'Doğru'),
                                      value: '$correctCount',
                                      iconColor: AppTheme.correct,
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: _MetricItemCompact(
                                      icon: Icons.cancel_outlined,
                                      label: context.s('Şaş', 'Yanlış'),
                                      value: '$wrongCount',
                                      iconColor: AppTheme.wrong,
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: _MetricItemCompact(
                                      icon: Icons.hourglass_empty_rounded,
                                      label: context.s('Vala', 'Boş'),
                                      value: '$unanswered',
                                      iconColor: AppTheme.textMutedColor(
                                        context,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    fit: FlexFit.tight,
                                    child: _MetricItemCompact(
                                      icon:
                                          Icons.local_fire_department_outlined,
                                      label: context.s('Baştirîn', 'En İyi'),
                                      value: '$bestStreak',
                                      iconColor: AppTheme.gold,
                                    ),
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
                  if (coinsAwarded > 0) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        child: Opacity(opacity: t, child: child),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(
                                left: 19,
                                top: 16,
                                right: 16,
                                bottom: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHiColor(context),
                                border: Border.all(
                                  color: AppTheme.gold.withValues(alpha: 0.18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.gold.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor(context),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.borderColor(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.monetization_on_outlined,
                                      color: AppTheme.gold,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TweenAnimationBuilder<int>(
                                          tween: IntTween(
                                            begin: 0,
                                            end: coinsAwarded,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 800,
                                          ),
                                          curve: Curves.easeOut,
                                          builder: (context, value, _) => Text(
                                            context.s(
                                              '+$value coin stendî',
                                              '+$value coin kazandın',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.textPrimaryColor(
                                                context,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          context.s(
                                            'Xelata te di malperê de tê nûkirin.',
                                            'Ödül bakiyen ana ekranda güncellenir.',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.textSubColor(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Sol gold accent çizgisi
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 3,
                                decoration: const BoxDecoration(
                                  color: AppTheme.gold,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_earnedXP > 0) ...[
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, t, child) => Transform.scale(
                        scale: 0.92 + 0.08 * t,
                        child: Opacity(opacity: t, child: child),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.only(
                                left: 19,
                                top: 16,
                                right: 16,
                                bottom: 16,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceHiColor(context),
                                border: Border.all(
                                  color: AppTheme.accent.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accent.withValues(
                                      alpha: 0.05,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppTheme.surfaceColor(context),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: AppTheme.borderColor(context),
                                        width: 1,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      color: AppTheme.accent,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        TweenAnimationBuilder<int>(
                                          tween: IntTween(
                                            begin: 0,
                                            end: _earnedXP,
                                          ),
                                          duration: const Duration(
                                            milliseconds: 800,
                                          ),
                                          curve: Curves.easeOut,
                                          builder: (context, value, _) => Text(
                                            context.s(
                                              '+$value XP bi dest xist',
                                              '+$value XP kazandın',
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: AppTheme.textPrimaryColor(
                                                context,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          context.s(
                                            'Asta te li ser profîlê tê nûkirin.',
                                            'Seviyen profil sayfasında güncellenir.',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: AppTheme.textSubColor(
                                              context,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Sol accent (pink) çizgisi
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              child: Container(
                                width: 3,
                                decoration: const BoxDecoration(
                                  color: AppTheme.brandOrange,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  AppPanel(
                    color: AppTheme.surfaceHiColor(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.s(
                            'Rêzbendiyê bişopîne',
                            'Sıralamaya devam et',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.s(
                            'Pûanên te li odeyên serhêl di tabloya pêşderçûnê de xuya dibin.',
                            'Puanların online odalarda liderlik tablosuna yansır.',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            key: const ValueKey('result-home-button'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.brandOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  16,
                                ), // AppRadius.lg
                              ),
                              elevation: 2,
                            ),
                            onPressed: () {
                              Navigator.of(
                                context,
                              ).popUntil((route) => route.isFirst);
                            },
                            icon: const Icon(Icons.replay_rounded),
                            label: Text(
                              context.s('Dîsa bilîze', 'Tekrar oyna'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: answerRecords.isEmpty
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          AppRoute.to(
                                            ReviewScreen(
                                              records: answerRecords,
                                              room: room,
                                            ),
                                          ),
                                        );
                                      },
                                icon: const Icon(Icons.fact_check_outlined),
                                label: Text(
                                  context.s(
                                    'Bersivan Bibîne',
                                    'Cevapları İncele',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),
                            // Çocuk modu: dış paylaşım butonu gizlenir.
                            if (context
                                .watch<ChildSafetyProvider>()
                                .allowExternalShare) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
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
                                  label: Text(
                                    context.s('Parve Bike', 'Paylaş'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                AppRoute.to(
                                  LeaderboardScreen(repository: repository),
                                ),
                              );
                            },
                            icon: const Icon(Icons.emoji_events_outlined),
                            label: Text(
                              context.s(
                                'Tabloya Pêşderçûnê',
                                'Liderlik Tablosu',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
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
    final user =
        (userIdentity ??
                Player(name: context.s('Tu', 'Tu'), score: 0, state: ''))
            .copyWith(score: userScore, state: 'Player');
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
    return AppPanel(
      gradient: AppTheme.goldGradient,
      child: Stack(
        children: [
          // Roj (güneş) ışını kutlaması: rozet açıldığında ışınlar bir kez
          // dışa doğru açılıp söner — kültürel imzayı ödül anına bağlar.
          Positioned.fill(
            child: IgnorePointer(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) =>
                    CustomPaint(painter: _RojRaysPainter(progress: v)),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.workspace_premium_outlined, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    context.s('Rozeta Nû', 'Yeni Rozet'),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final achievement in achievements)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(achievement.icon, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achievement.title(context.isKu),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              achievement.description(context.isKu),
                              style: TextStyle(
                                color: Colors.white70,
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
        ],
      ),
    );
  }
}

/// Roj motifi: merkezden dışa açılan 12 ışın; progress ilerledikçe uzar
/// ve şeffaflaşarak söner (tek seferlik kutlama parlaması).
class _RojRaysPainter extends CustomPainter {
  _RojRaysPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.longestSide * 0.55;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40 * (1 - progress))
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final inner = 18 + maxR * 0.45 * progress;
      final outer = inner + maxR * 0.35 * progress;
      canvas.drawLine(
        center + direction * inner,
        center + direction * outer,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RojRaysPainter oldDelegate) =>
      oldDelegate.progress != progress;
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
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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

class _MetricItemCompact extends StatelessWidget {
  const _MetricItemCompact({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(height: AppSpacing.xxs + 2),
          Text(
            value,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// Analytics tracking will be added in next iteration
// AnalyticsTracker.trackQuizComplete(category, correctCount, totalQuestions);
