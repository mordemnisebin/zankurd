import 'package:flutter/material.dart';

import '../l10n/explanation_ku.dart';
import '../l10n/lang.dart';
import '../models/answer_record.dart';
import '../models/room.dart';
import '../theme/app_theme.dart';
import '../widgets/app_panel.dart';
import '../widgets/app_state.dart';
import '../widgets/screen_identity_header.dart';

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
      appBar: AppBar(title: Text(context.s('Bersiv', 'Cevaplar'))),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          child: records.isEmpty
              ? AppEmptyState(
                  icon: Icons.checklist_outlined,
                  title: context.s(
                    'Tu bersiv tune ne.',
                    'Hiç cevap kaydı yok.',
                  ),
                  message: context.s(
                    'Pirsên çareserkirî dê li vir xuya bibin.',
                    'Çözülen sorular burada görünecektir.',
                  ),
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
                      title: context.s('Xulase', 'Özet'),
                      subtitle: context.s(
                        '$correct rast · $wrong şaş · $empty vala',
                        '$correct doğru · $wrong yanlış · $empty boş',
                      ),
                      accent: AppTheme.cyan,
                      icon: Icons.checklist_rounded,
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
            icon: Icons.check_circle_outline,
            value: '$correct',
            label: context.s('Rast', 'Doğru'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            color: AppTheme.wrong,
            icon: Icons.cancel_outlined,
            value: '$wrong',
            label: context.s('Şaş', 'Yanlış'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryTile(
            color: AppTheme.gold,
            icon: Icons.hourglass_empty_rounded,
            value: '$empty',
            label: context.s('Vala', 'Boş'),
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

    final Color headerColor;
    final IconData headerIcon;
    final String headerText;

    if (isUnanswered) {
      headerColor = AppTheme.gold;
      headerIcon = Icons.help_outline;
      headerText = context.s('VALA MA', 'BOŞ BIRAKILDI');
    } else if (isCorrect) {
      headerColor = AppTheme.correct;
      headerIcon = Icons.check_circle_outline;
      headerText = context.s('RAST', 'DOĞRU');
    } else {
      headerColor = AppTheme.wrong;
      headerIcon = Icons.cancel_outlined;
      headerText = context.s('ŞAŞ', 'YANLIŞ');
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
                Icon(headerIcon, color: headerColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  headerText,
                  style: TextStyle(
                    color: headerColor,
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
                    context.s('Pirs ${index + 1}', 'Soru ${index + 1}'),
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
                    textColor = AppTheme.correct;
                    icon = Icons.check;
                  } else if (isThisSelected) {
                    bgColor = AppTheme.wrong.withValues(alpha: 0.14);
                    textColor = AppTheme.wrong;
                    icon = Icons.close;
                  } else {
                    bgColor = AppTheme.surfaceHi;
                    textColor = AppTheme.textMuted;
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
                if (record.explanation.isNotEmpty) ...[
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
                        Icon(
                          Icons.lightbulb_outline,
                          color: Color(0xFFB794F6),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            context.isKu
                                ? explanationToKu(record.explanation)
                                : record.explanation,
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
