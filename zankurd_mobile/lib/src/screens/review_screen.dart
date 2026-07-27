import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/answer_record.dart';
import '../models/quiz_question.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({required this.records, required this.room, super.key});

  final List<AnswerRecord> records;
  final GameRoom room;

  @override
  Widget build(BuildContext context) {
    final correct = records.where((r) => r.isCorrect).length;
    final wrong = records.where((r) => !r.isCorrect && !r.isUnanswered).length;
    final empty = records.where((r) => r.isUnanswered).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(context.t(K.answersTitle))),
      body: Container(
        color: AppTheme.bgOf(context),
        child: SafeArea(
          child: records.isEmpty
              ? AppEmptyState(
                  icon: AppIcons.squareCheck,
                  title: context.t(K.answersEmptyTitle),
                  message: context.t(K.answersEmptyBody),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.lg,
                  ),
                  children: [
                    // Xwendin ailesi — camgöbeği kimlik (cevap inceleme).
                    // AppBar "Cevaplar" taşıyor; kart başlığı özet olsun.
                    ScreenIdentityHeader(
                      title: context.t(K.summaryTitle),
                      subtitle: context.t(K.reviewSummaryLine, {
                        'correct': '$correct',
                        'wrong': '$wrong',
                        'empty': '$empty',
                      }),
                      accent: AppTheme.cyan,
                      icon: AppIcons.squareCheck,
                      compact: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _SummaryStrip(correct: correct, wrong: wrong, empty: empty),
                    const SizedBox(height: 16),
                    for (var i = 0; i < records.length; i++) ...[
                      _ReviewCard(record: records[i], index: i),
                      if (i != records.length - 1) const SizedBox(height: 14),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.correct,
    required this.wrong,
    required this.empty,
  });

  final int correct;
  final int wrong;
  final int empty;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            color: AppTheme.correct,
            icon: AppIcons.circleCheck,
            value: '$correct',
            label: context.t(K.correct),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            color: AppTheme.wrong,
            icon: AppIcons.circleXmark,
            value: '$wrong',
            label: context.t(K.wrong),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            color: AppTheme.gold,
            icon: AppIcons.hourglass,
            value: '$empty',
            label: context.t(K.blank),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHiColor(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textMutedColor(context),
              fontSize: 12,
            ),
          ),
        ],
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
    // Yazılmış açıklama > override > şablon eleme > kural motoru.
    //
    // Burası doğrudan kural motoruna gidiyordu ve sorunun elle yazılmış
    // Kurmancî açıklamasını hiç görmüyordu: Kurmancî turda özet
    // "Şirove: <Türkçe cümle>" gösteriyordu. Motor yedektir, kaynak
    // değil (2026-07-27).
    final isKu = context.isKu;
    final authored = isKu ? record.explanationKu : record.explanationTr;
    final String explanationText =
        (authored != null &&
            authored.trim().isNotEmpty &&
            !isTemplateExplanation(authored))
        ? authored
        : resolveRawExplanation(
            id: record.id,
            explanation: record.explanation,
            isKu: isKu,
          );

    final Color headerColor;
    final IconData headerIcon;
    final String headerText;

    if (isUnanswered) {
      headerColor = AppTheme.gold;
      headerIcon = AppIcons.circleQuestion;
      headerText = context.t(K.blankBadge);
    } else if (isCorrect) {
      headerColor = AppTheme.correct;
      headerIcon = AppIcons.circleCheck;
      headerText = context.t(K.correctBadge);
    } else {
      headerColor = AppTheme.wrong;
      headerIcon = AppIcons.circleXmark;
      headerText = context.t(K.wrongBadge);
    }

    return AppPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor.withValues(alpha: 0.14),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Başlık şeridinin zemini rengin kendi %14'lük tonu; ham
                // renk orada okunmuyordu ("DOĞRU" 2.59:1, "YANLIŞ" 3.13:1).
                Icon(
                  headerIcon,
                  color: AppColors.onAccentTint(context, headerColor),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  headerText,
                  style: TextStyle(
                    color: AppColors.onAccentTint(context, headerColor),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgOf(context).withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    context.t(K.questionIndex, {'index': '${index + 1}'}),
                    style: TextStyle(
                      color: AppTheme.textSubColor(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
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
                        : CachedNetworkImage(
                            imageUrl: record.imageUrl!,
                            width: double.infinity,
                            height: 180,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: double.infinity,
                              height: 180,
                              color: AppTheme.surfaceHiColor(context),
                              alignment: Alignment.center,
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.brand.withValues(alpha: 0.7),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: double.infinity,
                              height: 180,
                              color: AppTheme.surfaceHiColor(context),
                              alignment: Alignment.center,
                              child: Icon(
                                AppIcons.image,
                                color: AppTheme.textMutedColor(context),
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  record.prompt,
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor(context),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                ...record.answers.map((answer) {
                  final isThisSelected = answer == record.selectedAnswer;
                  final isThisCorrect = answer == record.correctAnswer;

                  final Color bgColor;
                  final Color textColor;
                  IconData? icon;

                  if (isThisCorrect) {
                    bgColor = AppTheme.correct.withValues(alpha: 0.14);
                    // Ham yeşil kendi %14'lük tonunda 2.59:1 ölçüldü;
                    // doğru şık silik görünüyordu (2026-07-27).
                    textColor = AppColors.onAccentTint(
                      context,
                      AppTheme.correct,
                    );
                    icon = AppIcons.check;
                  } else if (isThisSelected) {
                    bgColor = AppTheme.wrong.withValues(alpha: 0.14);
                    textColor = AppColors.onAccentTint(context, AppTheme.wrong);
                    icon = AppIcons.xmark;
                  } else {
                    bgColor = AppTheme.surfaceHiColor(context);
                    textColor = AppTheme.textMutedColor(context);
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
                        color: icon != null
                            ? textColor
                            : AppTheme.borderColor(context),
                        width: icon != null ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            answer,
                            style: TextStyle(
                              color: icon != null
                                  ? textColor
                                  : AppTheme.textSubColor(context),
                              fontWeight: FontWeight.w600,
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
                if (explanationText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.violet.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          AppIcons.lightbulb,
                          color: AppTheme.violet,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            explanationText,
                            style: TextStyle(
                              color: AppTheme.textSubColor(context),
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
