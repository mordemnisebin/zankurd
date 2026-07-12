import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/screen_identity_header.dart';
import 'home/quick_play_grid.dart';
import 'matchmaking_screen.dart';
import 'quiz_screen.dart';
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

  Future<void> _openDailyQuiz() async {
    setState(() => _dailyLoading = true);
    try {
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
              title: ku ? 'Bilîze' : 'Oyna',
              subtitle: ku
                  ? 'Pêşbirk, turnuva û xelat li yek derê'
                  : 'Yarışma, turnuva ve ödüller tek yerde',
              accent: AppTheme.brandOrange,
              icon: Icons.sports_esports_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
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
          ],
        ),
      ),
    );
  }
}
