import 'package:flutter/material.dart';

import '../data/story_progress_store.dart';
import '../l10n/strings.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../theme/app_icons.dart';
import '../theme/app_theme.dart';

typedef StoryOpenCallback = Future<void> Function(Story story, MiniGuide guide);

/// Günlük hikâyeleri ve her birinin yerel ilerleme durumunu gösterir.
class StoryCatalog extends StatefulWidget {
  const StoryCatalog({required this.isKu, required this.onOpen, super.key});

  final bool isKu;
  final StoryOpenCallback onOpen;

  @override
  State<StoryCatalog> createState() => _StoryCatalogState();
}

class _StoryCatalogState extends State<StoryCatalog> {
  Map<String, String?> _progress = const {};

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final store = await StoryProgressStore.load();
    if (!mounted) return;
    setState(() {
      _progress = {
        for (final story in everydayStories)
          story.id: store.currentNodeId(story.id),
      };
    });
  }

  Future<void> _open(Story story) async {
    final guide = everydayGuides[story.id];
    if (guide == null) return;
    await widget.onOpen(story, guide);
    await _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('story-catalog'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Tr.forKu(K.storyCatalogTitle, widget.isKu),
          style: AppTypography.heading2.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          Tr.forKu(K.storyCatalogSub, widget.isKu),
          style: AppTypography.caption.copyWith(
            color: AppTheme.textMutedColor(context),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final story in everydayStories) ...[
          _StoryCatalogCard(
            key: ValueKey('story-card-${story.id}'),
            story: story,
            nodeId: _progress[story.id],
            isKu: widget.isKu,
            onTap: () => _open(story),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _StoryCatalogCard extends StatelessWidget {
  const _StoryCatalogCard({
    required this.story,
    required this.nodeId,
    required this.isKu,
    required this.onTap,
    super.key,
  });

  final Story story;
  final String? nodeId;
  final bool isKu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = story.node(nodeId)?.isEnding ?? false;
    final status = completed
        ? Tr.forKu(K.storyStatusDone, isKu)
        : nodeId == null
        ? Tr.forKu(K.storyStatusStart, isKu)
        : Tr.forKu(K.storyStatusContinue, isKu);
    return Semantics(
      button: true,
      label: '${isKu ? story.titleKu : story.titleTr}. $status',
      child: Material(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppTheme.playGreen.withValues(alpha: 0.28),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.playGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(
                    AppIcons.bookOpenReader,
                    size: 18,
                    color: AppTheme.playGreen,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isKu ? story.titleKu : story.titleTr,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isKu ? story.titleTr : story.titleKu,
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  status,
                  style: AppTypography.caption.copyWith(
                    color: AppTheme.playGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  AppIcons.chevronRight,
                  size: 16,
                  color: AppTheme.playGreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
