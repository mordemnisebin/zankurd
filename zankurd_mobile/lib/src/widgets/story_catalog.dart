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
  const StoryCatalog({
    required this.isKu,
    required this.onOpen,
    this.compact = false,
    super.key,
  });

  final bool isKu;
  final StoryOpenCallback onOpen;
  final bool compact;

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
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactRailHeight = (56.0 * textScale).clamp(56.0, 72.0).toDouble();

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
        if (widget.compact)
          SizedBox(
            height: compactRailHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: everydayStories.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) {
                final story = everydayStories[index];
                return SizedBox(
                  width: 248,
                  child: Material(
                    key: ValueKey('story-scene-strip-${story.id}'),
                    color: Colors.transparent,
                    child: _StoryCatalogCard(
                      key: ValueKey('story-card-${story.id}'),
                      story: story,
                      nodeId: _progress[story.id],
                      isKu: widget.isKu,
                      compact: true,
                      onTap: () => _open(story),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Material(
            color: AppTheme.surfaceColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              side: BorderSide(color: AppTheme.borderColor(context)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (
                  var index = 0;
                  index < everydayStories.length;
                  index++
                ) ...[
                  _StoryCatalogCard(
                    key: ValueKey('story-card-${everydayStories[index].id}'),
                    story: everydayStories[index],
                    nodeId: _progress[everydayStories[index].id],
                    isKu: widget.isKu,
                    compact: false,
                    onTap: () => _open(everydayStories[index]),
                  ),
                  if (index != everydayStories.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 64,
                      color: AppTheme.borderColor(
                        context,
                      ).withValues(alpha: 0.7),
                    ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StoryCatalogCard extends StatelessWidget {
  const _StoryCatalogCard({
    required this.story,
    required this.nodeId,
    required this.isKu,
    required this.compact,
    required this.onTap,
    super.key,
  });

  final Story story;
  final String? nodeId;
  final bool isKu;
  final bool compact;
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
      excludeSemantics: true,
      label: '${isKu ? story.titleKu : story.titleTr}. $status',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: compact ? AppSpacing.xs : AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 32 : 36,
                height: compact ? 32 : 36,
                decoration: BoxDecoration(
                  color: AppTheme.playGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  AppIcons.bookOpenReader,
                  size: compact ? 15 : 17,
                  color: AppColors.onAccentTint(
                    context,
                    AppTheme.playGreen,
                    tintAlpha: 0.1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKu ? story.titleKu : story.titleTr,
                      maxLines: compact ? 1 : null,
                      overflow: compact ? TextOverflow.ellipsis : null,
                      style:
                          (compact
                                  ? AppTypography.bodyMedium
                                  : AppTypography.bodyLarge)
                              .copyWith(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    if (!compact)
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
                  color: AppColors.readableAccent(context, AppTheme.playGreen),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight,
                size: 16,
                color: AppColors.readableAccent(context, AppTheme.playGreen),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
