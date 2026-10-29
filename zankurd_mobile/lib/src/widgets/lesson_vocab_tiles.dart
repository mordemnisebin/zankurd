import 'dart:async';

import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../utils/error_reporter.dart';

import '../theme/sahne.dart';
import 'lexicon_lookup.dart';
import '../services/lesson_listening_speaker.dart';
import 'lexicon_speak_button.dart';

/// Ders slaytının Kurmancî içeriği: düz metin + görsel kelime kartları.
///
/// ## Niçin
///
/// Slaytlar "• spî: beyaz" madde listesiydi: "Renkler" dersi renkleri
/// göstermeden adlarını yazıyor, "Alfabe" harfleri bir paragraf gibi
/// diziyordu. İki ayrı tasarım denetçisi (2026-10-22) bunu uygulamanın en
/// metin baskın yeri saydı. Metin aynen korunur; yalnız biçimi değişir:
///
/// * `• terim: anlam` satırları büyük Kurmancî terimli, ses düğmeli öğrenme
///   tonunda kartlara dönüşür. Terim bir renk adıysa kartta o rengin
///   lekesi durur.
/// * Yalnız tek harflerden oluşan satır ("A B C Ç …") harf karolarına
///   dönüşür.
/// * Öteki satırlar (başlık, açıklama) dokunulabilir [LexiconText] kalır.
class LessonContentBlocks extends StatelessWidget {
  const LessonContentBlocks({required this.text, this.translation, super.key});

  final String text;

  /// Türkçe arayüzde Kurmancî açıklamanın karşılığı (`content_tr`).
  ///
  /// Kapışma U20 (2026-10-29): karşılık kelime kartlarının ve harf
  /// karolarının ALTINDA, kartın en sonunda duruyordu; yeni başlayan hangi
  /// Kurmancî cümlenin ne dediğini eşleyemiyordu. Artık her açıklama
  /// cümlesinin HEMEN altında: karşılık boş satırla ayrılmış paragraflardan
  /// oluşuyor ve sayısı Kurmancî metin bloklarıyla eşitse her biri kendi
  /// bloğunun altına; değilse tamamı ilk açıklama bloğunun altına. Kurmancî
  /// arayüzde verilmez (çağıran `null` geçer).
  final String? translation;

  static final _pair = RegExp(r'^•\s*(.+?):\s+(.+)$');

  /// Kurmancî renk adı → gösterim rengi. Yalnız temel ve sık renkler;
  /// tanınmayan terim lekesiz kart olur.
  static const Map<String, Color> colorWords = {
    'spî': Color(0xFFF7F7F2),
    'reş': Color(0xFF1C1C1E),
    'sor': Color(0xFFD7263D),
    'kesk': Color(0xFF2E9E4F),
    'şîn': Color(0xFF2F6FDE),
    'zer': Color(0xFFF2C230),
    'gewr': Color(0xFF8E8E93),
    'qehweyî': Color(0xFF7A4A2A),
    'pembe': Color(0xFFF08BB0),
    'mor': Color(0xFF7B3FB5),
    'binefşî': Color(0xFF7B3FB5),
    'porteqalî': Color(0xFFF08A24),
    'narincî': Color(0xFFF08A24),
    'xemrî': Color(0xFF6B1F2E),
  };

  static final _singleCapital = RegExp(r'^\p{Lu}$', unicode: true);

  static bool _isLetterRow(String line) {
    final parts = line.trim().split(RegExp(r'\s+'));
    return parts.length >= 8 && parts.every(_singleCapital.hasMatch);
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final style = SahneType.body.copyWith(color: t.tx);
    final blocks = <Widget>[];
    final textBuffer = <String>[];
    final pairs = <(String, String)>[];
    final textBlocks = <Widget>{};

    void flushText() {
      final joined = textBuffer.join('\n').trim();
      textBuffer.clear();
      if (joined.isEmpty) return;
      final block = LexiconText(joined, style: style);
      textBlocks.add(block);
      blocks.add(block);
    }

    void flushPairs() {
      if (pairs.isEmpty) return;
      blocks.add(
        Column(
          key: const ValueKey('lesson-vocab-tiles'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (term, meaning) in pairs)
              Padding(
                padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                child: _VocabTile(term: term, meaning: meaning),
              ),
          ],
        ),
      );
      pairs.clear();
    }

