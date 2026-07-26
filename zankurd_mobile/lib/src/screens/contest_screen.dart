import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/contest.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import '../widgets/styled_button.dart';
import 'quiz_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Günlük contest/etkinlik: tema, sıralama ve quiz başlatma.
class ContestScreen extends StatefulWidget {
  const ContestScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  late Future<Contest?> _contestFuture;
  bool _starting = false;

  /// Sıralama future'ı yarışma kimliğine göre bir kez oluşturulur.
  /// Daha önce `build()` içinde yaratılıyordu: her yeniden çizim (tema
  /// animasyonu, setState, klavye) yeni bir RPC atıyor ve listeyi spinner'a
  /// döndürüyordu.
  String? _leaderboardContestId;
  Future<List<ContestLeaderboardRow>>? _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _loadContest();
  }

  void _loadContest() {
    _contestFuture = widget.repository.loadTodayContest().timeout(
      const Duration(seconds: 8),
      onTimeout: () => null,
    );
  }

  Future<List<ContestLeaderboardRow>> _leaderboardFor(Contest contest) {
    if (_leaderboardContestId != contest.id || _leaderboardFuture == null) {
      _leaderboardContestId = contest.id;
      _leaderboardFuture = widget.repository.getContestLeaderboard(
        contestId: contest.id,
        limit: 10,
      );
    }
    return _leaderboardFuture!;
  }

  Future<void> _startQuiz(Contest contest) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      // Günlük yarışma, tema/kategori etiketinden bağımsız olarak ortak
      // günlük havuzdan beslenir. Repository bu havuzu UTC gün seed'i ile
      // seçtiği için aynı gün tüm oyuncular aynı soruları görür.
      var questions = await widget.repository.loadDailyQuestions(
        limit: contest.questionCount,
      );
      if (questions.isEmpty) {
        questions = widget.repository.questions
            .take(contest.questionCount)
            .toList();
      }
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t(K.noQuestionsFound))));
        return;
      }

      final room = widget.repository
          .createRoom(category: contest.category)
          .copyWith(
            name: contest.themeNameKu,
            questionCount: questions.length,
            // Günün yarışması tempolu bir mod; 20sn (2026-07-21 kullanıcı kararı).
            secondsPerQuestion: 20,
          );

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t(K.contestStartFailed))));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.t(K.dailyContest))),
      body: Container(
        color: AppTheme.bgOf(context),
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
                  title: context.t(K.loadFailedShort),
                  message: context.t(K.contestLoadFailed),
                  retryLabel: context.t(K.retryTiny),
                  onRetry: () => setState(_loadContest),
                );
              }
              final contest = snapshot.data;
              if (contest == null) {
                // Dürüst boş durum: isim eşleşmesi (Pêşbirka Rojê) + net
                // "yakında" mesajı + geri yolu. Kullanıcı ölü ekranda
                // kalmaz (2026-07-19 canlı denetim P1 bulgusu).
                return AppEmptyState(
                  icon: AppIcons.champagneGlasses,
                  title: context.t(K.dailyContest),
                  message: context.t(K.contestNoneToday),
                  actionLabel: context.t(K.goHome),
                  actionIcon: AppIcons.house,
                  onAction: () => Navigator.of(context).pop(),
                );
              }
              return _ContestContent(
                contest: contest,
                leaderboardFuture: _leaderboardFor(contest),
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
    required this.leaderboardFuture,
    required this.ku,
    required this.starting,
    required this.onStart,
  });

  final Contest contest;

  /// Üst State'te bir kez oluşturulan sıralama future'ı; burada
  /// oluşturulursa her rebuild yeni bir ağ isteği tetikler.
  final Future<List<ContestLeaderboardRow>> leaderboardFuture;
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
          title: context.t(K.dailyEvent),
          subtitle: context.t(K.dailyEventSub),
          accent: AppTheme.gold,
          icon: AppIcons.champagneGlasses,
        ),
        const SizedBox(height: AppSpacing.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            key: const ValueKey('contest-hero'),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.surfaceOf(context),
                  Color.alphaBlend(
                    AppTheme.gold.withValues(alpha: 0.12),
                    AppTheme.surfaceOf(context),
                  ),
                  Color.alphaBlend(
                    AppTheme.accent.withValues(alpha: 0.05),
                    AppTheme.surfaceOf(context),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppTheme.gold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.gold.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -14,
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.gold.withValues(alpha: 0.08),
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
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.gold.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            AppIcons.trophy,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            contest.themeNameFor(isKu: context.isKu),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if ((contest.themeDescriptionFor(isKu: context.isKu) ?? '')
                        .isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        contest.themeDescriptionFor(isKu: context.isKu)!,
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
                          icon: AppIcons.tableCells,
                          label: categoryLabel,
                        ),
                        _BadgeLabel(
                          icon: AppIcons.gaugeHigh,
                          label:
                              '${contest.difficultyMin}-${contest.difficultyMax}',
                        ),
                        _BadgeLabel(
                          icon: AppIcons.question,
                          label: context.t(K.questionCount, {
                            'count': '${contest.questionCount}',
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        context.t(K.contestRewards, {
                          'join': '${contest.participationReward}',
                          'first': '${contest.rank1Reward}',
                        }),
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.gold,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    GeometricGradientButton(
                      label: starting
                          ? (context.t(K.preparing))
                          : (context.t(K.startEvent)),
                      icon: AppIcons.play,
                      isLoading: starting,
                      onPressed: starting ? null : onStart,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.t(K.joinAndRank),
                      textAlign: TextAlign.center,
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textMutedColor(context),
                        fontWeight: FontWeight.w600,
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
          label: context.t(K.rankingWord),
          accent: AppTheme.gold,
        ),
        const SizedBox(height: AppSpacing.sm),
        FutureBuilder<List<ContestLeaderboardRow>>(
          future: leaderboardFuture,
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
                  context.t(K.rankingLoadFailed),
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
                  context.t(K.noParticipantsYet),
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
        color: AppTheme.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.badge),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppTheme.gold,
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

  /// İlk üç sıranın rozeti.
  ///
  /// Burada emoji kullanılıyordu (🥇🥈🥉); liderlik tablosu ise aynı işi
  /// `AppIcons.trophy`/`AppIcons.medal` ile yapıyor. İki ekran aynı şeyi
  /// iki ayrı görsel dilde anlatıyordu: emoji sistem fontundan gelir,
  /// cihazdan cihaza değişir ve uygulamanın ikon ailesine hiç benzemez
  /// (2026-07-26). Rozet artık iki ekranda da aynı.
  Widget _rankBadge(BuildContext context, int? rank) {
    final place = rank ?? (index + 1);
    if (place > 3) {
      return SizedBox(
        width: 24,
        child: Text(
          '$place.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppTheme.textMutedColor(context),
          ),
        ),
      );
    }
    final isLight = AppTheme.isLight(context);
    final color = switch (place) {
      1 => AppTheme.gold,
      2 => isLight ? AppTheme.silverLight : AppTheme.silver,
      _ => isLight ? AppTheme.bronzeLight : AppTheme.bronze,
    };
    return SizedBox(
      width: 24,
      child: Icon(
        place == 1 ? AppIcons.trophy : AppIcons.medal,
        color: color,
        size: 20,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final highlight = index == 0
        ? AppTheme.gold
        : index == 1
        ? AppTheme.accent
        : index == 2
        ? AppTheme.violet
        : AppTheme.borderColor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: highlight.withValues(alpha: index < 3 ? 0.24 : 1),
          width: 1,
        ),
        boxShadow: index < 3
            ? [
                BoxShadow(
                  color: highlight.withValues(alpha: 0.10),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                  spreadRadius: -10,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _rankBadge(context, row.rank),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t(K.correctAndScore, {
                    'correct': '${row.correctCount}',
                    'score': '${row.score}',
                  }),
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.textMutedColor(context),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: highlight.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${row.score}',
              style: AppTypography.caption.copyWith(
                color: index < 3 ? highlight : AppTheme.primaryGradientStart,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
