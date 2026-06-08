import 'package:flutter/material.dart';

import '../data/local_data_service.dart';
import '../data/zankurd_repository.dart';
import '../models/answer_record.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import 'leaderboard_screen.dart';
import 'review_screen.dart';

class QuizResultScreen extends StatefulWidget {
  const QuizResultScreen({
    required this.repository,
    required this.room,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.bestStreak,
    this.answerRecords,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int bestStreak;
  final List<AnswerRecord>? answerRecords;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  int _coinsEarned = 0;

  @override
  void initState() {
    super.initState();
    _applyRewards();
  }

  Future<void> _applyRewards() async {
    final local = await LocalDataService.getInstance();

    // Calculate coin reward: 10 coins per correct answer, max 200
    final coinReward = (widget.correctCount * 10).clamp(0, 200);

    // Apply to local storage
    await local.applyQuizResult(
      score: widget.score,
      correctCount: widget.correctCount,
      streak: widget.bestStreak,
    );

    if (mounted) {
      setState(() => _coinsEarned = coinReward);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unanswered = (widget.totalQuestions - widget.correctCount - widget.wrongCount).clamp(
      0,
      widget.totalQuestions,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sonuç')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          children: [
            AppPanel(
              color: AppTheme.green,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.flag_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Yarış tamamlandı',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${widget.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 48,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.room.category} · ${widget.room.code}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_coinsEarned > 0) ...[
              AppPanel(
                color: const Color(0xFFFFB800),
                child: Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Kazandığın Coinler',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '+$_coinsEarned',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _ResultMetrics(
              correctCount: widget.correctCount,
              wrongCount: widget.wrongCount,
              unanswered: unanswered,
              bestStreak: widget.bestStreak,
            ),
            const SizedBox(height: 16),
            if (widget.answerRecords != null && widget.answerRecords!.isNotEmpty) ...[
              AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.replay_outlined, color: AppTheme.green),
                        SizedBox(width: 8),
                        Text(
                          'Cevapları gözden geçir',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Her soruyu, senin cevabını ve doğru yanıtı incele.',
                      style: TextStyle(color: AppTheme.muted),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReviewScreen(
                                records: widget.answerRecords!,
                                room: widget.room,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('Cevapları Gör'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sıralamaya devam et',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Puanların online odalarda liderlik tablosuna yansır.',
                    style: TextStyle(color: AppTheme.muted),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                LeaderboardScreen(repository: widget.repository),
                          ),
                        );
                      },
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text('Liderlik Tablosu'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      },
                      icon: const Icon(Icons.home_outlined),
                      label: const Text('Ana ekrana dön'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultMetrics extends StatelessWidget {
  const _ResultMetrics({
    required this.correctCount,
    required this.wrongCount,
    required this.unanswered,
    required this.bestStreak,
  });

  final int correctCount;
  final int wrongCount;
  final int unanswered;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.55,
      children: [
        _MetricTile(
          icon: Icons.check_circle_outline,
          label: 'Doğru',
          value: '$correctCount',
          color: AppTheme.green,
        ),
        _MetricTile(
          icon: Icons.cancel_outlined,
          label: 'Yanlış',
          value: '$wrongCount',
          color: AppTheme.red,
        ),
        _MetricTile(
          icon: Icons.hourglass_empty_rounded,
          label: 'Boş',
          value: '$unanswered',
          color: const Color(0xFFBD7B2B),
        ),
        _MetricTile(
          icon: Icons.local_fire_department_outlined,
          label: 'En iyi seri',
          value: '$bestStreak',
          color: const Color(0xFF4059AD),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppTheme.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
          ),
          Text(label, style: const TextStyle(color: AppTheme.muted)),
        ],
      ),
    );
  }
}
