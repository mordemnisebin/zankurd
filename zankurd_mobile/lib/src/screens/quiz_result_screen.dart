import 'dart:async';

import 'package:flutter/material.dart';
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
import '../l10n/strings.dart';
import '../providers/child_safety_provider.dart';
import '../services/premium_service.dart';
import '../models/achievement.dart';
import '../models/answer_record.dart';
import '../models/quiz_question.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../providers/reduced_motion_provider.dart';
import '../widgets/kilim_reveal.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
import '../data/daily_mission_store.dart';
import '../data/xp_store.dart';
import '../services/analytics_service.dart';
import '../services/review_service.dart';
import '../utils/result_sharer.dart';
import '../widgets/mission_toast.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/player_avatar.dart';
import '../widgets/roj_mascot.dart';
import 'leaderboard_screen.dart';
import 'review_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
    this.rewardQueued = false,
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

  /// Ödül sunucuya ulaşamadığı için kuyruğa alındı mı?
  ///
  /// Çevrimdışı bitirilen turda coin rozeti hiç görünmüyordu (rozet yalnız
  /// miktar sıfırdan büyükse çizilir) ve oyuncu turu boşuna oynadığını
  /// sanıyordu. Ödül artık kuyrukta beklediği için bunu söylemek doğru:
  /// kayıp değil, gecikme (2026-07-26).
  final bool rewardQueued;
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

  /// Kırılacak günlük seri için coin karşılığı dondurma teklif eder.
  /// Ödeme yapılıp seri korunursa yeni seri değerini, aksi halde null döner.
  static const _streakFreezeCost = 50;

  Future<int?> _maybeOfferStreakFreeze(StreakStore store) async {
    if (!mounted) return null;
    int balance;
    try {
      balance = await repository.loadCoinBalance();
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_freeze_balance');
      return null;
    }
    if (!mounted || balance < _streakFreezeCost) return null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t(K.streakBreaking)),
        content: Text(
          context.t(K.streakFreezeAsk, {'cost': '$_streakFreezeCost'}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.t(K.streakLetGo)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              context.t(K.streakFreezeAction, {'cost': '$_streakFreezeCost'}),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return null;
    bool ok;
    try {
      ok = await repository.spendCoins(_streakFreezeCost, 'streak_freeze');
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'streak_freeze_spend');
      return null;
    }
    if (!ok) return null;
    // Coin ödendi: bir jeton verilip hemen uygulanır (seri +1 devam eder).
    await store.addFreeze();
    return store.freezeAndRecordPlay();
  }

  Future<void> _recordProgress() async {
    // Premium durumunu await'lerden ÖNCE, context hâlâ güvenliyken oku.
    final isPremium = context.read<PremiumService>().isPremium;
    final streakStore = await StreakStore.load();
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    final isNewDay = streakStore.lastDay != todayKey;

    // Seri bugün oynamayınca kırılacaksa: Premium ise otomatik ve ÜCRETSİZ
    // korunur; değilse oyuncuya coin karşılığı koruma teklif edilir
    // (pay-at-result). Kabul edilmezse normal davranış işler.
    final int streak;
    if (streakStore.willBreakOnPlay()) {
      if (isPremium) {
        await streakStore.addFreeze();
        streak = await streakStore.freezeAndRecordPlay();
      } else {
        final saved = await _maybeOfferStreakFreeze(streakStore);
        streak = saved ?? await streakStore.recordPlay();
      }
    } else {
      streak = await streakStore.recordPlay();
    }
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
      await repository.awardProfileXPDelta(earnedXP);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'quiz_result_reward');
      SyncManager.instance.queueXP(xpStore.totalXP, delta: earnedXP);
    }

    // Doğru anda (yeterli quiz + iyi skor) bir kez mağaza değerlendirmesi iste.
    final accuracyPercent = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();
    final reviewService = await ReviewService.load();
    await reviewService.recordQuizCompletion(accuracyPercent: accuracyPercent);

    AnalyticsService.instance.logQuizComplete(
      category: room.category,
      correctCount: correctCount,
      totalQuestions: totalQuestions,
      xpEarned: earnedXP,
    );
    for (final achievement in newAchievements) {
      AnalyticsService.instance.logBadgeEarned(achievement.id);
    }

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
                      child: const Icon(
                        AppIcons.medal,
                        color: AppTheme.gold,
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.isKu ? 'Asta Te Bilind Bû!' : 'Seviyen Yükseldi!',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => Navigator.of(
                          context,
                        ).pop({'score': score, 'correct': correctCount}),
                        child: Text(
                          context.isKu ? 'Berdawam bike' : 'Devam Et',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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

    // 1v1 sonuç gradyanları: AppTheme.correctDeep / wrongDeep token'ları
    // kullanılır (M-11 — hardcoded Color literal → adlandırılmış sabit).
    final headerGradient = is1v1
        ? (isWinner
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.correct.withValues(alpha: 0.92),
                    AppTheme.correctDeep,
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
                    AppTheme.wrongDeep,
                  ],
                ))
        // Solo sonuç vitrini kimlik anıdır, eylem değil: Kesk (marka yeşili)
        // kullanılır. Turuncu yalnız "sonraki adım" butonunda kalır — böylece
        // ekranda göz nereye gideceğini şaşırmaz. Ayrıca eski turuncu hero,
        // açık temada beyaz metni okutabilmek için siyah perde harcıyordu.
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.culturalBrandBg, AppTheme.brandDeep],
          );

    final borderColor = is1v1
        ? (isWinner
              ? AppTheme.correct.withValues(alpha: 0.55)
              : isDraw
              ? AppTheme.borderColor(context)
              : AppTheme.wrong.withValues(alpha: 0.55))
        : AppTheme.brand.withValues(alpha: 0.45);

    final headerTitle = is1v1
        ? (isWinner
              ? context.t(K.youWon)
              : isDraw
              ? context.t(K.draw)
              : context.t(K.youLost))
        : context.t(K.raceFinished);

    final headerIcon = is1v1
        ? (isWinner
              ? AppIcons.trophy
              : isDraw
              ? AppIcons.scaleBalanced
              : AppIcons.faceFrown)
        : AppIcons.flag;

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
        title: Text(context.t(K.resultTitle)),
      ),
      body: Container(
        color: AppTheme.bgOf(context),
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
                    // Kutlama katmanı: kilim dokusu başlığın arkasında
                    // merkezden dışa açılır.
                    //
                    // Tek kutlama kanalı konfetiydi; konfeti her uygulamada
                    // aynıdır ve ZanKurd'a ait bir şey söylemez (2026-07-25
                    // görsel denetimi). Marka dili zaten kilim motifine
                    // dayanıyor — kutlama da aynı dili konuşur.
                    //
                    // Yalnız kutlanacak bir sonuç varken çizilir: 1v1'de
                    // galibiyet, solo turda en az yarısı doğru. Kaybedilen
                    // turda kutlama deseni açmak, sonucu yanlış okur.
                    child: KilimReveal(
                      active: is1v1
                          ? isWinner
                          : (totalQuestions > 0 &&
                                correctCount * 2 >= totalQuestions),
                      // Sağlayıcı yoksa (ör. bu ekranı izole eden widget
                      // testleri) kutlama sessizce animasyonsuz çizilir.
                      // Dekoratif bir katman, barındırıldığı ağaç eksik
                      // diye ekranı çökertmemeli.
                      reducedMotion:
                          context
                              .watch<ReducedMotionProvider?>()
                              ?.reduceMotion ??
                          false,
                      color: kilimRevealColorFor(context, onBrand: !isDraw),
                      child: Container(
                        key: const ValueKey('result-score-header'),
                        decoration: BoxDecoration(
                          gradient: headerGradient,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
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
                            // 2026-07-23 M33: Roj maskotu sonuç ekranında hiç
                            // yoktu — marka kimliği en duygusal andan
                            // (skoru görme) eksikti. Skora göre ruh hâli
                            // değişir; yoğun bilgi sütununu bozmasın diye
                            // sol üst köşede küçük bir rozet olarak durur.
                            Positioned(
                              left: 0,
                              top: 0,
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: 0.85,
                                  child: RojMascot(
                                    size: 36,
                                    mood: accuracy >= 80
                                        ? RojMood.celebrate
                                        : accuracy >= 40
                                        ? RojMood.happy
                                        : RojMood.thinking,
                                  ),
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
                                // Yıldızlar turuncu hero üzerinde duruyor:
                                // altın (#E7B53C) turuncuda ~1.3:1, boş yıldız
                                // beyaz@0.18 ile görünmez haldeydi — skorun en
                                // özet göstergesi okunmuyordu (2026-07-22 UX
                                // denetimi). Koyu yarı saydam bir hap zemin
                                // hem doluyu hem boşu ayrıştırıyor.
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.heroScrim(),
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.pill,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (var i = 0; i < 3; i++)
                                        Icon(
                                          AppIcons.star,
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
                                                  alpha: 0.32,
                                                ),
                                        ),
                                    ],
                                  ),
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
                                  '${CategoryNames.localized(room.category, context.isKu)} · %$accuracy ${context.t(K.accuracyLower)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                // Ödül rozetleri.
                                //
                                // `Row` idi: sistem yazısı büyütüldüğünde iki
                                // rozet yan yana sığmıyor ve kartın dışına
                                // taşıyordu. `Wrap` sığmayanı alt satıra alır
                                // (2026-07-26).
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (coinsAwarded > 0)
                                      _ResultRewardChip(
                                        icon: AppIcons.coins,
                                        label: '+${coinsAwarded}c',
                                        color: AppTheme.gold,
                                      ),
                                    if (_earnedXP > 0)
                                      _ResultRewardChip(
                                        icon: AppIcons.bolt,
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
                                // Ödül kuyrukta bekliyorsa bunu söyle.
                                // Rozet yalnız miktar sıfırdan büyükse
                                // çizildiği için çevrimdışı turda ekranda
                                // hiçbir iz kalmıyor ve oyuncu turu boşuna
                                // oynadığını sanıyordu (2026-07-26).
                                if (widget.rewardQueued &&
                                    coinsAwarded <= 0) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        AppIcons.cloud,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          context.t(K.rewardPending),
                                          textAlign: TextAlign.center,
                                          style: AppTypography.caption.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                                      icon: AppIcons.circleCheck,
                                      value: '$correctCount',
                                      label: context.t(K.correct),
                                      color: AppTheme.correct,
                                    ),
                                    _StatPill(
                                      icon: AppIcons.circleXmark,
                                      value: '$wrongCount',
                                      label: context.t(K.wrong),
                                      color: AppTheme.wrong,
                                    ),
                                    if (unanswered > 0)
                                      _StatPill(
                                        icon: AppIcons.hourglass,
                                        value: '$unanswered',
                                        label: context.t(K.blank),
                                        color: AppTheme.textMutedColor(context),
                                      ),
                                    if (bestStreak > 0)
                                      _StatPill(
                                        icon: AppIcons.fire,
                                        value: '$bestStreak',
                                        label: context.t(K.streakLabel),
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
                          const Icon(
                            AppIcons.fire,
                            color: AppTheme.accent,
                            size: 30,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t(K.dailyStreakDays, {
                                    'days': '$_dailyStreak',
                                  }),
                                  style: TextStyle(
                                    color: AppTheme.textPrimaryColor(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.t(K.keepStreakTomorrow),
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
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            boxShadow: AppTheme.glowShadow(
                              AppTheme.primaryCtaColor(context),
                              intensity: 0.28,
                            ),
                          ),
                          child: SizedBox(
                            height: 54,
                            child: FilledButton.icon(
                              key: const ValueKey('result-play-again-button'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryCtaColor(
                                  context,
                                ),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.md,
                                  ),
                                ),
                                elevation: 0,
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
                              icon: const Icon(
                                AppIcons.arrowRotateLeft,
                                size: 20,
                              ),
                              label: Text(
                                QuizStrings.playAgain(context.isKu),
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
                      ),
                      const SizedBox(width: 10),
                      _ResultSideAction(
                        key: const ValueKey('result-review-button'),
                        icon: AppIcons.squareCheck,
                        label: context.t(K.review),
                        onTap: answerRecords.isEmpty
                            ? null
                            : () => Navigator.of(context).push(
                                AppRoute.to(
                                  ReviewScreen(
                                    records: answerRecords,
                                    room: room,
                                  ),
                                ),
                              ),
                      ),
                      if (context
                          .watch<ChildSafetyProvider>()
                          .allowExternalShare)
                        _ResultSideAction(
                          key: const ValueKey('result-share-button'),
                          icon: AppIcons.shareNodes,
                          label: context.t(K.share),
                          onTap: () => ResultSharer.share(
                            context,
                            isKu: context.isKu,
                            score: score,
                            correctCount: correctCount,
                            totalQuestions: totalQuestions,
                            bestStreak: bestStreak,
                            category: room.category,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
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
                              horizontal: 10,
                              vertical: 6,
                            ),
                          ),
                          onPressed: () => Navigator.of(
                            context,
                          ).popUntil((route) => route.isFirst),
                          child: Text(
                            context.t(K.home),
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSubColor(context),
                              fontWeight: FontWeight.w700,
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
                            context.t(K.onlyWrong),
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
                            context.t(K.leaderboardLink),
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
                        // Değerlendir: öne çıkan CTA değil, soluk link — her
                        // sonuç ekranında birincil aksiyonla yarışmasın.
                        TextButton(
                          key: const ValueKey('result-rate-button'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: () => ReviewService.openStoreListing(),
                          child: Text(
                            context.t(K.rate),
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
                  // Turun bütün açıklamaları en sonda, bir arada.
                  //
                  // Eskiden her şıkkın altında tek tek açılıyordu; şık
                  // işaretlenir işaretlenmez paragraf beliriyor ve turun
                  // ritmi kesiliyordu (uygulama sahibinin tekrarlanan geri
                  // bildirimi, 2026-07-26). Kart birincil butonların
                  // *altında* durur: "Tekrar oyna" uzun bir okuma listesinin
                  // arkasında kalmamalı.
                  const SizedBox(height: 20),
                  _AllExplanationsCard(records: answerRecords),
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
        .copyWith(name: context.t(K.you), score: userScore, state: 'Player');
    final standings = [user, ...opponents]
      ..sort((a, b) => b.score.compareTo(a.score));
    final userRank =
        standings.indexWhere((player) => player.state == 'Player') + 1;
    final leader = standings.first;
    final title = context.t(K.compareRivals);
    final summary = leader.state == 'Player'
        ? context.t(K.finishedAtRank, {'rank': '$userRank'})
        : context.t(K.leaderFinishedFirst, {
            'leader': leader.name,
            'rank': '$userRank',
          });

    return AppPanel(
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.peopleGroup, color: AppTheme.accent),
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
          // Sabit `textMuted` karanlık tema rengi; açık temada okunmuyordu.
          Text(
            summary,
            style: TextStyle(color: AppTheme.textMutedColor(context)),
          ),
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
                  AppIcons.medal,
                  color: AppTheme.gold,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(K.newBadge),
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
                      borderRadius: BorderRadius.circular(AppRadius.badge),
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
                      borderRadius: BorderRadius.circular(AppRadius.sm),
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
                          // Anahtar tabanlı kayda taşınmadı ve taşınmamalı:
                          // iki dal yalnız *metin* değil, iki farklı veri
                          // araması yapıyor — `CategoryNames.localized`
                          // farklı argümanla, unvan da farklı alandan
                          // (`titleKu` / `titleTr`) okunuyor. Bu bir çeviri
                          // değil, dile göre kaynak seçimidir; kayıt defteri
                          // bunu ifade edemez.
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
                          context.t(K.newTitleEarned),
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
        borderRadius: BorderRadius.circular(AppRadius.md),
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
              borderRadius: BorderRadius.circular(AppRadius.badge),
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
            const Icon(AppIcons.fire, color: AppTheme.gold, size: 18),
            const SizedBox(width: 4),
            Text(
              '${player.streak}',
              style: const TextStyle(
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

/// Sonuç yan eylemi — ikon + kısa etiket, primary CTA'yı boğmaz.
class _ResultSideAction extends StatelessWidget {
  const _ResultSideAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final color = enabled
        ? AppTheme.textPrimaryColor(context)
        : AppTheme.textMutedColor(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Ink(
          width: 64,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.surfaceHiColor(context),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppTheme.borderColor(context).withValues(alpha: 0.7),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
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
    // Pill turuncu hero gradyanının üzerinde durur; yüzey metin renkleri
    // (textPrimary/textMuted) burada okunmuyordu — "Doğru/Yanlış/Seri"
    // etiketleri turuncu üstü turuncuya düşüyordu (~1.8:1, 2026-07-22 UX
    // denetimi). Beyaz metin tek başına da yetmez (turuncuda ~2.2:1), bu
    // yüzden koyu yarı saydam bir zemin eklendi.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.heroScrim(),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Turun bütün açıklamalarını tek kartta toplayan bölüm.
///
/// Açıklama eskiden cevaptan hemen sonra sorunun altında açılıyordu.
/// Uygulama sahibi bunu birkaç kez sorun olarak bildirdi: şık işaretlenir
/// işaretlenmez altında bir paragraf beliriyor, tur duruyor ve okuma yükü
/// oyunun ritmini kesiyordu. Karar: tur sırasında yalnız doğru cevap
/// görünür, açıklamaların tamamı sorular bittiğinde burada bir arada gelir.
///
/// Boş ya da şablon açıklamalar hiç listelenmez — `getLocalizedExplanation`
/// onlar için boş döner ve boş bir satır göstermek, açıklama olmamasından
/// kötüdür.
class _AllExplanationsCard extends StatelessWidget {
  const _AllExplanationsCard({required this.records});

  final List<AnswerRecord> records;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final entries = <({int index, AnswerRecord record, String explanation})>[];
    for (var i = 0; i < records.length; i++) {
      // Önce sorunun **yazılmış** açıklaması, sonra kural motoru.
      //
      // Burası doğrudan motora gidiyordu ve bankada yazılı Kurmancî
      // açıklamayı hiç görmüyordu; motor eşleşme bulamayınca ham Türkçe
      // metni `Şirove: <cümle>` diye sarıyor ve sarmak çevirmek değil.
      // Açıklamaların **asıl gösterildiği yer** burasıdır: tur boyunca
      // hiçbir açıklama gösterilmez, hepsi burada toplanır (2026-07-27).
      final authored = isKu
          ? records[i].explanationKu
          : records[i].explanationTr;
      final text =
          (authored != null &&
              authored.trim().isNotEmpty &&
              !isTemplateExplanation(authored))
          ? authored
          : resolveRawExplanation(
              id: records[i].id,
              explanation: records[i].explanation,
              isKu: isKu,
            );
      if (text.trim().isEmpty) continue;
      entries.add((index: i + 1, record: records[i], explanation: text));
    }
    if (entries.isEmpty) return const SizedBox.shrink();

    return AppPanel(
      key: const ValueKey('result-all-explanations'),
      cardType: CardType.secondary,
      color: AppTheme.surfaceHiColor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.bookOpen, color: AppTheme.correct, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(K.allExplanations),
                  style: AppTypography.heading2.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.t(K.allExplanationsHint),
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
            ),
          ),
          for (final entry in entries) ...[
            const SizedBox(height: 14),
            _ExplanationEntry(
              index: entry.index,
              record: entry.record,
              explanation: entry.explanation,
            ),
          ],
        ],
      ),
    );
  }
}

class _ExplanationEntry extends StatelessWidget {
  const _ExplanationEntry({
    required this.index,
    required this.record,
    required this.explanation,
  });

  final int index;
  final AnswerRecord record;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    // Doğru/yanlış ayrımı renkle verilir: oyuncu hangi soruda takıldığını
    // listeyi okumadan bulabilsin.
    final tone = record.isUnanswered
        ? AppTheme.gold
        : (record.isCorrect ? AppTheme.correct : AppTheme.wrong);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border(left: BorderSide(color: tone, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$index. ${record.prompt}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${context.t(K.correctAnswerLabel)}: ${record.correctAnswer}',
            style: AppTypography.caption.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            explanation,
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textSubColor(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
