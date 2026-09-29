import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/lesson_listening_speaker.dart';
import '../theme/app_icons.dart';
import 'app_panel.dart';
import 'sahne/sahne.dart';

class LessonListeningCard extends StatefulWidget {
  const LessonListeningCard({
    required this.entries,
    required this.speaker,
    super.key,
  });

  final List<LearnerLexiconEntry> entries;
  final LessonListeningSpeaker speaker;

  @override
  State<LessonListeningCard> createState() => _LessonListeningCardState();
}

class _LessonListeningCardState extends State<LessonListeningCard> {
  int _index = 0;
  String? _selectedMeaning;
  bool _hasPlayed = false;

  LearnerLexiconEntry get _entry => widget.entries[_index];
  bool get _answered => _selectedMeaning != null;
  bool get _correct => _selectedMeaning == _entry.meaningTr;

  List<LearnerLexiconEntry> get _options {
    final count = math.min(3, widget.entries.length);
    final candidates = List<LearnerLexiconEntry>.generate(
      count,
      (offset) => widget.entries[(_index + offset) % widget.entries.length],
    );
    if (candidates.length < 2) return candidates;

    // Doğru seçeneğin her turda ilk sırada olmasını önle; yine de tamamen
    // deterministik kal ki test/screen-tour çıktısı sabit olsun.
    final correct = candidates.removeAt(0);
    final insertAt = (_index + 1) % (candidates.length + 1);
    candidates.insert(insertAt, correct);
    return candidates;
  }

  Future<void> _play() async {
    await widget.speaker.speak(_entry.termKu);
    if (!mounted || _hasPlayed) return;
    setState(() => _hasPlayed = true);
  }

  void _answer(String meaning) {
    if (_answered) return;
    setState(() => _selectedMeaning = meaning);
  }

  Future<void> _next() async {
    if (widget.entries.length < 2) return;
    await widget.speaker.stop();
    if (!mounted) return;
    setState(() {
      _index = (_index + 1) % widget.entries.length;
      _selectedMeaning = null;
      _hasPlayed = false;
    });
  }

  @override
  void dispose() {
    unawaited(widget.speaker.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.speaker.available || widget.entries.length < 2) {
      return const SizedBox.shrink();
    }

    final entry = _entry;
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: yüzey kartı; başlık satırı öğrenme rolünün ikonu +
    // Gövde 700 + sayaç (kalın açıklama, tablo rakamı); dinle düğmesi ve
    // şıklar ikincil düğme (Kulis); geri bildirim Rast/Şaş metni.
    return AppPanel(
      key: const ValueKey('lesson-listening-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.volumeHigh, size: 20, color: t.learnTx),
              const SizedBox(width: SahneSpace.x2),
              Expanded(
                child: Text(
                  context.t(K.lessonListeningTitle),
                  style: SahneType.bodyStrong.copyWith(color: t.tx),
                ),
              ),
              Text(
                '${_index + 1}/${widget.entries.length}',
                style: SahneType.captionStrong.copyWith(
                  color: t.tx3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: SahneSpace.x2),
          Text(
            context.t(K.lessonListeningHint),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x3),
          ValueListenableBuilder<bool>(
            valueListenable: widget.speaker.speakingListenable,
            builder: (context, speaking, _) => SahneButton.secondary(
              key: const ValueKey('lesson-listening-play'),
              onPressed: _play,
              icon: speaking ? AppIcons.volumeHigh : AppIcons.play,
              label: context.t(
                speaking
                    ? K.lessonListeningPlaying
                    : _hasPlayed
                    ? K.lessonListeningReplay
                    : K.lessonListeningPlay,
              ),
            ),
          ),
          if (_hasPlayed) ...[
            const SizedBox(height: SahneSpace.x3),
            for (final option in _options) ...[
              SahneButton.secondary(
                key: ValueKey('lesson-listening-option-${option.id}'),
                onPressed: _answered ? null : () => _answer(option.meaningTr),
                label: option.meaningTr,
                expand: true,
              ),
              const SizedBox(height: SahneSpace.x2),
            ],
          ],
          if (_answered) ...[
            const SizedBox(height: SahneSpace.x1),
            Semantics(
              liveRegion: true,
              child: Text(
                _correct
                    ? context.t(K.lessonListeningCorrect)
                    : context.t(K.lessonListeningWrong),
                key: const ValueKey('lesson-listening-feedback'),
                style: SahneType.bodyStrong.copyWith(
                  color: _correct ? t.okTx : t.errTx,
                ),
              ),
            ),
            const SizedBox(height: SahneSpace.x2),
            Text(
              entry.termKu,
              key: const ValueKey('lesson-listening-term'),
              style: SahneType.headline.copyWith(color: t.tx),
            ),
            const SizedBox(height: SahneSpace.x1),
            Text(
              entry.meaningTr,
              key: const ValueKey('lesson-listening-answer'),
              style: SahneType.bodyStrong.copyWith(color: t.tx2),
            ),
            const SizedBox(height: SahneSpace.x3),
            if (widget.entries.length > 1)
              SahneButton.secondary(
                key: const ValueKey('lesson-listening-next'),
                onPressed: _next,
                label: context.t(K.lessonRecallNext),
                arrow: true,
              ),
          ],
        ],
      ),
    );
  }
}
