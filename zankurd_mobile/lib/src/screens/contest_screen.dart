import 'dart:async';

import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/contest.dart';
import '../theme/app_theme.dart';
import '../widgets/app_state.dart';

/// Günlük contest ekranı: tema, leaderboard, quiz start.
class ContestScreen extends StatefulWidget {
  const ContestScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  late Future<Contest?> _contestFuture;
  Timer? _refreshTimer;

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
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadContest();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startQuiz(Contest contest) {
    // TODO: Quiz başlatma akışı (Faz C Task 4'te Result entegr.)
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Quiz başlayacak')));
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(ku ? 'Etkinlik' : 'Etkinlik')),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: FutureBuilder<Contest?>(
            future: _contestFuture,
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  title: ku ? 'Barnekirî' : 'Yüklenemedi',
                  message: ku ? 'Etkinlik yüklenemiyor' : 'Contest yüklenemedi',
                  retryLabel: ku ? 'Dûbare' : 'Tekrar',
                  onRetry: () => setState(() => _loadContest()),
                );
              }
              final contest = snapshot.data;
              if (contest == null) {
                return AppEmptyState(
                  icon: Icons.celebration_outlined,
                  title: ku ? 'Hîn etkinlik tune' : 'Henüz etkinlik yok',
                  message: ku
                      ? 'Sibe kontestê tê.'
                      : 'Yarın yeni etkinlik başlar.',
                );
              }
              return _ContestContent(
                contest: contest,
                repository: widget.repository,
                onStartQuiz: () => _startQuiz(contest),
                ku: ku,
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
    required this.onStartQuiz,
    required this.ku,
  });

  final Contest contest;
  final ZanKurdRepository repository;
  final VoidCallback onStartQuiz;
  final bool ku;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        // Tema kartı
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.accent.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.emoji_events_outlined,
                    color: AppTheme.accent,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      contest.themeNameKu,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                contest.themeDescriptionKu ?? '',
                style: TextStyle(
                  color: AppTheme.textMutedColor(context),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _BadgeLabel(
                    icon: Icons.category_outlined,
                    label: contest.category,
                  ),
                  const SizedBox(width: 8),
                  _BadgeLabel(
                    icon: Icons.speed_outlined,
                    label: '${contest.difficultyMin}-${contest.difficultyMax}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStartQuiz,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(ku ? 'Kontestê Dest Pê Bike' : 'Başla'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Leaderboard
        Text(
          ku ? 'Pêşderiyan' : 'Leaderboard',
          style: TextStyle(
            color: AppTheme.textPrimaryColor(context),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<ContestLeaderboardRow>>(
          future: repository.getContestLeaderboard(
            contestId: contest.id,
            limit: 5,
          ),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              );
            }
            final rows = snap.data ?? [];
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  ku ? 'Hîn kesan tune' : 'Henüz katılım yok',
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
        color: AppTheme.accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.accent,
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
      _ => '${(rank ?? 0) + 1}.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(12),
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
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.correctCount}/${row.score}',
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
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${row.score}',
              style: TextStyle(
                color: AppTheme.accent,
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
