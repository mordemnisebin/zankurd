import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../data/mastery_store.dart';
import '../../l10n/lang.dart';
import '../../models/mastery_level.dart';
import '../../theme/app_theme.dart';

class CategoryGrid extends StatefulWidget {
  const CategoryGrid({
    required this.categories,
    required this.isKu,
    required this.loading,
    required this.onTap,
    super.key,
  });

  final List<String> categories;
  final bool isKu;
  final bool loading;
  final ValueChanged<String> onTap;

  @override
  State<CategoryGrid> createState() => _CategoryGridState();
}

class _CategoryGridState extends State<CategoryGrid> {
  Map<String, MasteryLevel> _masteryLevels = {};

  @override
  void initState() {
    super.initState();
    _loadMastery();
  }

  Future<void> _loadMastery() async {
    final store = await MasteryStore.load();
    if (!mounted) return;
    final levels = <String, MasteryLevel>{};
    for (final cat in widget.categories) {
      levels[cat] = store.levelFor(cat);
    }
    setState(() => _masteryLevels = levels);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            children: [
              for (final (index, cat) in widget.categories.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == widget.categories.length - 1 ? 0 : 8,
                  ),
                  child: _CompactCategoryButton(
                    category: cat,
                    index: index,
                    isKu: widget.isKu,
                    masteryLevel: _masteryLevels[cat] ?? MasteryLevel.none,
                    onTap: () => widget.onTap(cat),
                  ),
                ),
            ],
          );
        }

        int crossCount = 2;
        if (constraints.maxWidth > 900) {
          crossCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossCount = 3;
        }

        return GridView.builder(
          itemCount: widget.categories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.1,
          ),
          itemBuilder: (context, index) {
            final cat = widget.categories[index];
            return _CategoryCard(
              category: cat,
              index: index,
              isKu: widget.isKu,
              masteryLevel: _masteryLevels[cat] ?? MasteryLevel.none,
              onTap: () => widget.onTap(cat),
            );
          },
        );
      },
    );
  }
}

class _CompactCategoryButton extends StatelessWidget {
  const _CompactCategoryButton({
    required this.category,
    required this.index,
    required this.isKu,
    required this.masteryLevel,
    required this.onTap,
  });

  final String category;
  final int index;
  final bool isKu;
  final MasteryLevel masteryLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.categoryGradient(index);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(CategoryVisuals.icon(category), color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  CategoryNames.localized(category, isKu),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (masteryLevel != MasteryLevel.none) ...[
                const SizedBox(width: 6),
                Icon(masteryLevel.icon, color: Colors.white, size: 13),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isKu,
    required this.masteryLevel,
    required this.onTap,
  });

  final String category;
  final int index;
  final bool isKu;
  final MasteryLevel masteryLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.categoryGradient(index);
    final glowColor = AppTheme
        .categoryGradients[index % AppTheme.categoryGradients.length]
        .first;
    final image = CategoryVisuals.imagePath(category);

    return Hero(
      tag: 'category_hero_$category',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: AppTheme.elevatedShadow(glowColor),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(image, fit: BoxFit.cover)),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          gradient.colors.first.withValues(alpha: 0.30),
                          gradient.colors.last.withValues(alpha: 0.88),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: -15,
                  top: -15,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (masteryLevel != MasteryLevel.none)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            masteryLevel.icon,
                            color: AppTheme.gold,
                            size: 11,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isKu ? masteryLevel.titleKu : masteryLevel.titleTr,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CategoryVisuals.icon(category),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CategoryNames.localized(category, isKu),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isKu ? '5 ast · pêşbaz' : '5 seviye · yarış',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
