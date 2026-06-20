import 'package:flutter/material.dart';

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

    return GridView.builder(
      itemCount: widget.categories.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
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

  IconData _icon(String cat) => switch (cat) {
    'Ziman' => Icons.translate_outlined,
    'Çand' => Icons.diversity_3_outlined,
    'Dîrok' => Icons.account_balance_outlined,
    'Edebiyat' => Icons.menu_book_outlined,
    'Cografya' => Icons.public_outlined,
    'Muzîk' => Icons.music_note_outlined,
    'Siyaset' => Icons.how_to_vote_outlined,
    'Paradigma' => Icons.psychology_outlined,
    _ => Icons.category_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.categoryGradient(index);
    final glowColor = AppTheme
        .categoryGradients[index % AppTheme.categoryGradients.length]
        .first;

    return Hero(
      tag: 'category_hero_$category',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
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
                      child: Icon(_icon(category), color: Colors.white, size: 24),
                    ),
                    const Spacer(),
                    Text(
                      CategoryNames.localized(category, isKu),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isKu ? '5 ast · pêşbaz' : '5 seviye · yarış',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                    if (masteryLevel != MasteryLevel.none) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            masteryLevel.icon,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isKu ? masteryLevel.titleKu : masteryLevel.titleTr,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
