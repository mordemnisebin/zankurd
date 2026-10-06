import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../screens/learner_lexicon_screen.dart';
import '../utils/app_route.dart';
import 'sahne/sahne.dart';

/// Hangi sözcükler sözlük için dokunulabilir?
///
/// ## Niçin var
///
/// Başlangıç yolu geri bildirimi: "anlamını bilmeyen öğrenen soruda ya da
/// slaytta takılıyor". Kurmancî metindeki bir sözcüğe dokununca sözlük
/// maddesi (anlam, kaynak ders) küçük bir sayfada açılır.
///
/// ## Cevap sızdırmaz
///
/// Sözlük anlamı cevabın kendisi olabilir: `"Dûr" bi Tirkî çi ye?` sorusunda
/// `Dûr`a dokunmak "Uzak"ı gösterirdi. Bu yüzden CEVAPLANMADAN önce
/// [blocked] kümesindeki sözcükler (sorulan terim ve doğru cevabın
/// sözcükleri) dokunulabilir ÇİZİLMEZ; cevaptan sonra hepsi açılır. Şıklar
/// bu yüzden hiç dokunulabilir değildir: bir şıkkın anlamı soruyu çözerdi.
class LexiconTapPolicy {
  const LexiconTapPolicy({required this.mode, this.blocked = const {}});

  /// Hiçbir sözcük dokunulabilir değil (yarış/oda/düello, cümle kurma...).
  static const off = LexiconTapPolicy(mode: LexiconTapMode.off);

  final LexiconTapMode mode;

  /// Katlanmış (bkz. [LearnerLexicon.foldForSearch]) engelli sözcükler.
  final Set<String> blocked;

  bool get enabled => mode != LexiconTapMode.off;

  /// Bir sorunun metni için kural.
  ///
  /// * [enabled] false (yarış, oda, düello): hiçbir şey dokunulabilir değil.
  /// * Cümle kurma: istem Türkçe cümledir, dokunulacak Kurmancî yok.
  /// * `"…" bi Kurmancî çi ye?`: tırnaktaki Türkçedir; Kurmancî sözcük
  ///   yalnız şıklardadır (şıklar kapalı) -> kapalı.
  /// * Boşluk doldurma: ilk tırnaktaki Kurmancî cümle; doğru cevabın
  ///   sözcükleri cevaptan önce engelli.
  /// * `"Dûr" bi Tirkî çi ye?`: ilk tırnaktaki terim; cevaptan önce TAMAMI
  ///   engelli.
  /// * Kurmancî arayüzde Kurmancî sorular: metnin tamamı; doğru cevabın
  ///   sözcükleri cevaptan önce engelli. Türkçe arayüzde istem Türkçedir.
  static LexiconTapPolicy forQuestion({
    required bool enabled,
    required bool isKu,
    required bool answered,
    required String type,
    required String promptText,
    required String correctAnswer,
  }) {
    if (!enabled || type == 'wordOrdering') return off;
    final lower = promptText.toLowerCase();
    final toKurmanci = RegExp(
      r'bi kurmanc|kurmancîsi|kurmancisi',
    ).hasMatch(lower);
    final toTurkish = RegExp(r'bi tirk|türkçesi|turkcesi').hasMatch(lower);
    if (toKurmanci) return off;
    final correctTokens = answered ? <String>{} : _tokenSet(correctAnswer);
    if (type == 'fillInBlank') {
      return LexiconTapPolicy(
        mode: LexiconTapMode.firstQuote,
        blocked: correctTokens,
      );
    }
    if (toTurkish) {
      final quoted = _firstQuote(promptText);
      return LexiconTapPolicy(
        mode: LexiconTapMode.firstQuote,
        blocked: answered ? const {} : _tokenSet(quoted ?? ''),
      );
    }
    if (!isKu) return off;
    return LexiconTapPolicy(mode: LexiconTapMode.whole, blocked: correctTokens);
  }

  static final _wordPattern = RegExp(r'[\p{L}̧̂]+', unicode: true);

  static Set<String> _tokenSet(String text) => {
    for (final m in _wordPattern.allMatches(text))
      LearnerLexicon.foldForSearch(m.group(0)!),
  };

  static String? _firstQuote(String text) =>
      RegExp('["“«]([^"”»]*)["”»]').firstMatch(text)?.group(1);
}

enum LexiconTapMode { off, firstQuote, whole }

