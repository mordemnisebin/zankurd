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
class AsyncDuelReviewSection extends StatefulWidget {
  const AsyncDuelReviewSection({
    required this.review,
    required this.opponentLabel,
    this.initiallyOpen = false,
    super.key,
  });

  final AsyncDuelReview review;

  /// Rakibin satırdaki adı (engelli çiftte genel "Rakip").
  final String opponentLabel;

  /// K7 (2026-10-28): karşılaştırma varsayılan KAPALI; "Cevapları gör" açar.
  final bool initiallyOpen;

  @override
  State<AsyncDuelReviewSection> createState() => _AsyncDuelReviewSectionState();
}

class _AsyncDuelReviewSectionState extends State<AsyncDuelReviewSection> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final review = widget.review;
    final opponentLabel = widget.opponentLabel;
    if (review.questions.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('async-duel-review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SahneSectionHeader(title: context.t(K.asyncDuelReviewTitle)),
        // Doğru/yanlış/boş dökümü: skor yalnız doğruyu söylüyordu.
        _AnswerSummaryLine(
          key: const ValueKey('async-duel-review-summary-me'),
          name: context.t(K.you),
          answers: [for (final q in review.questions) q.mine],
        ),
        if (!review.opponentBlocked &&
            review.questions.any((q) => q.opponent != null))
          _AnswerSummaryLine(
            key: const ValueKey('async-duel-review-summary-opp'),
            name: opponentLabel,
            answers: [for (final q in review.questions) q.opponent],
          ),
        const SizedBox(height: SahneSpace.x2),
        SahneButton.secondary(
          key: const ValueKey('async-duel-review-toggle'),
          label: context.t(_open ? K.hideAnswers : K.seeAnswers),
          icon: _open ? AppIcons.chevronUp : AppIcons.chevronDown,
          arrow: false,
          expand: true,
          onPressed: () => setState(() => _open = !_open),
        ),
        if (_open) ...[
          const SizedBox(height: SahneSpace.x3),
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
      ],
    );
  }
}

/// "Sen: 5 doğru · 1 yanlış · 1 boş" — cevapsız (null) ve süresi dolan boştur.
class _AnswerSummaryLine extends StatelessWidget {
  const _AnswerSummaryLine({
    required this.name,
    required this.answers,
    super.key,
  });

  final String name;
  final List<AsyncDuelReviewAnswer?> answers;

  @override
  Widget build(BuildContext context) {
    var correct = 0;
    var wrong = 0;
    var blank = 0;
    for (final a in answers) {
      if (a == null || a.timedOut) {
        blank++;
      } else if (a.correct) {
        correct++;
      } else {
        wrong++;
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: SahneSpace.x1),
      child: Text(
        context.t(K.asyncDuelAnswerSummary, {
          'name': name,
          'c': '$correct',
          'w': '$wrong',
          'b': '$blank',
        }),
        style: SahneType.caption.copyWith(color: SahneTokens.of(context).tx2),
      ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SahneType.bodyStrong.copyWith(color: t.tx),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            '${context.t(K.correctAnswerLabel)}: ${question.correctText}',
            key: ValueKey('async-duel-review-correct-${question.index}'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: SahneType.captionStrong.copyWith(color: t.okTx),
          ),
          const SizedBox(height: SahneSpace.x2),
          // K7: sen ve rakip TEK satırda yan yana (dar ekran / büyük yazıda
          // alt alta).
          LayoutBuilder(
            builder: (context, box) {
              final stacked =
                  opponent == null ||
                  box.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(14) > 16;
              final myLine = _AnswerLine(
                key: ValueKey('async-duel-review-mine-${question.index}'),
                who: context.t(K.you),
                question: question,
                answer: mine,
              );
              final oppLine = opponent == null
                  ? null
                  : _AnswerLine(
                      key: ValueKey('async-duel-review-opp-${question.index}'),
                      who: opponentLabel,
                      question: question,
                      answer: opponent,
                    );
              if (stacked || oppLine == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    myLine,
                    if (oppLine != null) ...[
                      const SizedBox(height: SahneSpace.x1),
                      oppLine,
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: myLine),
                  const SizedBox(width: SahneSpace.x3),
                  Expanded(child: oppLine),
                ],
              );
            },
          ),
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
