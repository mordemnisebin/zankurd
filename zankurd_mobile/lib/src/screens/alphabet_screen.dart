import 'package:flutter/material.dart';

import '../data/kurmanci_alphabet.dart';
import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/lesson_listening_speaker.dart';
import '../theme/app_icons.dart';
import '../widgets/pronunciation_sheet.dart';
import '../widgets/sahne/sahne.dart';
import '../widgets/zk_back_button.dart';

/// "Alfabe ve sesler" (2026-10-27): 31 harf, her birine sesi olan bir
/// örnek kelime ve Türkçeden farklı okunan harflerde kısa ses ipucu.
///
/// Niçin: rakiplerde harf-ses tablosu başlangıcın parçası; bizde alfabe
/// yalnız ilk dersin içindeydi ve ders bitince geri dönülecek bir başvuru
/// yeri yoktu. Satıra dokunmak örneği çalar; kaplumbağa yavaş çalar;
/// mikrofon telaffuz atölyesini açar (kendi sesini kaydet, karşılaştır).
class AlphabetScreen extends StatefulWidget {
  const AlphabetScreen({this.speaker, super.key});

  /// Testler sahte verir; yoksa paylaşılan ders seslendiricisi yüklenir.
  final LessonListeningSpeaker? speaker;

  @override
  State<AlphabetScreen> createState() => _AlphabetScreenState();
}

class _AlphabetScreenState extends State<AlphabetScreen> {
  LessonListeningSpeaker? _speaker;

  @override
  void initState() {
    super.initState();
    _speaker = widget.speaker ?? LessonAudio.loaded;
    if (_speaker == null) _load();
  }

  Future<void> _load() async {
    try {
      final speaker = await LessonAudio.shared();
      if (!mounted) return;
      setState(() => _speaker = speaker);
    } catch (_) {
      // Ses yüklenemezse harfler örneksiz görünür.
    }
  }

  @override
  void dispose() {
    _speaker?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final speaker = _speaker;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: zkAppBar(context, title: Text(context.t(K.alphabetTitle))),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          key: const ValueKey('alphabet-list'),
          padding: const EdgeInsets.fromLTRB(
            SahneSpace.page,
            SahneSpace.x2,
            SahneSpace.page,
            SahneSpace.x8,
          ),
          itemCount: kurmanciAlphabet.length + 1,
          separatorBuilder: (_, _) => const SizedBox(height: SahneSpace.x2),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: SahneSpace.x2),
                child: Text(
                  context.t(K.alphabetIntro),
                  style: SahneType.body.copyWith(color: t.tx2),
                ),
              );
            }
            final letter = kurmanciAlphabet[i - 1];
            // Ses yoksa da örnek gösterilir (okuma örneği); düğme yalnız
            // sesi olanda çizilir.
            final example =
                (speaker == null
                    ? null
                    : alphabetExampleFor(
                        letter.letter,
                        speaker.availableFor,
                      )) ??
                alphabetExampleFor(letter.letter, (_) => true);
            return _LetterRow(
              letter: letter,
              example: example,
              speaker: speaker,
            );
          },
        ),
      ),
    );
  }
}

class _LetterRow extends StatelessWidget {
  const _LetterRow({
    required this.letter,
    required this.example,
    required this.speaker,
  });

  final AlphabetLetter letter;
  final LearnerLexiconEntry? example;
  final LessonListeningSpeaker? speaker;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final example = this.example;
    final speaker = this.speaker;
    final hintKey = letter.hintKey;
    final canPlay =
        example != null &&
        speaker != null &&
        speaker.availableFor(example.termKu);
    return SahneSurfaceCard(
      key: ValueKey('alphabet-letter-${letter.letter}'),
      padding: const EdgeInsets.all(SahneSpace.x3),
      onTap: canPlay ? () => speaker.speak(example.termKu) : null,
      semanticLabel: [
        letter.upper,
        if (example != null) '${example.termKu}, ${example.meaningTr}',
        if (hintKey != null) context.t(hintKey),
      ].join('. '),
      child: Row(
        children: [
          ExcludeSemantics(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: t.learnTint,
                shape: SahneShape.m,
              ),
              child: SizedBox.square(
                dimension: 52,
                child: Center(
                  child: Text(
                    '${letter.upper}${letter.letter}',
                    style: SahneType.title.copyWith(color: t.learnTx),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: SahneSpace.x3),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (example != null)
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: example.termKu,
                            style: SahneType.bodyStrong.copyWith(color: t.tx),
                          ),
                          TextSpan(
                            text: '  ${example.meaningTr}',
                            style: SahneType.caption.copyWith(color: t.tx2),
                          ),
                        ],
                      ),
                    ),
                  if (hintKey != null)
                    Padding(
                      padding: EdgeInsets.only(
                        top: example == null ? 0 : SahneSpace.x1,
                      ),
                      child: Text(
                        context.t(hintKey),
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (canPlay) ...[
            SahneIconButton(
              key: ValueKey('alphabet-slow-${letter.letter}'),
              icon: AppIcons.turtle,
              semanticLabel: context.t(K.slowListen),
              onPressed: () => speaker.speak(example.termKu, slow: true),
            ),
            const SizedBox(width: SahneSpace.x1),
            // Telaffuz atölyesi burada da: harfin örneğini kendi sesinle
            // kaydedip karşılaştır (rakiplerde konuşma pratiği ses
            // tablosunun yanında durur; eskiden yalnız sözlük satırındaydı).
            PronunciationButton(
              key: ValueKey('alphabet-mic-${letter.letter}'),
              text: example.termKu,
              speaker: speaker,
            ),
          ],
        ],
      ),
    );
  }
}