    for (final line in text.split('\n')) {
      final pair = _pair.firstMatch(line.trim());
      if (pair != null) {
        flushText();
        pairs.add((pair.group(1)!.trim(), pair.group(2)!.trim()));
        continue;
      }
      if (_isLetterRow(line)) {
        flushText();
        flushPairs();
        blocks.add(_LetterTiles(letters: line.trim().split(RegExp(r'\s+'))));
        continue;
      }
      flushPairs();
      textBuffer.add(line);
    }
    flushText();
    flushPairs();

    final tr = translation?.trim();
    if (tr != null && tr.isNotEmpty) {
      final paragraphs = tr
          .split(RegExp(r'\n\s*\n'))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      Widget translated(String p) => Padding(
        key: const ValueKey('lesson-content-tr'),
        padding: const EdgeInsets.only(top: SahneSpace.x1),
        child: Text(p, style: SahneType.caption.copyWith(color: t.tx2)),
      );
      final textAt = [
        for (var i = 0; i < blocks.length; i++)
          if (textBlocks.contains(blocks[i])) i,
      ];
      if (textAt.isEmpty) {
        blocks.insert(0, translated(paragraphs.join('\n\n')));
      } else if (paragraphs.length == textAt.length) {
        for (var k = textAt.length - 1; k >= 0; k--) {
          blocks[textAt[k]] = _withTranslation(
            blocks[textAt[k]],
            translated(paragraphs[k]),
          );
        }
      } else {
        blocks[textAt.first] = _withTranslation(
          blocks[textAt.first],
          translated(paragraphs.join('\n\n')),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: SahneSpace.x3),
          blocks[i],
        ],
      ],
    );
  }
}

/// Açıklama bloğu + hemen altında Türkçe karşılığı (aradaki boşluk dar:
/// ikisi bir çift olarak okunur).
Widget _withTranslation(Widget block, Widget translation) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [block, translation],
);

class _VocabTile extends StatefulWidget {
  const _VocabTile({required this.term, required this.meaning});

  final String term;
  final String meaning;

  @override
  State<_VocabTile> createState() => _VocabTileState();
}

/// Kartın tamamı dokununca terimi seslendirir ve kısa süre parlar
/// (kurul 2. tur, iki denetçinin ortak önerisi). Ses yoksa kart dokunulmaz;
/// sağdaki düğme zaten görünmez.
class _VocabTileState extends State<_VocabTile> {
  LessonListeningSpeaker? _speaker = LessonAudio.loaded;
  bool _lit = false;

  @override
  void initState() {
    super.initState();
    if (_speaker == null) {
      LessonAudio.shared().then((s) {
        if (mounted) setState(() => _speaker = s);
      }, onError: (_) {});
    }
  }

