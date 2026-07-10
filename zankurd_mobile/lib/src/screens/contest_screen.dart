import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/contest.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/kilim_pattern_painter.dart';
import '../widgets/screen_identity_header.dart';
import '../widgets/styled_button.dart';
import 'quiz_screen.dart';

/// Günlük contest/etkinlik: tema, sıralama ve quiz başlatma.
class ContestScreen extends StatefulWidget {
  const ContestScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  late Future<Contest?> _contestFuture;
  Timer? _refreshTimer;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _loadContest();
    _startRefresh();
  }

  void _loadContest() {
    _contestFuture = widget.repository.loadTodayContest();
  }

  void _startRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _starting) return;
      setState(_loadContest);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _startQuiz(Contest contest) async {
    if (_starting) return;
    setState(() => _starting = true);
    final ku = context.isKu;
    try {
      var questions = await widget.repository.loadLevelQuestions(
        category: contest.category,
        difficultyMin: contest.difficultyMin,
        difficultyMax: contest.difficultyMax,
        limit: contest.questionCount,
      );
      if (questions.isEmpty) {
        questions = await widget.repository.loadDailyQuestions(
          limit: contest.questionCount,
        );
      }
      if (questions.isEmpty) {
        questions = widget.repository.questions
            .take(contest.questionCount)
            .toList();
      }
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ku ? 'Pirs nehatin dîtin.' : 'Soru bulunamadı.'),
          ),
        );
        return;
      }

      final room = widget.repository
          .createRoom(category: contest.category)
          .copyWith(name: contest.themeNameKu, questionCount: questions.length);

      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            dailyQuiz: true,
            contestId: contest.id,
          ),
        ),
      );
      if (!mounted) return;
      setState(_loadContest);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'contest quiz start failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ku
                ? 'Çalakî dest pê nekir. Dîsa biceribîne.'
                : 'Etkinlik başlatılamadı. Tekrar dene.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Çalakî' : 'Etkinlik')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: FutureBuilder<Contest?>(
            future: _contestFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGradientStart,
                  ),
                );
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  title: ku ? 'Barnebû' : 'Yüklenemedi',
                  message: ku
                      ? 'Çalakî nehat barkirin.'
                      : 'Etkinlik yüklenemedi.',
                  retryLabel: ku ? 'Dîsa' : 'Tekrar',
                  onRetry: () => setState(_loadContest),
                );
              }
              final contest = snapshot.data;
              if (contest == null) {
                return AppEmptyState(
                  icon: Icons.celebration_outlined,
                  title: ku ? 'Hîn çalakî tune' : 'Henüz etkinlik yok',
                  message: ku
                      ? 'Sibê çalakiya nû tê.'
                      : 'Yarın yeni etkinlik başlar.',
                );
              }
              return _ContestContent(
                contest: contest,
                repository: widget.repository,
                ku: ku,
                starting: _starting,
                onStart: () => _startQuiz(contest),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ContestContent extends StatelessWidget {
  const _ContestContent({
    required this.contest,
    required this.repository,
    required this.ku,
    required this.starting,
    required this.onStart,
  });

  final Contest contest;
  final ZanKurdRepository repository;
  final bool ku;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = CategoryNames.localized(contest.category, ku);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      children: [
        // Pêşbaz ailesi — altın kimlik.
        ScreenIdentityHeader(
          title: ku ? 'Çalakiya Rojê' : 'Günün Etkinliği',
          subtitle: ku ? 'Beşdar bibe û xelatê bigire' : 'Katıl ve ödülü kap',
          accent: AppTheme.gold,
          icon: Icons.celebration_rounded,
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceOf(context),
                  Color.alphaBlend(
                    AppTheme.gold.withValues(alpha: 0.10),
                    AppTheme.surfaceOf(context),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: AppTheme.glowShadow(AppTheme.gold, intensity: 0.10),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: KilimPatternPainter(
                        drawPattern: true,
                        color: AppTheme.gold,
                        opacity: 0.04,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.goldGradient,
                            boxShadow: AppTheme.glowShadow(
                              AppTheme.gold,
                              intensity: 0.22,
                            ),
                          ),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            contest.themeNameKu,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((contest.themeDescriptionKu ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        contest.themeDescriptionKu!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        _BadgeLabel(
                          icon: Icons.category_outlined,
                          label: categoryLabel,
                        ),
                        _BadgeLabel(
                          icon: Icons.speed_outlined,
                          label:
                              '${contest.difficultyMin}-${contest.difficultyMax}',
                        ),
                        _BadgeLabel(
                          icon: Icons.quiz_outlined,
                          label: ku
                              ? '${contest.questionCount} pirs'
                              : '${contest.questionCount} soru',
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GeometricGradientButton(
                      label: starting
                          ? (ku ? 'Tê amadekirin…' : 'Hazırlanıyor…')
                          : (ku ? 'Çalakiyê dest pê bike' : 'Etkinliğe başla'),
                      icon: Icons.play_arrow_rounded,
                      isLoading: starting,
                      onPressed: starting ? null : onStart,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      ku
                          ? 'Beşdariyê bike û pêşderçûnê de cîh bigire.'
                          : 'Katıl ve sıralamada yerini al.',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      ku
                          ? 'Xelat: beşdarî ${contest.participationReward} · 1. ${contest.rank1Reward} coin'
                          : 'Ödül: katılım ${contest.participationReward} · 1. ${contest.rank1Reward} coin',
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.gold,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section - 8),
        ScreenSectionLabel(
          label: ku ? 'Pêşderçûn' : 'Sıralama',
          accent: AppTheme.gold,
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<ContestLeaderboardRow>>(
          future: repository.getContestLeaderboard(
            contestId: contest.id,
            limit: 10,
          ),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primaryGradientStart,
                  ),
                ),
              );
            }
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ku ? 'Rêzkirin nehat barkirin.' : 'Sıralama yüklenemedi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedColor(context)),
                ),
              );
            }
            final rows = snap.data ?? [];
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ku
                      ? 'Hîn beşdar tune — yekemîn tu bibe!'
                      : 'Henüz katılım yok — ilk sen ol!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMutedColor(context)),
                ),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < rows.length; i++)
                  _LeaderboardRow(row: rows[i], index: i, ku: ku),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _BadgeLabel extends StatelessWidget {
  const _BadgeLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryGradientStart.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryGradientStart),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryGradientStart,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.row,
    required this.index,
    required this.ku,
  });

  final ContestLeaderboardRow row;
  final int index;
  final bool ku;

  String _rankEmoji(int? rank) {
    return switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '${rank ?? (index + 1)}.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppTheme.borderColor(context), width: 1),
      ),
      child: Row(
        children: [
          Text(_rankEmoji(row.rank), style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ku
                      ? '${row.correctCount} rast · ${row.score} pûan'
                      : '${row.correctCount} doğru · ${row.score} puan',
                  style: TextStyle(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGradientStart.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${row.score}',
              style: const TextStyle(
                color: AppTheme.primaryGradientStart,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