/// [text] içindeki sözlükte olan sözcükleri dokunulabilir çizer.
///
/// Dokunulabilir sözcük: noktalı alt çizgili, sözcükten 6 dp taşan dokunma
/// alanı (inline metinde 44 dp'lik kutu satırı şişirir; `Semantics` düğmesi, etiketi "sözcük. Sözcüğün anlamı sözlükte var").
/// Sözlükte olmayan sözcük sade metindir; dokunulmaz.
class LexiconText extends StatelessWidget {
  const LexiconText(
    this.text, {
    required this.style,
    this.policy = const LexiconTapPolicy(mode: LexiconTapMode.whole),
    this.skipLinePattern,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle style;
  final LexiconTapPolicy policy;

  /// Eşleşen satırlar düz metin kalır (ör. `• terim: anlam` çiftleri).
  final RegExp? skipLinePattern;
  final TextAlign? textAlign;

  static final _word = RegExp(r'[\p{L}̧̂]+', unicode: true);

  @override
  Widget build(BuildContext context) {
    if (!policy.enabled) return Text(text, style: style, textAlign: textAlign);
    final t = SahneTokens.of(context);
    final spans = <InlineSpan>[];
    var quoteIndex = -1;
    var inQuote = false;
    final lines = text.split('\n');
    for (var li = 0; li < lines.length; li++) {
      final line = lines[li];
      final skip = skipLinePattern?.hasMatch(line) ?? false;
      var cursor = 0;
      for (final match in _word.allMatches(line)) {
        // Aradaki ayraçlar: tırnak durumunu izle.
        final gap = line.substring(cursor, match.start);
        for (final ch in gap.runes) {
          final c = String.fromCharCode(ch);
          if (c == '"' || c == '“' || c == '”' || c == '«' || c == '»') {
            if (c == '"') {
              inQuote = !inQuote;
              if (inQuote) quoteIndex++;
            } else if (c == '“' || c == '«') {
              inQuote = true;
              quoteIndex++;
            } else {
              inQuote = false;
            }
          }
        }
        if (gap.isNotEmpty) spans.add(TextSpan(text: gap));
        cursor = match.end;
        final word = match.group(0)!;
        final allowedHere = switch (policy.mode) {
          LexiconTapMode.off => false,
          LexiconTapMode.whole => true,
          LexiconTapMode.firstQuote => inQuote && quoteIndex == 0,
        };
        final entry =
            (!skip &&
                allowedHere &&
                // Tek harfler (alfabe satırı, `e` ünlüsü) sözlük sözcüğü değildir.
                word.runes.length >= 2 &&
                !policy.blocked.contains(LearnerLexicon.foldForSearch(word)))
            ? LearnerLexicon.lookup(word)
            : null;
        if (entry == null) {
          spans.add(TextSpan(text: word));
          continue;
        }
        spans.add(_tappable(context, t, word, entry));
      }
      final rest = line.substring(cursor);
      // Satır sonundaki tırnaklar da durumu etkiler.
      for (final ch in rest.runes) {
        final c = String.fromCharCode(ch);
        if (c == '"') {
          inQuote = !inQuote;
          if (inQuote) quoteIndex++;
        } else if (c == '”' || c == '»') {
          inQuote = false;
        } else if (c == '“' || c == '«') {
          inQuote = true;
          quoteIndex++;
        }
      }
      if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
      if (li < lines.length - 1) spans.add(const TextSpan(text: '\n'));
    }
    return Text.rich(
      TextSpan(style: style, children: spans),
      textAlign: textAlign,
    );
  }

  WidgetSpan _tappable(
    BuildContext context,
    SahneTokens t,
    String word,
    LearnerLexiconEntry entry,
  ) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Semantics(
        button: true,
        label: '$word. ${context.t(K.lexiconWordHint)}',
        child: ExcludeSemantics(
          child: GestureDetector(
            key: ValueKey('lexicon-word-${LearnerLexicon.foldForSearch(word)}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => showLexiconEntrySheet(context, entry),
            child: Padding(
              // Dokunma alanı sözcükten biraz büyük: satır yüksekliğini
              // şişirmeden elin rahat isabet ettirmesi için.
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Text(
                word,
                style: style.copyWith(
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: t.learnTx,
                  decorationThickness: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sözlük maddesi balonu: Kurmancî sözcük, Türkçe anlam, kaynak ders,
/// "Sözlükte aç".
Future<void> showLexiconEntrySheet(
  BuildContext context,
  LearnerLexiconEntry entry,
) {
  final t = SahneTokens.of(context);
  final isKu = context.isKu;
  final source = LearnerLexicon.sourceFor(entry);
  final sourceText =
      '${context.t(K.lexiconSource)}: ${isKu ? source.titleKu : source.titleTr}';
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: t.s1,
    shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
    builder: (sheetContext) => Padding(
      key: const ValueKey('lexicon-entry-sheet'),
      padding: const EdgeInsets.fromLTRB(
        SahneSpace.page,
        SahneSpace.x5,
        SahneSpace.page,
        SahneSpace.x5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              entry.termKu,
              style: SahneType.headline.copyWith(color: t.tx),
            ),
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(entry.meaningTr, style: SahneType.body.copyWith(color: t.tx2)),
          if (entry.forms.isNotEmpty) ...[
            const SizedBox(height: SahneSpace.x1),
            Text(
              '${context.t(K.lexiconForms)}: ${entry.forms.join(', ')}',
              style: SahneType.caption.copyWith(color: t.tx3),
            ),
          ],
          const SizedBox(height: SahneSpace.x2),
          Text(
            sourceText,
            style: SahneType.captionStrong.copyWith(color: t.learnTx),
          ),
          const SizedBox(height: SahneSpace.x4),
          SahneButton.secondary(
            buttonKey: const ValueKey('lexicon-sheet-open'),
            label: context.t(K.lexiconOpen),
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              Navigator.of(context).push(
                AppRoute(
                  page: LearnerLexiconScreen(initialQuery: entry.termKu),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
