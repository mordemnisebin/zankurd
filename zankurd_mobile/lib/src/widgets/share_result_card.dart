import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Paylaşım için sabit boyutlu, markalı sonuç kartı. RepaintBoundary ile
/// PNG'ye render edilip share_plus üzerinden paylaşılır.
class ShareResultCard extends StatelessWidget {
  const ShareResultCard({
    required this.isKu,
    required this.score,
    required this.correctCount,
    required this.totalQuestions,
    required this.bestStreak,
    required this.category,
    super.key,
  });

  final bool isKu;
  final int score;
  final int correctCount;
  final int totalQuestions;
  final int bestStreak;
  final String category;

  @override
  Widget build(BuildContext context) {
    final accuracy = totalQuestions == 0
        ? 0
        : ((correctCount / totalQuestions) * 100).round();

    return Container(
      width: 360,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Marka
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.quiz_rounded, color: AppTheme.gold, size: 26),
              const SizedBox(width: 8),
              Text(
                'ZanKurd',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isKu ? 'Pêşbirka Kurmancî' : 'Kurmancî Bilgi Yarışması',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 22),

          // Skor
          Text(
            '$score',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.gold,
              fontWeight: FontWeight.w800,
              fontSize: 64,
              height: 1.0,
            ),
          ),
          Text(
            isKu ? 'PÛAN' : 'PUAN',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 22),

          // İstatistik satırı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _stat('$correctCount/$totalQuestions', isKu ? 'Rast' : 'Doğru'),
              _stat('%$accuracy', isKu ? 'Rastî' : 'İsabet'),
              _stat('$bestStreak', isKu ? 'Rêz' : 'Seri'),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              category,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            isKu
                ? 'Tu jî bilîze — li Play Store\'ê "ZanKurd"'
                : 'Sen de oyna — Play Store\'da "ZanKurd"',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.gold.withValues(alpha: 0.9),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
