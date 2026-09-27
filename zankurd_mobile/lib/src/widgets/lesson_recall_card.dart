import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_panel.dart';

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
    return AppPanel(
      key: const ValueKey('lesson-recall-card'),
      cardType: CardType.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.brain, size: 18, color: AppTheme.playGreen),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(K.lessonRecallTitle),
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimaryColor(context),
                  ),
                ),
              ),
              Text(
                '${_index + 1}/${widget.entries.length}',
                style: AppTypography.caption.copyWith(
                  color: AppTheme.textMutedColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.t(K.lessonRecallHint),
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            entry.termKu,
            key: const ValueKey('lesson-recall-term'),
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
          if (_revealed) ...[
            const SizedBox(height: 10),
            Semantics(
              liveRegion: true,
              child: Text(
                entry.meaningTr,
                key: const ValueKey('lesson-recall-answer'),
                style: AppTypography.bodyLarge.copyWith(
                  color: AppTheme.textSubColor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (!_revealed)
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('lesson-recall-reveal'),
                    onPressed: _reveal,
                    icon: const Icon(AppIcons.eye, size: 16),
                    label: Text(context.t(K.lessonRecallReveal)),
                  ),
                )
              else if (widget.entries.length > 1)
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('lesson-recall-next'),
                    onPressed: _next,
                    child: Text(context.t(K.lessonRecallNext)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
