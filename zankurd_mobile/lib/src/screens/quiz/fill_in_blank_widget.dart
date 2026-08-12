import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/quiz_question.dart';
import '../../theme/app_theme.dart';
import '../../utils/free_text_answer_matcher.dart';

/// Boşluk doldurma soruları için erişilebilir serbest metin alanı.
class FillInBlankWidget extends StatefulWidget {
  const FillInBlankWidget({
    super.key,
    required this.question,
    required this.disabled,
    required this.showResult,
    required this.onAnswerSubmitted,
    this.adjudicatedCorrect,
    this.excludedAnswer,
    this.selectedAnswer,
  });

  final QuizQuestion question;
  final bool disabled;
  final bool showResult;
  final bool? adjudicatedCorrect;
  final String? excludedAnswer;
  final ValueChanged<String> onAnswerSubmitted;
  final String? selectedAnswer;

  @override
  State<FillInBlankWidget> createState() => _FillInBlankWidgetState();
}

class _FillInBlankWidgetState extends State<FillInBlankWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.selectedAnswer ?? '')
      ..addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant FillInBlankWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) {
      _controller.text = widget.selectedAnswer ?? '';
    } else if (oldWidget.excludedAnswer != widget.excludedAnswer &&
        widget.excludedAnswer?.isNotEmpty == true) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSubmit {
    final answer = _controller.text.trim();
    if (widget.disabled || answer.isEmpty) return false;
    final excludedAnswer = widget.excludedAnswer?.trim();
    if (excludedAnswer == null || excludedAnswer.isEmpty) return true;
    final isTurkish = widget.question.answerLanguage == AnswerLanguage.turkish;
    return normalizeFreeTextAnswer(answer, isTurkish: isTurkish) !=
        normalizeFreeTextAnswer(excludedAnswer, isTurkish: isTurkish);
  }

  void _submit() {
    if (!_canSubmit) return;
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onAnswerSubmitted(_controller.text.trim());
  }

  /// İmleç neredeyse oraya bir harf yazar ve imleci harften sonraya taşır.
  ///
  /// Seçili bir aralık varsa onun yerine geçer; böylece harf düğmesi
  /// klavyedeki bir tuştan ayırt edilemez davranır.
  void _insert(String letter) {
    if (widget.disabled) return;
    final value = _controller.value;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final text = value.text.replaceRange(
      selection.start,
      selection.end,
      letter,
    );
    _controller.value = value.copyWith(
      text: text,
      selection: TextSelection.collapsed(
        offset: selection.start + letter.length,
      ),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKu = LangContext(context).isKu;
    final label = Tr.forKu(K.answerLabel, isKu);
    final canSubmit = _canSubmit;
    final submittedAnswer = widget.selectedAnswer ?? _controller.text;
    final isCorrect =
        widget.adjudicatedCorrect ??
        widget.question.acceptsAnswer(submittedAnswer);
    final usesCanonicalWriting =
        normalizeFreeTextAnswer(submittedAnswer) ==
        normalizeFreeTextAnswer(widget.question.correctAnswer);
    final resultColor = isCorrect ? AppTheme.correct : AppTheme.wrong;
    final resultText = isCorrect
        ? usesCanonicalWriting
              ? Tr.forKu(K.correct, isKu)
              : '${Tr.forKu(K.correct, isKu)}: '
                    '${widget.question.correctAnswer}'
        : '${Tr.forKu(K.correctAnswerLabel, isKu)}: '
              '${widget.question.correctAnswer}';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('fill-in-blank-input'),
          controller: _controller,
          enabled: !widget.disabled,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: label,
            hintText: label,
            prefixIcon: const Icon(Icons.edit_rounded),
          ),
        ),
        if (!widget.disabled) ...[
          const SizedBox(height: AppSpacing.sm),
          _DiacriticRow(onInsert: _insert),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const ValueKey('fill-in-blank-submit'),
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryCtaColor(context),
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.disabledSurface(context),
              disabledForegroundColor: AppTheme.textMutedColor(context),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              Tr.forKu(K.kontrolEt, isKu),
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
        if (widget.showResult) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            liveRegion: true,
            label: resultText,
            excludeSemantics: true,
            child: Container(
              key: const ValueKey('fill-in-blank-result'),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: resultColor.withValues(alpha: 0.55)),
              ),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                    color: resultColor,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      resultText,
                      style: AppTypography.bodyLarge.copyWith(
                        color: resultColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Türkçe klavyede bulunmayan üç Kurmancî sesliyi girişe ekleyen sıra.
///
/// Kabul listesi (`acceptedAnswers`) `miroveki` yazanı doğru sayar ama
/// oyuncuya doğru YAZIMI hiç göstermez. Bu sıra tersini yapar: harf bir
/// dokunuş uzağa gelir, oyuncu `mirovekî` yazar ve kanonik biçimi bir kez
/// daha görür. İkisi birlikte çalışır — biri hakkı teslim eder, öteki öğretir.
///
/// `ş` ve `ç` bilerek yok: Türkçe klavyede ikisi de var, sıraya eklemek
/// gerçekten eksik olan üçünü seyreltirdi.
class _DiacriticRow extends StatelessWidget {
  const _DiacriticRow({required this.onInsert});

  static const letters = ['î', 'ê', 'û'];

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final letter in letters)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: OutlinedButton(
              key: ValueKey('fill-in-blank-diacritic-$letter'),
              onPressed: () => onInsert(letter),
              style: OutlinedButton.styleFrom(
                // 44pt, dokunma hedefi için en küçük saygılı ölçü.
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
                foregroundColor: AppTheme.textPrimaryColor(context),
                side: BorderSide(color: AppTheme.borderColor(context)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              child: Text(
                letter,
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
