import 'package:flutter/material.dart';

import '../../models/quiz_question.dart';
import '../../utils/question_prompt_parser.dart';
import '../../widgets/lexicon_lookup.dart';
import '../../widgets/sahne/sahne.dart';
import 'quiz_option_tile.dart';

/// Boşluk doldurma ve kelime sıralama sorusunun başlığı.
///
/// Tek satıra sıkışmış `Yönerge: "cümle" ("çeviri")` metnini dört role
/// ayırır: küçük yönerge satırı, büyük ana cümle (boşluk vurgulu), ipucu
/// ve soluk çeviri. Kalıba uymayan metin için `null` döner; çağıran eski
/// [QuizQuestionPrompt]u çizer ([QuestionPromptBlock.tryBuild]).
///
/// Kelime sıralamada tırnak içi cümle Türkçe kaynaktır (oyuncu onu
/// Kurmancîye kurar); arayüz Kurmancî olsa da ayrı bir kutuda "TR → KU"
/// rozetiyle durur. Rozet bir dil kodudur, çevrilecek bir dize değildir.
class QuestionPromptBlock extends StatelessWidget {
  const QuestionPromptBlock({
    super.key,
    required this.parts,
    required this.question,
    this.lexicon = LexiconTapPolicy.off,
    this.forceHeadline = false,
    this.titleLineBudget = QuizQuestionPrompt.maxTitleLines,
  });

  final QuestionPromptParts parts;
  final QuizQuestion question;
  final LexiconTapPolicy lexicon;
  final bool forceHeadline;
  final int titleLineBudget;

  /// Bu tür ve metin için blok çizilebiliyorsa onu, yoksa `null` verir.
  static QuestionPromptBlock? tryBuild({
    required QuizQuestion question,
    required String promptText,
    LexiconTapPolicy lexicon = LexiconTapPolicy.off,
    bool forceHeadline = false,
    int titleLineBudget = QuizQuestionPrompt.maxTitleLines,
  }) {
    if (question.type != QuestionType.fillInBlank &&
        question.type != QuestionType.wordOrdering) {
      return null;
    }
    final parts = parseQuestionPrompt(promptText);
    if (parts == null) return null;
    return QuestionPromptBlock(
      parts: parts,
      question: question,
      lexicon: lexicon,
      forceHeadline: forceHeadline,
      titleLineBudget: titleLineBudget,
    );
  }

  bool get _isOrdering => question.type == QuestionType.wordOrdering;

  bool get _turkishSource =>
      _isOrdering && isTurkishSourceSentence(parts.main, question.answers);

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final hint = parts.hint;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts.instruction,
          key: const ValueKey('prompt-instruction'),
          style: SahneType.caption.copyWith(color: t.tx2),
        ),
        const SizedBox(height: SahneSpace.x2),
        if (_turkishSource)
          _SourceBox(
            badge: const SahneBadge(
              key: ValueKey('prompt-source-badge'),
              label: 'TR → KU',
              tone: SahneBadgeTone.soon,
            ),
            child: _mainSentence(context, t),
          )
        else
          _mainSentence(context, t),
        if (hint != null) ...[
          const SizedBox(height: SahneSpace.x2),
          Text(
            hint,
            key: const ValueKey('prompt-hint'),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
        ],
        if (parts.translation != null) ...[
          const SizedBox(height: SahneSpace.x2),
          Text(
            parts.translation!,
            key: const ValueKey('prompt-translation'),
            // tx2: ikincil ama 4,5:1 üstü; tx3'e inilmez.
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ],
      ],
    );
  }

  Widget _mainSentence(BuildContext context, SahneTokens t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final style = QuizQuestionPrompt.styleFor(
          context,
          parts.main,
          constraints.maxWidth,
          forceHeadline: forceHeadline,
          titleLineBudget: titleLineBudget,
        );
        if (lexicon.enabled) {
          // Ana cümle ZATEN ilk tırnağın içeriğidir; tırnaklar ayrıştırmada
          // atıldığı için `firstQuote` kuralı burada hiçbir sözcük bulamazdı
          // (233 sözlük turu kırıldı). Aynı engelli kümeyle bütün cümle açılır.
          return LexiconText(
            parts.main,
            style: style,
            policy: LexiconTapPolicy(
              mode: LexiconTapMode.whole,
              blocked: lexicon.blocked,
            ),
          );
        }
        return Text.rich(
          key: const ValueKey('prompt-main'),
          TextSpan(children: _withBlankSpans(parts.main, style, t)),
          style: style,
        );
      },
    );
  }

  /// `___` boşluğu konu vurgusunda ve kalın çizilir; yeri cümlede aranır.
  static List<InlineSpan> _withBlankSpans(
    String text,
    TextStyle style,
    SahneTokens t,
  ) {
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in RegExp('_{2,}').allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: style.copyWith(color: t.actTx, fontWeight: FontWeight.w800),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return spans;
  }
}

/// Türkçe kaynak cümlenin kutusu: Perde yüzeyi, L pah, sağ üstte dil rozeti.
class _SourceBox extends StatelessWidget {
  const _SourceBox({required this.child, required this.badge});

  final Widget child;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return DecoratedBox(
      key: const ValueKey('prompt-source-box'),
      decoration: ShapeDecoration(
        color: t.s1,
        shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(SahneSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            badge,
            const SizedBox(height: SahneSpace.x2),
            child,
          ],
        ),
      ),
    );
  }
}
