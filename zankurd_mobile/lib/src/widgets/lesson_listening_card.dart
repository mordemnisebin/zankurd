import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/learner_lexicon.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../services/lesson_listening_speaker.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import 'app_panel.dart';

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
    return AppPanel(
      key: const ValueKey('lesson-listening-card'),
      cardType: CardType.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                AppIcons.volumeHigh,
                size: 18,
                color: AppTheme.playCyan,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.t(K.lessonListeningTitle),
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
            context.t(K.lessonListeningHint),
            style: AppTypography.bodyMedium.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: widget.speaker.speakingListenable,
            builder: (context, speaking, _) => FilledButton.tonalIcon(
              key: const ValueKey('lesson-listening-play'),
              onPressed: _play,
              icon: Icon(
                speaking ? AppIcons.volumeHigh : AppIcons.play,
                size: 16,
              ),
              label: Text(
                context.t(
                  speaking
                      ? K.lessonListeningPlaying
                      : _hasPlayed
                      ? K.lessonListeningReplay
                      : K.lessonListeningPlay,
                ),
              ),
            ),
          ),
          if (_hasPlayed) ...[
            const SizedBox(height: 12),
            for (final option in _options) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  key: ValueKey('lesson-listening-option-${option.id}'),
                  onPressed: _answered ? null : () => _answer(option.meaningTr),
                  child: Text(option.meaningTr),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
          if (_answered) ...[
            const SizedBox(height: 4),
            Semantics(
              liveRegion: true,
              child: Text(
                _correct
                    ? context.t(K.lessonListeningCorrect)
                    : context.t(K.lessonListeningWrong),
                key: const ValueKey('lesson-listening-feedback'),
                style: AppTypography.bodyMedium.copyWith(
                  color: _correct ? AppTheme.playGreen : AppTheme.wrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.termKu,
              key: const ValueKey('lesson-listening-term'),
              style: AppTypography.heading2.copyWith(
                color: AppTheme.textPrimaryColor(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.meaningTr,
              key: const ValueKey('lesson-listening-answer'),
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textSubColor(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (widget.entries.length > 1)
              OutlinedButton(
                key: const ValueKey('lesson-listening-next'),
                onPressed: _next,
                child: Text(context.t(K.lessonRecallNext)),
              ),
          ],
        ],
      ),
    );
  }
}
