import 'package:flutter/material.dart';

import '../data/story_progress_store.dart';
import '../l10n/strings.dart';
import '../models/mini_guide.dart';
import '../models/story.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

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
    final t = SahneTokens.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compactRailHeight = (56.0 * textScale).clamp(56.0, 72.0).toDouble();

    return Column(
      key: const ValueKey('story-catalog'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 2026-09-29 Şahnê: bölüm başlığı dili — Manşet 22 + Açıklama.
        Semantics(
          header: true,
          child: Text(
            Tr.forKu(K.storyCatalogTitle, widget.isKu),
            style: SahneType.headline.copyWith(color: t.tx),
          ),
        ),
        const SizedBox(height: SahneSpace.x3),
        if (widget.compact)
          SizedBox(
            height: compactRailHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: everydayStories.length,
              separatorBuilder: (_, _) => const SizedBox(width: SahneSpace.x2),
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
          // Liste grubu (Perde, L pah, gündüzde 1 px kenar); satırlar ikonsuz,
          // ayırıcı metin hizasından (16) başlar.
          SahneListGroup(
            children: [
              for (final story in everydayStories)
                _StoryCatalogCard(
                  key: ValueKey('story-card-${story.id}'),
                  story: story,
                  nodeId: _progress[story.id],
                  isKu: widget.isKu,
                  compact: false,
                  onTap: () => _open(story),
                ),
            ],
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
    // 2026-09-29 doğallık (K7): başlık Gövde 700, öteki dildeki ad
    // Açıklama; sağda YALNIZ ilerleme — bitti ise ✓, yarım ise "Devam et"
    // (kalın açıklama, Zimrût metni), başlanmamışsa hiçbir şey. Eskiden her
    // satırda aynı kitap ikonu karosu ve "Başla ›" vardı: dört satırda dört
    // kez aynı süs ve aynı söz, satırın tamamı zaten dokunulur. Ekran
    // okuyucu durumu yine duyar (etiketteki "Başla").
    final t = SahneTokens.of(context);
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: '${isKu ? story.titleKu : story.titleTr}. $status',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        excludeFromSemantics: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 48 : 52),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? SahneSpace.x3 : SahneSpace.x4,
              vertical: compact ? SahneSpace.x1 : SahneSpace.x2,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isKu ? story.titleKu : story.titleTr,
                        maxLines: compact ? 1 : null,
                        overflow: compact ? TextOverflow.ellipsis : null,
                        style: SahneType.bodyStrong.copyWith(color: t.tx),
                      ),
                      if (!compact)
                        Text(
                          isKu ? story.titleTr : story.titleKu,
                          style: SahneType.caption.copyWith(color: t.tx2),
                        ),
                    ],
                  ),
                ),
                if (completed) ...[
                  const SizedBox(width: SahneSpace.x2),
                  Icon(AppIcons.check, size: 20, color: t.learnTx),
                ] else if (nodeId != null) ...[
                  const SizedBox(width: SahneSpace.x2),
                  Text(
                    status,
                    style: SahneType.captionStrong.copyWith(color: t.learnTx),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