  Future<void> _play() async {
    final speaker = _speaker;
    if (speaker == null) return;
    setState(() => _lit = true);
    try {
      await speaker.speak(widget.term);
    } finally {
      if (mounted) setState(() => _lit = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final swatch =
        LessonContentBlocks.colorWords[widget.term.toLowerCase().trim()];
    final speaker = _speaker;
    final canPlay = speaker != null && speaker.availableFor(widget.term);
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: ShapeDecoration(
        color: _lit ? Color.lerp(t.learnTint, t.learn, 0.18) : t.learnTint,
        shape: SahneShape.withSide(
          SahneShape.m,
          _lit ? t.learnTx : t.learnEdge,
          width: _lit ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SahneSpace.x3,
          SahneSpace.x2,
          SahneSpace.x1,
          SahneSpace.x2,
        ),
        child: Row(
          children: [
            if (swatch != null) ...[
              Container(
                key: const ValueKey('lesson-vocab-swatch'),
                width: 28,
                height: 28,
                decoration: ShapeDecoration(
                  color: swatch,
                  // Beyaz leke açık zeminde kaybolmasın: belirgin kenar.
                  shape: SahneShape.withSide(SahneShape.s, t.tx2, width: 1),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.term,
                    style: SahneType.bodyStrong.copyWith(color: t.learnTx),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.meaning,
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
            LexiconSpeakButton(text: widget.term, speaker: speaker),
          ],
        ),
      ),
    );
    if (!canPlay) return card;
    return GestureDetector(
      key: const ValueKey('lesson-vocab-tile'),
      behavior: HitTestBehavior.opaque,
      // Okuyucu sağdaki ses düğmesini kullanır; kart ikinci bir düğüm
      // üretmesin.
      excludeFromSemantics: true,
      onTap: _play,
      child: card,
    );
  }
}

/// Harf karosuna dokununca seslendirilen örnek kelime. Hepsi öğrenen
/// sözlüğünde (anlam oradan okunur, burada çeviri üretilmez) ve
/// `assets/audio/ku` kayıtlarında bulunan sözcüklerdir; cihaz TTS'i iOS ve
/// web'de olmadığından tek güvenilir ses kaynağı bu kayıtlardır. I ve U ile
/// başlayan kayıtlı sözcük olmadığından o harfi İÇEREN sözcük seçildi;
/// panel harfi sözcük içinde vurgular (Gemini Flash denetimi: "Jin"
/// J sesiyle başlar, öğrenen harfi nerede duyacağını görmeli).
///
/// 2026-10-25 ekran turu: ızgara yalnız görseldi, harfe dokununca hiçbir
/// şey olmuyordu (kurul: Codex + Gemini 4 Argon, alfabe 8–9/10).
const Map<String, String> kAlphabetExampleWords = {
  'A': 'Av',
  'B': 'Bav',
  'C': 'Cil',
  'Ç': 'çav',
  'D': 'Dar',
  'E': 'Ev',
  'Ê': 'Êvar',
  'F': 'Fêkî',
  'G': 'Gul',
  'H': 'hêk',
  'I': 'Jin',
  'Î': 'Îro',
  'J': 'Jiyan',
  'K': 'Keç',
  'L': 'Lêv',
  'M': 'Mal',
  'N': 'Nan',
  'O': 'otêl',
  'P': 'Pez',
  'Q': 'Qelem',
  'R': 'Roj',
  'S': 'Sêv',
  'Ş': 'Şêr',
  'T': 'Tîp',
  'U': 'Du',
  'Û': 'Û',
  'V': 'Vekirî',
  'W': 'War',
  'X': 'Xew',
  'Y': 'Yek',
  'Z': 'Zarok',
};

/// Hawar alfabesinde sesi yakın, işaretiyle ayrılan harf çiftleri.
const Map<String, String> kHawarLetterPairs = {
  'E': 'Ê',
  'Ê': 'E',
  'I': 'Î',
  'Î': 'I',
  'U': 'Û',
  'Û': 'U',
  'C': 'Ç',
  'Ç': 'C',
  'S': 'Ş',
  'Ş': 'S',
};

class _LetterTiles extends StatefulWidget {
  const _LetterTiles({required this.letters});

  final List<String> letters;

  @override
  State<_LetterTiles> createState() => _LetterTilesState();
}

class _LetterTilesState extends State<_LetterTiles> {
  Widget _exampleRow(
    SahneTokens t,
    String letter,
    String word, {
    bool muted = false,
  }) {
    final meaning = LearnerLexicon.lookup(word)?.meaningTr;
    return Row(
      children: [
        Text(
          '$letter ${letter.toLowerCase()}',
          style: SahneType.headline.copyWith(color: muted ? t.tx2 : t.learnTx),
        ),
        const SizedBox(width: SahneSpace.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HighlightedWord(
                word: word,
                letter: letter,
                style: SahneType.bodyStrong.copyWith(color: t.tx),
                highlight: muted ? t.tx2 : t.learnTx,
              ),
              if (meaning != null)
                Text(meaning, style: SahneType.caption.copyWith(color: t.tx2)),
            ],
          ),
        ),
        LexiconSpeakButton(text: word, speaker: _speaker),
      ],
    );
  }

  LessonListeningSpeaker? _speaker = LessonAudio.loaded;
  String? _selected;

  @override
  void initState() {
    super.initState();
    if (_speaker == null) {
      LessonAudio.shared().then((s) {
        if (mounted) setState(() => _speaker = s);
      }, onError: (_) {});
    }
  }

  void _select(String letter) {
    setState(() => _selected = letter);
    final word = kAlphabetExampleWords[letter];
    final speaker = _speaker;
    if (word != null && speaker != null && speaker.availableFor(word)) {
      unawaited(
        speaker.speak(word).catchError((Object error, StackTrace stack) {
          ErrorReporter.record(error, stack, reason: 'alphabet letter speak');
          return false;
        }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final selected = _selected;
    final word = selected == null ? null : kAlphabetExampleWords[selected];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ortalı: sola yaslı karolar dar ekranda sağda boş şerit bırakıyordu
        // (simülatör, 2026-10-22).
        Wrap(
          key: const ValueKey('lesson-letter-tiles'),
          alignment: WrapAlignment.center,
          spacing: SahneSpace.x1,
          runSpacing: SahneSpace.x1,
          children: [
            for (final letter in widget.letters)
              _LetterTile(
                letter: letter,
                selected: letter == selected,
                onTap: kAlphabetExampleWords.containsKey(letter)
                    ? () => _select(letter)
                    : null,
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: selected == null || word == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: SahneSpace.x3),
                  child: Container(
                    key: const ValueKey('lesson-letter-example'),
                    padding: const EdgeInsets.fromLTRB(
                      SahneSpace.x3,
                      SahneSpace.x2,
                      SahneSpace.x1,
                      SahneSpace.x2,
                    ),
                    decoration: ShapeDecoration(
                      color: t.learnTint,
                      shape: SahneShape.withSide(
                        SahneShape.m,
                        t.learnTx,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _exampleRow(t, selected, word),
                        // Hawar çifti (e/ê, i/î, u/û, c/ç, s/ş): eşinin
                        // örneği de dinlenir; öğrenen iki sesi yan yana
                        // karşılaştırır (kurul: e/ê ayırt etme önerisi).
                        if (kHawarLetterPairs[selected] case final pair?)
                          if (kAlphabetExampleWords[pair]
                              case final pairWord?) ...[
                            Divider(height: SahneSpace.x3, color: t.learnEdge),
                            KeyedSubtree(
                              key: const ValueKey('lesson-letter-pair'),
                              child: _exampleRow(
                                t,
                                pair,
                                pairWord,
                                muted: true,
                              ),
                            ),
                          ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LetterTile extends StatelessWidget {
  const _LetterTile({
    required this.letter,
    required this.selected,
    required this.onTap,
  });

  final String letter;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      // Dokunulabilir oldu: Android'in 48x48 hedef alt sınırı; büyük
      // yazıda harfle birlikte büyür.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      padding: const EdgeInsets.symmetric(
        horizontal: SahneSpace.x1,
        vertical: SahneSpace.x1,
      ),
      decoration: ShapeDecoration(
        color: selected ? t.learnTx : t.learnTint,
        shape: SahneShape.withSide(
          SahneShape.s,
          selected ? t.learnTx : t.learnEdge,
          width: 1,
        ),
      ),
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: Text(
          letter,
          style: SahneType.headline.copyWith(
            color: selected ? t.learnTint : t.learnTx,
          ),
        ),
      ),
    );
    if (onTap == null) return tile;
    return Semantics(
      button: true,
      selected: selected,
      label: letter,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('lesson-letter-$letter'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: tile,
      ),
    );
  }
}

/// Örnek sözcük, baş harfi büyük; seçili harfin İLK geçtiği yer vurgulu
/// (altı çizili, öğrenme renginde).
class _HighlightedWord extends StatelessWidget {
  const _HighlightedWord({
    required this.word,
    required this.letter,
    required this.style,
    required this.highlight,
  });

  final String word;
  final String letter;
  final TextStyle style;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    final shown = word.isEmpty
        ? word
        : SahneType.upperFor(word[0], isKu: true) + word.substring(1);
    final at = shown.toLowerCase().indexOf(letter.toLowerCase());
    if (at < 0) return Text(shown, style: style);
    return Text.rich(
      key: const ValueKey('lesson-letter-example-word'),
      TextSpan(
        style: style,
        children: [
          TextSpan(text: shown.substring(0, at)),
          TextSpan(
            text: shown.substring(at, at + letter.length),
            style: TextStyle(
              color: highlight,
              fontWeight: FontWeight.w800,
              decoration: TextDecoration.underline,
              decorationColor: highlight,
            ),
          ),
          TextSpan(text: shown.substring(at + letter.length)),
        ],
      ),
    );
  }
}
