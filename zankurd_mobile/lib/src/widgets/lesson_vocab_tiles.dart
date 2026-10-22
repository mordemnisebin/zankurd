import 'package:flutter/material.dart';

import '../theme/sahne.dart';
import 'lexicon_lookup.dart';
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
  const LessonContentBlocks({required this.text, super.key});

  final String text;

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

    void flushText() {
      final joined = textBuffer.join('\n').trim();
      textBuffer.clear();
      if (joined.isEmpty) return;
      blocks.add(LexiconText(joined, style: style));
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

class _VocabTile extends StatelessWidget {
  const _VocabTile({required this.term, required this.meaning});

  final String term;
  final String meaning;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final swatch = LessonContentBlocks.colorWords[term.toLowerCase().trim()];
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.learnTint,
        shape: SahneShape.withSide(SahneShape.m, t.learnEdge, width: 1),
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
                  shape: SahneShape.withSide(SahneShape.s, t.line, width: 1),
                ),
              ),
              const SizedBox(width: SahneSpace.x3),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    term,
                    style: SahneType.bodyStrong.copyWith(color: t.learnTx),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    meaning,
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
            LexiconSpeakButton(text: term),
          ],
        ),
      ),
    );
  }
}

class _LetterTiles extends StatelessWidget {
  const _LetterTiles({required this.letters});

  final List<String> letters;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    // Ortalı: sola yaslı karolar dar ekranda sağda boş şerit bırakıyordu
    // (simülatör, 2026-10-22).
    return Wrap(
      key: const ValueKey('lesson-letter-tiles'),
      alignment: WrapAlignment.center,
      spacing: SahneSpace.x1,
      runSpacing: SahneSpace.x1,
      children: [
        for (final letter in letters)
          Container(
            width: 40,
            height: 44,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: t.learnTint,
              shape: SahneShape.withSide(SahneShape.s, t.learnEdge, width: 1),
            ),
            child: Text(
              letter,
              style: SahneType.headline.copyWith(color: t.learnTx),
            ),
          ),
      ],
    );
  }
}
