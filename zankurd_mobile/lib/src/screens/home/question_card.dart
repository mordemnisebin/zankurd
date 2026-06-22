import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
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
              Expanded(
                child: _Tag(
                  label: CategoryNames.localized(question.category, isKu),
                  color: AppTheme.violet,
                ),
              ),
              const SizedBox(width: 8),
              _Tag(
                label: isKu ? '08 çirke' : '08 sn',
                color: AppTheme.textMutedColor(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            question.promptText,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
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
              icon: Icon(Icons.quiz_outlined),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color == AppTheme.textMuted
              ? AppTheme.textMutedColor(context)
              : color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
