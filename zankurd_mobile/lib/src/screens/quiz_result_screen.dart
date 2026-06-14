import 'package:flutter/material.dart';

import '../data/achievement_store.dart';
import '../data/mistake_store.dart';
import '../data/streak_store.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../models/achievement.dart';
import '../models/answer_record.dart';
import '../models/player.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
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
    required this.answerRecords,
    required this.coinsAwarded,
    this.opponents = const [],
    this.practice = false,
    this.dailyQuiz = false,
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

  /// Bot yarışındaki rakiplerin son durumu; boşsa panel gizlenir.
  final List<Player> opponents;
  final bool practice;
  final bool dailyQuiz;

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  ZanKurdRepository get repository => widget.repository;
  GameRoom get room => widget.room;
  int get score => widget.score;
  int get correctCount => widget.correctCount;
  int get wrongCount => widget.wrongCount;
  int get totalQuestions => widget.totalQuestions;
  int get bestStreak => widget.bestStreak;
  List<AnswerRecord> get answerRecords => widget.answerRecords;
  int get coinsAwarded => widget.coinsAwarded;
  List<Player> get opponents => widget.opponents;
  bool get practice => widget.practice;
  bool get dailyQuiz => widget.dailyQuiz;

  int _dailyStreak = 0;
  List<Achievement> _newAchievements = const [];

  @override
  void initState() {
    super.initState();
    _recordProgress();
  }

  Future<void> _recordProgress() async {
    final streakStore = await StreakStore.load();
    final streak = await streakStore.recordPlay();
    final mistakeStore = await MistakeStore.load();
    final achievementStore = await AchievementStore.load();
    final newAchievements = await achievementStore.recordQuizResult(
      category: room.category,
      totalQuestions: totalQuestions,
      correctCount: correctCount,
      bestStreak: bestStreak,
      dailyStreak: streak,
      userScore: score,
      practice: practice,
      dailyQuiz: dailyQuiz,
      remainingMistakes: mistakeStore.count,
      opponents: opponents,
    );
    if (mounted) {
      setState(() {
        _dailyStreak = streak;
        _newAchievements = newAchievements;
      });
    }
  }

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
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
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
              if (opponents.isNotEmpty) ...[
                const SizedBox(height: 16),
                _RaceStandings(userScore: score, opponents: opponents),
              ],
              if (_newAchievements.isNotEmpty) ...[
                const SizedBox(height: 16),
                _AchievementUnlocks(achievements: _newAchievements),
              ],
              if (_dailyStreak > 0) ...[
                const SizedBox(height: 16),
                AppPanel(
                  color: AppTheme.surfaceHi,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: AppTheme.accent,
                        size: 30,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.s(
                                'Seriya rojane: $_dailyStreak roj',
                                'Günlük seri: $_dailyStreak gün',
                              ),
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.s(
                                'Sibê jî bilîze û seriyê bidomîne!',
                                'Yarın da oyna, seriyi sürdür!',
                              ),
                              style: const TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (coinsAwarded > 0) ...[
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, child) => Transform.scale(
                    scale: 0.92 + 0.08 * t,
                    child: Opacity(opacity: t, child: child),
                  ),
                  child: AppPanel(
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
                              TweenAnimationBuilder<int>(
                                tween: IntTween(begin: 0, end: coinsAwarded),
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOut,
                                builder: (context, value, _) => Text(
                                  context.s(
                                    '+$value coin stendî',
                                    '+$value coin kazandın',
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
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
                                  AppRoute.to(ReviewScreen(
                                    records: answerRecords,
                                    room: room,
                                  )),
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
                            AppRoute.to(LeaderboardScreen(repository: repository)),
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

class _RaceStandings extends StatelessWidget {
  const _RaceStandings({required this.userScore, required this.opponents});

  final int userScore;
  final List<Player> opponents;

  @override
  Widget build(BuildContext context) {
    final standings = [
      Player(name: context.s('Tu', 'Tu'), score: userScore, state: 'Player'),
      ...opponents,
    ]..sort((a, b) => b.score.compareTo(a.score));
    final userRank =
        standings.indexWhere((player) => player.state == 'Player') + 1;
    final leader = standings.first;
    final title = context.s(
      'Bi reqîban re beramber bike',
      'Rakiplerle Karşılaştırma',
    );
    final summary = leader.state == 'Player'
        ? context.s(
            'Te yarış di rêza $userRank. de qedand.',
            'Yarışı $userRank. sırada tamamladın.',
          )
        : context.s(
            '${leader.name} pêşî qediya; tu di rêza $userRank. de yî.',
            '${leader.name} önde bitirdi; sen $userRank. sıradasın.',
          );

    return AppPanel(
      color: AppTheme.surfaceHi,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_2_outlined, color: AppTheme.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(summary, style: const TextStyle(color: AppTheme.textMuted)),
          const SizedBox(height: 12),
          for (var i = 0; i < standings.length; i++)
            _RaceStandingRow(rank: i + 1, player: standings[i]),
        ],
      ),
    );
  }
}

class _AchievementUnlocks extends StatelessWidget {
  const _AchievementUnlocks({required this.achievements});

  final List<Achievement> achievements;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      gradient: AppTheme.goldGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_outlined, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                context.s('Rozeta Nû', 'Yeni Rozet'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final achievement in achievements)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(achievement.icon, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.title(context.isKu),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          achievement.description(context.isKu),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _RaceStandingRow extends StatelessWidget {
  const _RaceStandingRow({required this.rank, required this.player});

  final int rank;
  final Player player;

  @override
  Widget build(BuildContext context) {
    final isUser = player.state == 'Player';
    final color = isUser ? AppTheme.accent : AppTheme.gold;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUser
            ? AppTheme.accent.withValues(alpha: 0.12)
            : AppTheme.bgOf(context).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUser
              ? AppTheme.accent.withValues(alpha: 0.45)
              : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$rank',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              player.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          if (player.streak > 0) ...[
            const Icon(
              Icons.local_fire_department_outlined,
              color: AppTheme.gold,
              size: 18,
            ),
            const SizedBox(width: 4),
            Text(
              '${player.streak}',
              style: const TextStyle(
                color: AppTheme.gold,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            '${player.score}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
