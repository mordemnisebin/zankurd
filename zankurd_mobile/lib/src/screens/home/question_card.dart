import 'package:flutter/material.dart';

import '../../models/quiz_question.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_panel.dart';

class QuestionCard extends StatelessWidget {
  const QuestionCard({
    required this.question,
    required this.isKu,
    required this.onOpen,
    super.key,
  });

  final QuizQuestion question;
  final bool isKu;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tag(label: question.category, color: AppTheme.violet),
              const Spacer(),
              _Tag(
                label: isKu ? '08 çirke' : '08 sn',
                color: AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.prompt,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.quiz_outlined),
              label: Text(isKu ? 'Pirs Çareser Bike' : 'Soruyu Çöz'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == AppTheme.textMuted ? AppTheme.textMuted : color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
