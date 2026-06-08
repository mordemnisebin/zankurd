import 'package:flutter/material.dart';

import '../models/answer_record.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({required this.records, required this.room, super.key});

  final List<AnswerRecord> records;
  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cevaplar')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: records.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final record = records[index];
          return _ReviewCard(record: record, index: index);
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.record, required this.index});

  final AnswerRecord record;
  final int index;

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = record.isCorrect;
    final bool isUnanswered = record.isUnanswered;

    Color headerColor;
    IconData headerIcon;
    String headerText;

    if (isUnanswered) {
      headerColor = Colors.orange;
      headerIcon = Icons.help_outline;
      headerText = 'BOŞ BIRAKILDI';
    } else if (isCorrect) {
      headerColor = AppTheme.green;
      headerIcon = Icons.check_circle_outline;
      headerText = 'DOĞRU';
    } else {
      headerColor = AppTheme.red;
      headerIcon = Icons.cancel_outlined;
      headerText = 'YANLIŞ';
    }

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(headerIcon, color: headerColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  headerText,
                  style: TextStyle(
                    color: headerColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Soru ${index + 1}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.hasImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: record.imageUrl!.startsWith('asset://')
                        ? Image.asset(
                            record.imageUrl!.replaceFirst('asset://', ''),
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          )
                        : Image.network(
                            record.imageUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  record.prompt,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                ...record.answers.map((answer) {
                  final isThisSelected = answer == record.selectedAnswer;
                  final isThisCorrect = answer == record.correctAnswer;

                  Color bgColor;
                  Color textColor;
                  IconData? icon;

                  if (isThisCorrect) {
                    bgColor = AppTheme.green.withValues(alpha: 0.15);
                    textColor = AppTheme.green;
                    icon = Icons.check;
                  } else if (isThisSelected && !isThisCorrect) {
                    bgColor = AppTheme.red.withValues(alpha: 0.15);
                    textColor = AppTheme.red;
                    icon = Icons.close;
                  } else {
                    bgColor = AppTheme.line;
                    textColor = AppTheme.muted;
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            (isThisCorrect ||
                                (isThisSelected && !isThisCorrect))
                            ? textColor
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            answer,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 8),
                          Icon(icon, color: textColor, size: 20),
                        ],
                      ],
                    ),
                  );
                }),
                if (record.explanation.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: AppTheme.green,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            record.explanation,
                            style: const TextStyle(
                              color: AppTheme.green,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
