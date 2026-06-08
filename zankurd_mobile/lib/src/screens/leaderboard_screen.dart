import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../models/leaderboard_entry.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.repository, super.key});

  final ZanKurdRepository repository;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  late Future<List<LeaderboardEntry>> _leaderboardFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = widget.repository.loadLeaderboard();
  }

  void _refresh() {
    setState(() {
      _leaderboardFuture = widget.repository.loadLeaderboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liderlik Tablosu'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<LeaderboardEntry>>(
          future: _leaderboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _LoadingLeaderboard();
            }

            if (snapshot.hasError) {
              return _LeaderboardMessage(
                icon: Icons.error_outline,
                title: 'Liderlik yüklenemedi',
                message: 'Bağlantıyı kontrol edip tekrar dene.',
                onRetry: _refresh,
              );
            }

            final entries = snapshot.data ?? const [];
            if (entries.isEmpty) {
              return _LeaderboardMessage(
                icon: Icons.emoji_events_outlined,
                title: 'Henüz puan yok',
                message: 'İlk online yarıştan sonra sıralama burada görünür.',
                onRetry: _refresh,
              );
            }

            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                _LeaderboardHero(entries: entries),
                const SizedBox(height: 16),
                for (final entry in entries) _LeaderboardRow(entry: entry),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingLeaderboard extends StatelessWidget {
  const _LoadingLeaderboard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(18),
      child: AppPanel(
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Liderlik tablosu yükleniyor...')),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardHero extends StatelessWidget {
  const _LeaderboardHero({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final leader = entries.first;
    final totalPlayers = entries.length;

    return AppPanel(
      color: AppTheme.green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Haftanın zirvesi',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            leader.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 30,
              height: 1.06,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroMetric(label: 'Puan', value: '${leader.totalScore}'),
              _HeroMetric(label: 'En iyi seri', value: '${leader.bestStreak}'),
              _HeroMetric(label: 'Oyuncu', value: '$totalPlayers'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry});

  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final rankColor = switch (entry.rank) {
      1 => const Color(0xFFD49A2A),
      2 => const Color(0xFF7C8794),
      3 => const Color(0xFFB66A3A),
      _ => AppTheme.green,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: rankColor.withValues(alpha: 0.12),
            child: Text(
              '${entry.rank}',
              style: TextStyle(color: rankColor, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${entry.roomsPlayed} oda · ${entry.bestStreak} seri',
                  style: const TextStyle(color: AppTheme.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${entry.totalScore}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardMessage extends StatelessWidget {
  const _LeaderboardMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      children: [
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppTheme.green, size: 32),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 21,
                ),
              ),
              const SizedBox(height: 6),
              Text(message, style: const TextStyle(color: AppTheme.muted)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tekrar dene'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
