import 'package:flutter/material.dart';

import '../../data/mastery_store.dart';
import '../../data/mistake_store.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_reporter.dart';
import '../../widgets/kilim_pattern_painter.dart';

/// "Senin İçin Önerilen" personalized recommendation card.
///
/// Detects the user's weakest category by combining:
/// - MistakeStore (high mistake counts = weakness)
/// - MasteryStore (low correct counts = less mastery)
///
/// Only appears when the user has played at least 5 quizzes (enough data).
/// Shows a tappable card with a "Hemen Çalış" button.
class RecommendationCard extends StatefulWidget {
  const RecommendationCard({
    required this.isKu,
    required this.onTapCategory,
    super.key,
  });

  final bool isKu;
  final void Function(String category) onTapCategory;

  @override
  State<RecommendationCard> createState() => _RecommendationCardState();
}

class _RecommendationCardState extends State<RecommendationCard> {
  String? _weakestCategory;
  String? _weakestCategoryTr;
  int? _totalAnswers;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyze();
  }

  Future<void> _analyze() async {
    try {
      final mistakeStore = await MistakeStore.load();
      final masteryStore = await MasteryStore.load();

      // Total answers from last 7 days (rough estimate)
      final history = mistakeStore.getLast7DaysHistory();
      int totalCorrect = 0;
      int totalWrong = 0;
      for (final day in history.values) {
        totalCorrect += day['correct'] ?? 0;
        totalWrong += day['wrong'] ?? 0;
      }
      final totalAnswers = totalCorrect + totalWrong;

      // Need at least 5 answers to make meaningful recommendations
      if (totalAnswers < 5) {
        if (!mounted) return;
        setState(() {
          _totalAnswers = totalAnswers;
          _loading = false;
        });
        return;
      }

      // Get weakness scores per category
      final mistakeCounts = mistakeStore.getMistakesCountByCategory();

      // Map of category -> weakness score (higher = weaker)
      // Score = mistakeCount * 2 + (100 - min(correctCount, 100)) / 5
      final Map<String, double> weaknessScores = {};

      // Known categories
      const allCategories = [
        'Ziman',
        'Çand',
        'Dîrok',
        'Edebiyat',
        'Cografya',
        'Muzîk',
        'Siyaset',
        'Paradigma',
      ];

      for (final cat in allCategories) {
        final mistakes = mistakeCounts[cat] ?? 0;
        final correct = masteryStore.correctCount(cat);
        final masteryDeficit = (100 - correct.clamp(0, 100)).toDouble();
        weaknessScores[cat] = mistakes * 2.0 + masteryDeficit / 5.0;
      }

      // Find the weakest category with at least some data
      String? weakestCat;
      double highestScore = 0;
      for (final entry in weaknessScores.entries) {
        if (entry.value > 0 && entry.value > highestScore) {
          highestScore = entry.value;
          weakestCat = entry.key;
        }
      }

      if (!mounted) return;
      setState(() {
        _totalAnswers = totalAnswers;
        _weakestCategory = weakestCat;
        _weakestCategoryTr = _trCategory(weakestCat);
        _loading = false;
      });
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'recommendation_card');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  static String _trCategory(String? kuCat) {
    return switch (kuCat) {
      'Ziman' => 'Dil',
      'Çand' => 'Kültür',
      'Dîrok' => 'Tarih',
      'Edebiyat' => 'Edebiyat',
      'Cografya' => 'Coğrafya',
      'Muzîk' => 'Müzik',
      'Siyaset' => 'Siyaset',
      'Paradigma' => 'Paradigma',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything while loading or if not enough data
    if (_loading) return const SizedBox.shrink();
    if (_weakestCategory == null) return const SizedBox.shrink();
    if (_totalAnswers == null || _totalAnswers! < 5) {
      return const SizedBox.shrink();
    }

    final isKu = widget.isKu;
    final catKu = _weakestCategory!;
    final catTr = _weakestCategoryTr!;
    final catLabel = isKu ? catKu : catTr;

    const accentColor = AppTheme.playPurple;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onTapCategory(catKu),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    accentColor.withValues(alpha: 0.14),
                    AppTheme.surfaceColor(context),
                  ),
                  Color.alphaBlend(
                    accentColor.withValues(alpha: 0.04),
                    AppTheme.surfaceColor(context),
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.30),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: KilimPatternPainter(
                        drawPattern: true,
                        color: accentColor,
                        opacity: 0.03,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section label
                    Row(
                      children: [
                        Container(
                          width: 3,
                          height: 14,
                          decoration: AppTheme.sectionAccent(accentColor),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isKu ? 'Ji Bo Te Pêşniyar' : 'Senin İçin Önerilen',
                          style: AppTypography.caption.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Recommendation message
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accentColor, AppTheme.playPink],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            isKu
                                ? '$catLabel kategorisinde pratik yapmak ister misin?'
                                : '$catLabel kategorisinde pratik yapmak ister misin?',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => widget.onTapCategory(catKu),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(
                          isKu ? 'Hema Bixebite' : 'Hemen Çalış',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
