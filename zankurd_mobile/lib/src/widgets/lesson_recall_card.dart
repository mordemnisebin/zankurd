import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'app_panel.dart';
import 'sahne/sahne.dart';

class LessonRecallCard extends StatefulWidget {
  const LessonRecallCard({required this.entries, super.key});

  final List<LearnerLexiconEntry> entries;

  @override
  State<LessonRecallCard> createState() => _LessonRecallCardState();
}

class _LessonRecallCardState extends State<LessonRecallCard> {
  int _index = 0;
  bool _revealed = false;

  void _reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
  }

  void _next() {
    if (widget.entries.length < 2) return;
    setState(() {
      _index = (_index + 1) % widget.entries.length;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) return const SizedBox.shrink();

    final entry = widget.entries[_index];
    final t = SahneTokens.of(context);
    // 2026-09-29 Şahnê: yüzey kartı; öğrenme rolünün ikonu, Gövde 700
    // başlık, sayaç tablo rakamı; terim Manşet; düğmeler ikincil (Kulis).
    return AppPanel(
      key: const ValueKey('lesson-recall-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.brain, size: 20, color: t.learnTx),
              const SizedBox(width: SahneSpace.x2),
              Expanded(
                child: Text(
                  context.t(K.lessonRecallTitle),
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
            context.t(K.lessonRecallHint),
            style: SahneType.body.copyWith(color: t.tx2),
          ),
          const SizedBox(height: SahneSpace.x4),
          Text(
            entry.termKu,
            key: const ValueKey('lesson-recall-term'),
            style: SahneType.headline.copyWith(color: t.tx),
          ),
          if (_revealed) ...[
            const SizedBox(height: SahneSpace.x2),
            Semantics(
              liveRegion: true,
              child: Text(
                entry.meaningTr,
                key: const ValueKey('lesson-recall-answer'),
                style: SahneType.bodyStrong.copyWith(color: t.tx2),
              ),
            ),
          ],
          const SizedBox(height: SahneSpace.x4),
          if (!_revealed)
            SahneButton.secondary(
              key: const ValueKey('lesson-recall-reveal'),
              onPressed: _reveal,
              icon: AppIcons.eye,
              label: context.t(K.lessonRecallReveal),
              expand: true,
            )
          else if (widget.entries.length > 1)
            SahneButton.secondary(
              key: const ValueKey('lesson-recall-next'),
              onPressed: _next,
              label: context.t(K.lessonRecallNext),
              arrow: true,
              expand: true,
            ),
        ],
      ),
    );
  }
}
