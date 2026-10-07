import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/quiz_question.dart';
import '../../theme/app_icons.dart';
import '../../utils/free_text_answer_matcher.dart';
import '../../widgets/sahne/sahne.dart';

/// Boşluk doldurma soruları için erişilebilir serbest metin alanı.
///
/// Şahnê: giriş alanı temanın Kulis alanıdır (M pah); diyakritik tuşları
/// Kulis tonlu 48'lik M pahlı karolar; "Kontrol et" cevaptan önce ekranın
/// TEK birincil eylemidir (Agir, temanın `FilledButton`ı — anahtarı
/// düğmenin kendisinde durur, testler onu `FilledButton` olarak okur).
/// Sonuç satırı durum notudur: Rast/Şaş ton zemini + ✓/ℹ ikonu + söz.
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
    final t = SahneTokens.of(context);
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
        SahneField(
          key: const ValueKey('fill-in-blank-input'),
          controller: _controller,
          enabled: !widget.disabled,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => _submit(),
          inputTextStyle: SahneType.bodyStrong,
          hintText: label,
          semanticLabel: label,
          prefixIcon: AppIcons.pen,
        ),
        if (!widget.disabled) ...[
          const SizedBox(height: SahneSpace.x3),
          _DiacriticRow(onInsert: _insert),
          const SizedBox(height: SahneSpace.x4),
          FilledButton(
            key: const ValueKey('fill-in-blank-submit'),
            onPressed: canSubmit ? _submit : null,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: Text(Tr.forKu(K.kontrolEt, isKu)),
          ),
        ],
        // Süre dolunca doğru cevabı zaten `QuizTimeoutNotice` yazıyor
        // ("Dem qediya. Bersiv: X"); buradaki kutu da aynı cevabı yazınca
        // iki bant üst üste aynı sözü söylüyordu (2026-09-30 canlı).
        if (widget.showResult && widget.selectedAnswer != 'TIMEOUT') ...[
          const SizedBox(height: SahneSpace.x3),
          Semantics(
            liveRegion: true,
            label: resultText,
            excludeSemantics: true,
            child: DecoratedBox(
              key: const ValueKey('fill-in-blank-result'),
              decoration: ShapeDecoration(
                color: isCorrect ? t.okTint : t.errTint,
                shape: SahneShape.l,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SahneSpace.x3,
                  SahneSpace.x3,
                  SahneSpace.x4,
                  SahneSpace.x3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isCorrect ? AppIcons.check : AppIcons.circleInfo,
                      color: isCorrect ? t.okTx : t.errTx,
                      size: 24,
                    ),
                    const SizedBox(width: SahneSpace.x3),
                    Expanded(
                      child: Text(
                        resultText,
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kurmancî'ye özgü harfleri girişe ekleyen sıra: ç ş ê î û.
///
/// Kabul listesi (`acceptedAnswers`) `miroveki` yazanı doğru sayar ama
/// oyuncuya doğru YAZIMI hiç göstermez. Bu sıra tersini yapar: harf bir
/// dokunuş uzağa gelir, oyuncu `mirovekî` yazar ve kanonik biçimi bir kez
/// daha görür. İkisi birlikte çalışır — biri hakkı teslim eder, öteki öğretir.
///
/// `ç` ve `ş` 2026-10-07'de eklendi: telefondaki klavye Türkçe değilse
/// (ya da İngilizce/Kürtçe düzenli ise) ikisi de bir uzun basışın arkasında;
/// QA'da yalnız î ê û görünce `ç`/`ş` içeren cevaplar (ör. `çiya`, `şev`)
/// yazılamaz sanıldı. Bu satır artık Kurmancî alfabesinin klavyede zor
/// ulaşılan beş harfini birden verir.
class _DiacriticRow extends StatelessWidget {
  const _DiacriticRow({required this.onInsert});

  static const letters = ['ç', 'ş', 'ê', 'î', 'û'];

  final ValueChanged<String> onInsert;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return Row(
      children: [
        for (final letter in letters)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: SahneSpace.x2),
            child: Semantics(
              button: true,
              label: letter,
              onTap: () => onInsert(letter),
              excludeSemantics: true,
              child: SahnePressSink(
                enabled: true,
                child: SahneTappable(
                  key: ValueKey('fill-in-blank-diacritic-$letter'),
                  shape: SahneShape.m,
                  color: t.s2,
                  onTap: () => onInsert(letter),
                  // Android dokunma hedefi alt sınırı: en az 48×48 dp.
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Text(
                        letter,
                        style: SahneType.button.copyWith(color: t.tx),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
