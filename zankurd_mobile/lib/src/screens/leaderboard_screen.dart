import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/leaderboard_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import 'quiz_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.loadLeaderboard();
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.loadLeaderboard();
    });
  }

  Future<void> _startQuickRace() async {
    final questions = await widget.repository.loadQuestions(limit: 10);
    if (!mounted) return;
    final raceQuestions = questions.isEmpty
        ? widget.repository.questions
        : questions;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          repository: widget.repository,
          room: widget.repository.createRoom(),
          questions: raceQuestions,
          botRace: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku ? 'Tabloya Pêşderiyan' : 'Liderlik Tablosu',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        Text(
                          ku ? 'Baştirîn lîstikvan' : 'En iyi oyuncular',
                          style: const TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.textSub,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<LeaderboardEntry>>(
                future: _future,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppTheme.accent),
                    );
                  }
                  if (snap.hasError) {
                    return AppErrorState(
                      title: ku ? 'Tabloya barnekirî' : 'Liderlik yüklenemedi',
                      message: ku
                          ? 'Girêdanê kontrol bike û dîsa bicerib.'
                          : 'Bağlantıyı kontrol edip tekrar dene.',
                      retryLabel: ku ? 'Dîsa Bicerib' : 'Tekrar Dene',
                      onRetry: _refresh,
                    );
                  }
                  final entries = snap.data ?? [];
                  if (entries.isEmpty) {
                    return AppEmptyState(
                      icon: Icons.emoji_events_outlined,
                      title: ku ? 'Hîn xal tune' : 'Henüz puan yok',
                      message: ku
                          ? 'Pêşbirkekê dest pê bike; xalên te piştî lîstinê li vir xuya dibin.'
                          : 'Bir yarış başlat; puanların oynadıktan sonra burada görünür.',
                      actionLabel: ku
                          ? 'Pêşbirkê Dest Pê Bike'
                          : 'Yarışa Başla',
                      actionIcon: Icons.bolt_rounded,
                      onAction: _startQuickRace,
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _Podium(entries: entries.take(3).toList(), isKu: ku),
                      const SizedBox(height: 16),
                      for (final e in entries.skip(3))
                        _RankRow(entry: e, isKu: ku),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.entries, required this.isKu});

  final List<LeaderboardEntry> entries;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final first = entries.isNotEmpty ? entries[0] : null;
    final second = entries.length > 1 ? entries[1] : null;
    final third = entries.length > 2 ? entries[2] : null;

    return AppPanel(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E2A45), Color(0xFF243357)],
      ),
      child: Column(
        children: [
          Text(
            isKu ? 'Sê Pêşderian' : 'İlk 3',
            style: const TextStyle(
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (second != null)
                Expanded(child: _PodiumSlot(entry: second, height: 80)),
              if (first != null)
                Expanded(child: _PodiumSlot(entry: first, height: 110)),
              if (third != null)
                Expanded(child: _PodiumSlot(entry: third, height: 60)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.entry, required this.height});

  final LeaderboardEntry entry;
  final double height;

  static const _medals = {1: '🥇', 2: '🥈', 3: '🥉'};
  static const _colors = {
    1: Color(0xFFFFB800),
    2: Color(0xFF7C8794),
    3: Color(0xFFB66A3A),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[entry.rank] ?? AppTheme.accent;
    final medal = _medals[entry.rank] ?? '${entry.rank}';

    return Column(
      children: [
        Text(medal, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 6),
        CircleAvatar(
          radius: 22,
          backgroundColor: color.withValues(alpha: 0.2),
          child: Text(
            entry.displayName.isNotEmpty
                ? entry.displayName[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          entry.displayName,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        Text(
          '${entry.totalScore}',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              top: BorderSide(color: color.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.entry, required this.isKu});

  final LeaderboardEntry entry;
  final bool isKu;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHi,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry.roomsPlayed} ${isKu ? "jûr" : "oda"} · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalScore}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
