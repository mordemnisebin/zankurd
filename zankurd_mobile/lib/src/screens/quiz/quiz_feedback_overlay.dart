import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_icons.dart';

/// Süre dolduğunda gösterilen geri bildirim bandı.
///
/// Şıklar zaten kilitlenir (answered=true); bu bant geri bildirimi
/// netleştirir: süre bitti + doğru cevap görünür.
class QuizTimeoutNotice extends StatelessWidget {
  const QuizTimeoutNotice({
    required this.isKu,
    required this.correctAnswer,
    super.key,
  });

  final bool isKu;
  final String correctAnswer;

  @override
  Widget build(BuildContext context) {
    final label = Tr.forKu(K.sureDolduDogruCevap, isKu, {'p0': correctAnswer});
    return Semantics(
      key: const ValueKey('quiz-timeout-notice'),
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.xs),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppTheme.wrong.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppTheme.wrong.withValues(alpha: 0.32)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ExcludeSemantics(
              child: Icon(AppIcons.stopwatch, color: AppTheme.wrong, size: 18),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textPrimaryColor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
