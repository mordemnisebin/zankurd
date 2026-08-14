import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import '../utils/percent_format.dart';

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
          colors: [AppTheme.culturalBrandBg, AppTheme.culturalBrandBg],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Marka
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(AppIcons.question, color: AppTheme.gold, size: 26),
              SizedBox(width: 8),
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
            Tr.forKu(K.kurmancBilgiYarismasi, isKu),
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
            Tr.forKu(K.puan, isKu),
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
              _stat('$correctCount/$totalQuestions', Tr.forKu(K.correct, isKu)),
              _stat(
                PercentFormat.value(accuracy, isKu: isKu),
                Tr.forKu(K.isabet, isKu),
              ),
              _stat('$bestStreak', Tr.forKu(K.seri2, isKu)),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.badge),
            ),
            child: Text(
              // `category` çağırandan Kurmancî kimlik olarak gelir (bkz.
              // `CategoryNames`); paylaşım kartı Türkçe modda ham kimliği
              // basıyordu, kartı gören herkes görüyordu (2026-08-14
              // denetimi).
              CategoryNames.localized(category, isKu),
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
            Tr.forKu(K.senDeOynaPlay, isKu),
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
