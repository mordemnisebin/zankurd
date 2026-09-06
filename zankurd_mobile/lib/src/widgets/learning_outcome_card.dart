import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/answer_record.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_panel.dart';

class LearningOutcome {
  const LearningOutcome({
    required this.strongestCategory,
    required this.strongestCorrect,
    required this.strongestAnswered,
    required this.reviewCategory,
    required this.reviewWrong,
    required this.reviewAnswered,
    required this.reviewRecords,
    required this.answered,
    required this.correct,
    required this.unanswered,
  });

  factory LearningOutcome.fromRecords(List<AnswerRecord> records) {
    final stats = <String, _TopicStats>{};
    final wrongRecords = <AnswerRecord>[];
    var answered = 0;
    var correct = 0;
    var unanswered = 0;

    for (final record in records) {
      if (record.isUnanswered) {
        unanswered++;
        continue;
      }
      answered++;
      if (record.isCorrect) correct++;
      if (!record.isCorrect) wrongRecords.add(record);
      final category = record.category.trim();
      if (category.isEmpty) continue;
      final current = stats[category] ?? const _TopicStats();
      stats[category] = current.add(record.isCorrect);
    }

    MapEntry<String, _TopicStats>? strongest;
    MapEntry<String, _TopicStats>? review;
    for (final entry in stats.entries) {
      final value = entry.value;
      if (value.answered >= 2 &&
          value.correct >= 2 &&
          value.correct / value.answered >= 0.75 &&
          (strongest == null ||
              value.correct / value.answered >
                  strongest.value.correct / strongest.value.answered ||
              (value.correct / value.answered ==
                      strongest.value.correct / strongest.value.answered &&
                  value.answered > strongest.value.answered))) {
        strongest = entry;
      }
      if (value.answered >= 2 &&
          value.wrong > 0 &&
          value.wrong / value.answered >= 0.5 &&
          (review == null ||
              value.wrong > review.value.wrong ||
              (value.wrong == review.value.wrong &&
                  value.wrong / value.answered >
                      review.value.wrong / review.value.answered))) {
        review = entry;
      }
    }

    final selectedWrong = review == null
        ? wrongRecords
        : wrongRecords
              .where((record) => record.category.trim() == review!.key)
              .toList(growable: false);

    return LearningOutcome(
      strongestCategory: strongest?.key,
      strongestCorrect: strongest?.value.correct ?? 0,
      strongestAnswered: strongest?.value.answered ?? 0,
      reviewCategory: review?.key,
      reviewWrong: review?.value.wrong ?? 0,
      reviewAnswered: review?.value.answered ?? 0,
      reviewRecords: selectedWrong,
      answered: answered,
      correct: correct,
      unanswered: unanswered,
    );
  }

  final String? strongestCategory;
  final int strongestCorrect;
  final int strongestAnswered;
  final String? reviewCategory;
  final int reviewWrong;
  final int reviewAnswered;
  final List<AnswerRecord> reviewRecords;
  final int answered;
  final int correct;
  final int unanswered;
}

class _TopicStats {
  const _TopicStats({this.correct = 0, this.wrong = 0});

  final int correct;
  final int wrong;
  int get answered => correct + wrong;

  _TopicStats add(bool isCorrect) => _TopicStats(
    correct: correct + (isCorrect ? 1 : 0),
    wrong: wrong + (isCorrect ? 0 : 1),
  );
}

class LearningOutcomeCard extends StatelessWidget {
  const LearningOutcomeCard({
    required this.outcome,
    required this.onReview,
    super.key,
  });

  final LearningOutcome outcome;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final isKu = context.isKu;
    final strongest = outcome.strongestCategory;
    final review = outcome.reviewCategory;
    final strongestName = strongest == null
        ? null
        : CategoryNames.localized(strongest, isKu);
    final reviewName = review == null
        ? null
        : CategoryNames.localized(review, isKu);

    return AppPanel(
      key: const ValueKey('learning-outcome-card'),
      cardType: CardType.info,
      color: AppColors.iconTileBg(context, AppTheme.cyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.lightbulb,
                color: AppColors.readableAccent(context, AppTheme.cyan),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.t(K.outcomeTitle),
                  style: AppTypography.subtitle.copyWith(
                    color: AppTheme.textPrimaryColor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            context.t(K.outcomeCounts, {
              'answered': '${outcome.answered}',
              'correct': '${outcome.correct}',
              'wrong': '${outcome.answered - outcome.correct}',
            }),
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          if (outcome.unanswered > 0) ...[
            const SizedBox(height: 4),
            Text(
              context.t(K.outcomeUnanswered, {
                'count': '${outcome.unanswered}',
              }),
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textSubColor(context),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (strongestName != null)
            _OutcomeLine(
              icon: AppIcons.circleCheck,
              color: AppTheme.correct,
              text: context.t(K.outcomeStrong, {
                'name': strongestName,
                'answered': '${outcome.strongestAnswered}',
                'correct': '${outcome.strongestCorrect}',
              }),
            ),
          if (strongestName != null && reviewName != null)
            const SizedBox(height: 8),
          if (reviewName != null)
            _OutcomeLine(
              icon: AppIcons.bullseye,
              color: AppTheme.gold,
              text: context.t(K.outcomeReview, {
                'name': reviewName,
                'answered': '${outcome.reviewAnswered}',
                'wrong': '${outcome.reviewWrong}',
              }),
            ),
          if (strongestName == null && reviewName == null)
            Text(
              context.t(K.outcomeEmpty),
              style: AppTypography.bodyMedium.copyWith(
                color: AppTheme.textSubColor(context),
                height: 1.4,
              ),
            ),
          if (outcome.reviewRecords.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('learning-outcome-review'),
                onPressed: onReview,
                icon: const Icon(AppIcons.bookOpen, size: 18),
                label: Text(
                  reviewName == null
                      ? context.t(K.outcomeReviewGeneric)
                      : context.t(K.outcomeReviewNamed, {'name': reviewName}),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeLine extends StatelessWidget {
  const _OutcomeLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Icon(icon, size: 17, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: AppTypography.bodyMedium.copyWith(
            color: AppTheme.textSubColor(context),
            height: 1.4,
          ),
        ),
      ),
    ],
  );
}
