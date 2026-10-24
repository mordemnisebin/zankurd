import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../theme/app_icons.dart';
import '../../widgets/sahne/sahne.dart';

/// Milisaniyeyi "3,2 sn" / "3,2 çirke" yazar (ondalık virgül: iki dilde de).
String asyncDuelSecondsLabel(BuildContext context, int ms) {
  final seconds = (ms / 1000).toStringAsFixed(1).replaceAll('.', ',');
  return '$seconds ${context.t(K.secondsShortUnit)}';
}

/// Düello sonucunun "soru soru karşılaştırma" bölümü (QuizClash / Trivia
/// Crack düzeni): her soru için kısa soru metni, doğru cevap, benim cevabım
/// (✓/✗ + süre) ve — görünürse — rakibin cevabı.
///
/// Rakip satırı yalnız sunucu verdiyse çizilir: engelli çiftte ya da rakip o
/// soruyu hiç oynamadıysa (hükmen) [AsyncDuelReviewQuestion.opponent] null
/// gelir ve satır YOKTUR — "yanlış" ile "hiç oynamadı" ayrı şeylerdir.
class AsyncDuelReviewSection extends StatelessWidget {
  const AsyncDuelReviewSection({
    required this.review,
    required this.opponentLabel,
    super.key,
  });

  final AsyncDuelReview review;

  /// Rakibin satırdaki adı (engelli çiftte genel "Rakip").
  final String opponentLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    if (review.questions.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('async-duel-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.asyncDuelReviewTitle)),
        if (review.opponentBlocked) ...[
          Text(
            context.t(K.asyncDuelReviewBlockedNote),
            key: const ValueKey('async-duel-review-blocked'),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
        ],
        SahneListGroup(
          dividerIndent: SahneSpace.x4,
          children: [
            for (final question in review.questions)
              AsyncDuelReviewRow(
                key: ValueKey('async-duel-review-row-${question.index}'),
                question: question,
                opponentLabel: opponentLabel,
              ),
          ],
        ),
      ],
    );
  }
}

/// Karşılaştırmanın tek sorusu. Durum yalnız renkle değil şekille de verilir
/// (✓ / ✗ / boş için ⧗) ve ekran okuyucuya söyleniyor.
class AsyncDuelReviewRow extends StatelessWidget {
  const AsyncDuelReviewRow({
    required this.question,
    required this.opponentLabel,
    super.key,
  });

  final AsyncDuelReviewQuestion question;
  final String opponentLabel;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final mine = question.mine;
    final opponent = question.opponent;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SahneSpace.x4,
        SahneSpace.x3,
        SahneSpace.x4,
        SahneSpace.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Soru kısa gösterilir: 2 satır, sonra "…". Tam metin zaten
          // oynarken görüldü; burada amaç cevapları yan yana okumaktır.
          Text(
            '${question.index + 1}. ${question.prompt}',
            key: ValueKey('async-duel-review-prompt-${question.index}'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            '${context.t(K.correctAnswerLabel)}: ${question.correctText}',
            key: ValueKey('async-duel-review-correct-${question.index}'),
            style: SahneType.captionStrong.copyWith(color: t.okTx),
          ),
          const SizedBox(height: SahneSpace.x2),
          _AnswerLine(
            key: ValueKey('async-duel-review-mine-${question.index}'),
            who: context.t(K.you),
            question: question,
            answer: mine,
          ),
          if (opponent != null) ...[
            const SizedBox(height: SahneSpace.x1),
            _AnswerLine(
              key: ValueKey('async-duel-review-opp-${question.index}'),
              who: opponentLabel,
              question: question,
              answer: opponent,
            ),
          ],
        ],
      ),
    );
  }
}

class _AnswerLine extends StatelessWidget {
  const _AnswerLine({
    required this.who,
    required this.question,
    required this.answer,
    super.key,
  });

  final String who;
  final AsyncDuelReviewQuestion question;
  final AsyncDuelReviewAnswer? answer;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final answer = this.answer;
    final IconData icon;
    final Color color;
    final String verdict;
    final String detail;
    if (answer == null) {
      icon = AppIcons.hourglass;
      color = t.tx2;
      verdict = context.t(K.blank);
      detail = context.t(K.asyncDuelReviewNoAnswer);
    } else if (answer.timedOut) {
      icon = AppIcons.xmark;
      color = t.errTx;
      verdict = context.t(K.wrong);
      detail = context.t(K.sureDoldu);
    } else {
      icon = answer.correct ? AppIcons.check : AppIcons.xmark;
      color = answer.correct ? t.okTx : t.errTx;
      verdict = context.t(answer.correct ? K.correct : K.wrong);
      detail =
          '${question.choiceText(answer)} · '
          '${asyncDuelSecondsLabel(context, answer.ms)}';
    }
    return Semantics(
      container: true,
      label: '$who: $detail, $verdict',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: SahneSpace.x2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: who,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                  TextSpan(
                    text: ' · $detail',
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
