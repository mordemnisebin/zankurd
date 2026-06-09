import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/answer_record.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import 'leaderboard_screen.dart';
import 'review_screen.dart';

class QuizResultScreen extends StatelessWidget {
  const QuizResultScreen({
    required this.repository,
    required this.room,
    required this.score,
    required this.correctCount,
    required this.wrongCount,
    required this.totalQuestions,
    required this.bestStreak,
    required this.answerRecords,
    required this.coinsAwarded,
    super.key,
  });

  final ZanKurdRepository repository;
  final GameRoom room;
  final int score;
  final int correctCount;
  final int wrongCount;
  final int totalQuestions;
  final int bestStreak;
  final List<AnswerRecord> answerRecords;
  final int coinsAwarded;

  @override
  Widget build(BuildContext context) {
    final unanswered = (totalQuestions - correctCount - wrongCount).clamp(
      0,
      totalQuestions,
    );
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.s('Encam', 'Sonuç'))),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              AppPanel(
                gradient: AppTheme.accentGradient,
                child: Stack(
                  children: [
                    Positioned(
                      right: -26,
                      top: -32,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.flag_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.s('Pêşbirk qediya', 'Yarış tamamlandı'),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$score',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 52,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${CategoryNames.localized(room.category, context.isKu)} · ${room.code}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            context.s(
                              'Rastbûn: %$accuracy',
                              'Doğruluk: %$accuracy',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _ResultMetrics(
                correctCount: correctCount,
                wrongCount: wrongCount,
                unanswered: unanswered,
                bestStreak: bestStreak,
              ),
              const SizedBox(height: 16),
              if (coinsAwarded > 0) ...[
                AppPanel(
                  gradient: AppTheme.goldGradient,
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.monetization_on_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.s(
                                '+$coinsAwarded coin stendî',
                                '+$coinsAwarded coin kazandın',
                              ),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              context.s(
                                'Xelata te di malperê de tê nûkirin.',
                                'Ödül bakiyen ana ekranda güncellenir.',
                              ),
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AppPanel(
                color: AppTheme.surfaceHi,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.s('Rêzbendiyê bişopîne', 'Sıralamaya devam et'),
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.s(
                        'Pûanên te li jûrên online di tabloya pêşderçûnê de xuya dibin.',
                        'Puanların online odalarda liderlik tablosuna yansır.',
                      ),
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: answerRecords.isEmpty
                            ? null
                            : () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReviewScreen(
                                      records: answerRecords,
                                      room: room,
                                    ),
                                  ),
                                );
                              },
                        icon: const Icon(Icons.fact_check_outlined),
                        label: Text(
                          context.s('Bersivan Bibîne', 'Cevapları İncele'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LeaderboardScreen(repository: repository),
                            ),
                          );
                        },
                        icon: const Icon(Icons.emoji_events_outlined),
                        label: Text(
                          context.s('Tabloya Pêşderçûnê', 'Liderlik Tablosu'),
                        ),
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
                        label: Text(context.s('Vegere malê', 'Ana ekrana dön')),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
          label: context.s('Rast', 'Doğru'),
          value: '$correctCount',
          color: AppTheme.correct,
        ),
        _MetricTile(
          icon: Icons.cancel_outlined,
          label: context.s('Şaş', 'Yanlış'),
          value: '$wrongCount',
          color: AppTheme.wrong,
        ),
        _MetricTile(
          icon: Icons.hourglass_empty_rounded,
          label: context.s('Vala', 'Boş'),
          value: '$unanswered',
          color: AppTheme.gold,
        ),
        _MetricTile(
          icon: Icons.local_fire_department_outlined,
          label: context.s('Rêza herî baş', 'En iyi seri'),
          value: '$bestStreak',
          color: AppTheme.violet,
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
        color: AppTheme.surfaceHi,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}
