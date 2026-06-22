import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import '../data/mastery_store.dart';
import '../data/zankurd_repository.dart';
import '../models/mastery_level.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'subcategory_screen.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({
    required this.repository,
    this.scrollController,
    super.key,
  });

  final ZanKurdRepository repository;
  final ScrollController? scrollController;

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  late List<String> _categories = widget.repository.categories;
  bool _loading = false;
  Map<String, MasteryLevel> _masteryLevels = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await widget.repository.loadCategories();
      if (mounted && cats.isNotEmpty) setState(() => _categories = cats);
    } catch (error, stack) {
      ErrorReporter.record(error, stack, reason: 'categories load failed');
    }
    if (mounted) setState(() => _loading = false);
    await _loadMastery();
  }

  Future<void> _loadMastery() async {
    final store = await MasteryStore.load();
    if (!mounted) return;
    final levels = <String, MasteryLevel>{};
    for (final cat in _categories) {
      levels[cat] = store.levelFor(cat);
    }
    setState(() => _masteryLevels = levels);
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;

    return Container(
      decoration: BoxDecoration(gradient: AppTheme.backgroundGradient(context)),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku ? 'Kategorî' : 'Kategoriler',
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          ku
                              ? 'Kategoriyekê hilbijêre û dest pê bike'
                              : 'Bir kategori seç ve başla',
                          style: TextStyle(
                            color: AppTheme.textMutedColor(context),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossCount = 2;
                  if (constraints.maxWidth > 1200) {
                    crossCount = 5;
                  } else if (constraints.maxWidth > 900) {
                    crossCount = 4;
                  } else if (constraints.maxWidth > 600) {
                    crossCount = 3;
                  }
                  return GridView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _categories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.88,
                    ),
                    itemBuilder: (context, index) {
                      final cat = _categories[index];
                      return _CategoryCard(
                        category: cat,
                        index: index,
                        isKu: ku,
                        masteryLevel: _masteryLevels[cat] ?? MasteryLevel.none,
                        onTap: () => Navigator.of(context).push(
                          AppRoute.to(
                            SubcategoryScreen(
                              repository: widget.repository,
                              category: cat,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
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
    final icon = CategoryVisuals.icon(category);

    return GestureDetector(
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
              // Background circle decoration
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      CategoryNames.localized(category, isKu),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isKu ? '5 ast · pêşbaz' : '5 seviye · yarış',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
