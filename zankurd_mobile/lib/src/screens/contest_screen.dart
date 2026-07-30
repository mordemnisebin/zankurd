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

/// Günlük 10 soruluk ilerleme etkinliği: tema ve quiz başlatma.
class ContestScreen extends StatefulWidget {
  const ContestScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  late Future<Contest?> _contestFuture;
  bool _starting = false;

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

  Future<void> _startQuiz(Contest contest) async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      // Günlük etkinlik, tema/kategori etiketinden bağımsız olarak ortak
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
          .createRoom(category: 'Tevlihev')
          .copyWith(
            name: context.t(K.dailyEvent),
            questionCount: questions.length,
            // Günlük etkinlik tempolu bir mod; 20sn (2026-07-21 kullanıcı kararı).
            secondsPerQuestion: 20,
          );

      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
            dailyQuiz: true,
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      // AppBar başlıksız: ekranın adını `ScreenIdentityHeader` taşıyor.
      // Burada başlık da verilince "Günün Etkinliği" ilk 300 pikselde iki
      // kez yazıyordu (2026-07-30 ekran turu, 11/24/31/34). Kimlik başlığı
      // kullanan on ekranın sekizi AppBar başlığını zaten boş bırakıyor;
      // aykırı olan buydu. (`review_screen` iki *farklı* başlık gösterir —
      // "Cevaplar" ve "Özet" — orada tekrar yok.)
      appBar: AppBar(),
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
                // Dürüst boş durum: isim eşleşmesi (Çalakiya Rojê) + net
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
    required this.starting,
    required this.onStart,
  });

  final Contest contest;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
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
            // Süs dairesi kartın iç boşluğunun içine kapatılmıştı:
            // `padding` Stack'in dışında olduğu için taşan daire kartın
            // yuvarlak köşesine değil, iç dikdörtgenin düz kenarına
            // kırpılıyor ve köşeli bir dilim bırakıyordu (2026-07-27).
            // Boşluk artık yalnız içeriğe uygulanır.
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
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
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
                              context.t(K.dailyEventCardTitle),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.heading2.copyWith(
                                color: AppTheme.textPrimaryColor(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        context.t(K.dailyEventCardBody),
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _BadgeLabel(
                            icon: AppIcons.question,
                            label: context.t(K.questionCount, {
                              'count': '${contest.questionCount}',
                            }),
                          ),
                        ],
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
          // Çipin zemini altının %10'luk tonu; ham altın orada 2.04:1.
          Icon(
            icon,
            size: 14,
            color: AppColors.onAccentTint(context, AppTheme.gold),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.onAccentTint(context, AppTheme.gold),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
