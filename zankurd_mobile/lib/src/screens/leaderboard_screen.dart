import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/leaderboard_entry.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
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
      AppRoute.to(
        QuizScreen(
          repository: widget.repository,
          room: widget.repository.createRoom(),
          questions: raceQuestions,
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
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 26,
                          ),
                        ),
                        Text(
                          ku ? 'Baştirîn lîstikvan' : 'En iyi oyuncular',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _refresh,
                    icon: Icon(
                      Icons.refresh_rounded,
                      color: AppTheme.textSubColor(context),
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
            style: TextStyle(
              color: AppTheme.textSub,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (second != null) Expanded(child: _PodiumSlot(entry: second)),
              if (first != null) Expanded(child: _PodiumSlot(entry: first)),
              if (third != null) Expanded(child: _PodiumSlot(entry: third)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({required this.entry});

  final LeaderboardEntry entry;

  static const _colors = {
    1: Color(0xFFFFB800), // Altın
    2: Color(0xFF7C8794), // Gümüş
    3: Color(0xFFB66A3A), // Bronz
  };

  Widget _buildPodiumMedal(int rank, Color color) {
    if (rank == 1) {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Color(0x22FFB800),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.emoji_events, color: Color(0xFFFFB800), size: 26),
      );
    }
    return Icon(Icons.military_tech, color: color, size: 26);
  }

  @override
  Widget build(BuildContext context) {
    final color = _colors[entry.rank] ?? AppTheme.accent;

    return Column(
      children: [
        Container(
          key: ValueKey('podium-slot-${entry.rank}'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            children: [
              _buildPodiumMedal(entry.rank, color),
              const SizedBox(height: 6),
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.24),
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
                '#${entry.rank}',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                entry.displayName,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
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
                  fontSize: 13.5,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            offset: const Offset(0, 3),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.surfaceHiColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.borderColor(context),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                color: AppTheme.textSubColor(context),
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          CircleAvatar(
            radius: 19,
            backgroundColor: AppTheme.accent.withValues(alpha: 0.12),
            child: Text(
              entry.displayName.isNotEmpty
                  ? entry.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: AppTheme.accent,
                fontWeight: FontWeight.w900,
                fontSize: 15,
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
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 14.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.roomsPlayed} ${isKu ? "jûr" : "oda"} · ${entry.bestStreak} ${isKu ? "zincîr" : "seri"}',
                  style: TextStyle(
                    color: AppTheme.textMutedColor(context),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${entry.totalScore}',
            style: TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}
