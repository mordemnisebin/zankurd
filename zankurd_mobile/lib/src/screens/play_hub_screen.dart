import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_panel.dart';
import '../widgets/screen_identity_header.dart';
import 'contest_screen.dart';
import 'home/quick_play_grid.dart';
import 'matchmaking_screen.dart';
import 'quiz_screen.dart';
import 'room_screen.dart';
import 'shop_screen.dart';
import 'spin_wheel_screen.dart';
import 'tournament_screen.dart';

class PlayHubScreen extends StatefulWidget {
  const PlayHubScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<PlayHubScreen> createState() => _PlayHubScreenState();
}

class _PlayHubScreenState extends State<PlayHubScreen> {
  bool _dailyLoading = false;
  bool _roomActionLoading = false;

  Future<void> _openDailyQuiz() async {
    setState(() => _dailyLoading = true);
    try {
      final contest = await widget.repository.loadTodayContest();
      if (!mounted) return;
      if (contest != null) {
        await Navigator.of(
          context,
        ).push(AppRoute.to(ContestScreen(repository: widget.repository)));
        return;
      }
      final questions = await widget.repository.loadQuestions(limit: 10);
      if (!mounted || questions.isEmpty) return;
      final room = widget.repository.createRoom().copyWith(
        questionCount: questions.length,
      );
      await Navigator.of(context).push(
        AppRoute.to(
          QuizScreen(
            repository: widget.repository,
            room: room,
            questions: questions,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _dailyLoading = false);
    }
  }

  Future<void> _createOnlineRoom() async {
    if (_roomActionLoading) return;
    setState(() => _roomActionLoading = true);
    try {
      final room = await widget.repository.createOnlineRoom();
      if (!mounted) return;
      _openRoom(room);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'play hub create room failed');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.s(
              'Ode nehate vekirin. Têkiliya xwe kontrol bike.',
              'Oda açılamadı. Bağlantını kontrol et.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _roomActionLoading = false);
    }
  }

  void _openRoom(GameRoom room) {
    Navigator.of(context).push(
      AppRoute.to(RoomScreen(repository: widget.repository, initialRoom: room)),
    );
  }

  Future<void> _showJoinSheet() async {
    final ku = context.isKu;
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final inputTextStyle = TextStyle(
      color: AppTheme.textPrimaryColor(context),
      fontWeight: FontWeight.w800,
      letterSpacing: 1.4,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.page,
            right: AppSpacing.page,
            bottom: MediaQuery.viewInsetsOf(sheetCtx).bottom + AppSpacing.page,
          ),
          child: AppPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ku ? 'Tevlî Odeyê Bibe' : 'Odaya Katıl',
                    style: AppTypography.heading1.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    ku
                        ? 'Koda odeyê binivîse û bi hevalên xwe re bilîze.'
                        : 'Oda kodunu yaz ve arkadaşlarınla oyna.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textSubColor(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    key: const ValueKey('play-hub-join-room-code-field'),
                    controller: controller,
                    textCapitalization: TextCapitalization.characters,
                    style: inputTextStyle,
                    decoration: InputDecoration(
                      labelText: ku ? 'Koda odeyê' : 'Oda kodu',
                      prefixIcon: const Icon(Icons.meeting_room_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return ku ? 'Kod pêwîst e' : 'Kod zorunlu';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        try {
                          final room = await widget.repository.joinOnlineRoom(
                            controller.text.trim(),
                          );
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          if (mounted) _openRoom(room);
                        } catch (error, stack) {
                          ErrorReporter.record(
                            error,
                            stack,
                            reason: 'play hub join room failed',
                          );
                          if (!sheetCtx.mounted) return;
                          Navigator.of(sheetCtx).pop();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ku
                                    ? 'Odeya bi vê kodê nehate dîtin.'
                                    : 'Bu kodla oda bulunamadı.',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: Text(ku ? 'Tevlî bibe' : 'Katıl'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.page),
          children: [
            ScreenIdentityHeader(
              title: ku ? 'Pêşbazî' : 'Yarış',
              subtitle: ku
                  ? 'Pêşbirk, turnuva û xelat hemû li vir in'
                  : 'Günlük yarışma, düello ve ödüller tek yerde',
              accent: AppTheme.brandOrange,
              icon: Icons.sports_esports_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
            _PlaySectionHeading(
              title: ku ? 'Pêşbaziyek hilbijêre' : 'Bir yarış seç',
              subtitle: ku
                  ? 'Ji bo destpêkirinê yek ji modan hilbijêre.'
                  : 'Başlamak için bir yarış modunu seç.',
            ),
            const SizedBox(height: AppSpacing.sm),
            QuickPlayGrid(
              isKu: ku,
              dailyQuizLoading: _dailyLoading,
              onDuel: () => Navigator.of(context).push(
                AppRoute.to(MatchmakingScreen(repository: widget.repository)),
              ),
              onDailyQuiz: _openDailyQuiz,
              onSpinWheel: () => Navigator.of(context).push(
                AppRoute.to(SpinWheelScreen(repository: widget.repository)),
              ),
              onTournament: () => Navigator.of(context).push(
                AppRoute.to(TournamentScreen(repository: widget.repository)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _GroupPlayPanel(
              ku: ku,
              loading: _roomActionLoading,
              onCreateRoom: _createOnlineRoom,
              onJoinRoom: _showJoinSheet,
            ),
            const SizedBox(height: AppSpacing.md),
            _SupportActions(
              ku: ku,
              onOpenShop: () => Navigator.of(
                context,
              ).push(AppRoute.to(ShopScreen(repository: widget.repository))),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaySectionHeading extends StatelessWidget {
  const _PlaySectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.heading2.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: AppTheme.textSubColor(context),
          ),
        ),
      ],
    );
  }
}

class _GroupPlayPanel extends StatelessWidget {
  const _GroupPlayPanel({
    required this.ku,
    required this.loading,
    required this.onCreateRoom,
    required this.onJoinRoom,
  });

  final bool ku;
  final bool loading;
  final VoidCallback onCreateRoom;
  final VoidCallback onJoinRoom;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      key: const ValueKey('play-hub-group-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.playCyan.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.groups_2_rounded,
                  color: AppTheme.playCyan,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ku
                          ? 'Bi heval an komê re bilîze'
                          : 'Arkadaşınla veya grupla oyna',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      ku
                          ? 'Odeyek veke, kodê parve bike, hevalên xwe vexwîne.'
                          : 'Oda aç, kodu paylaş, arkadaşlarını davet et.',
                      style: AppTypography.caption.copyWith(
                        color: AppTheme.textSubColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('play-hub-create-room'),
                  onPressed: loading ? null : onCreateRoom,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_circle_outline),
                  label: Text(
                    loading
                        ? (ku ? 'Tê Vekirin...' : 'Açılıyor...')
                        : (ku ? 'Odeyek Ava Bike' : 'Oda Kur'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('play-hub-join-room'),
                  onPressed: onJoinRoom,
                  icon: const Icon(Icons.meeting_room_outlined),
                  label: Text(ku ? 'Kodê tevlî bibe' : 'Kodla Katıl'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportActions extends StatelessWidget {
  const _SupportActions({required this.ku, required this.onOpenShop});

  final bool ku;
  final VoidCallback onOpenShop;

  @override
  Widget build(BuildContext context) {
    return _SupportCard(
      key: const ValueKey('play-hub-shop-card'),
      icon: Icons.storefront_outlined,
      color: AppTheme.gold,
      title: ku ? 'Dukan û joker' : 'Mağaza ve jokerler',
      subtitle: ku
          ? 'Coin, çerx û mafên joker li yek derê.'
          : 'Coin, çark ve joker hakların tek yerde.',
      onTap: onOpenShop,
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({
    required super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AppPanel(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: color.withValues(alpha: 0.28)),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppTheme.textPrimaryColor(context),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: AppTheme.textSubColor(context),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
