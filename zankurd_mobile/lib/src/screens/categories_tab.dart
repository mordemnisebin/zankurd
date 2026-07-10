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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.isKu
                  ? 'Kategorî nehatin barkirin. Ji kerema xwe rûpelê nû bike.'
                  : 'Kategoriler yüklenemedi. Lütfen sayfayı yenileyin.',
            ),
          ),
        );
      }
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
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    margin: const EdgeInsets.only(right: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: AppGradients.accentVertical,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ku ? 'Kategorî' : 'Kategoriler',
                          style: AppTypography.display.copyWith(
                            color: AppTheme.textPrimaryColor(context),
                            fontSize: 28,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          ku
                              ? 'Kategoriyekê hilbijêre û dest pê bike'
                              : 'Bir kategori seç ve başla',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppTheme.textMutedColor(context),
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
                        color: AppTheme.primaryGradientStart,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bottomPadding =
                      MediaQuery.paddingOf(context).bottom + AppSpacing.xxl;
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
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.sm,
                      AppSpacing.page,
                      bottomPadding,
                    ),
                    itemCount: _categories.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      mainAxisSpacing: AppSpacing.gridGap,
                      crossAxisSpacing: AppSpacing.gridGap,
                      childAspectRatio: 0.84,
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

class _CategoryCard extends StatefulWidget {
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
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _entryController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    final start = (widget.index * 0.08).clamp(0.0, 0.6);
    final end = (start + 0.5).clamp(start + 0.1, 1.0);
    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = AppTheme.categoryGradient(widget.index);
    final glowColor = AppTheme
        .categoryGradients[widget.index % AppTheme.categoryGradients.length]
        .first;
    final image = CategoryVisuals.imagePath(widget.category);
    final icon = CategoryVisuals.icon(widget.category);
    final radius = BorderRadius.circular(AppRadius.card);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: Container(
              decoration: AppTheme.categoryCardDecoration(glowColor),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: AppGradients.categoryFallback(gradient),
                            ),
                            child: Center(
                              child: Icon(
                                icon,
                                color: Colors.white.withValues(alpha: 0.74),
                                size: 48,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: AppGradients.categoryImageOverlay(gradient),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -24,
                      top: -24,
                      child: Container(
                        width: 112,
                        height: 112,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.07),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    if (widget.masteryLevel != MasteryLevel.none)
                      Positioned(
                        top: AppSpacing.md,
                        right: AppSpacing.md,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: AppTheme.gold.withValues(alpha: 0.60),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.gold.withValues(alpha: 0.18),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                widget.masteryLevel.icon,
                                color: AppTheme.gold,
                                size: 11,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isKu
                                    ? widget.masteryLevel.titleKu
                                    : widget.masteryLevel.titleTr,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.20),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(icon, color: Colors.white, size: 24),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.28),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1.1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Uzun adlar ("Paradigma") kırpılmasın diye
                                // tek satırda otomatik küçülür.
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    CategoryNames.localized(
                                      widget.category,
                                      widget.isKu,
                                    ),
                                    style: AppTypography.categoryTitle,
                                    maxLines: 1,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.layers_outlined,
                                      color: Colors.white.withValues(
                                        alpha: 0.82,
                                      ),
                                      size: 13,
                                    ),
                                    const SizedBox(width: 5),
                                    Flexible(
                                      child: Text(
                                        widget.isKu
                                            ? '5 ast • pêşbaz'
                                            : '5 seviye • yarış',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.categoryMeta,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
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
        ),
      ),
    );
  }
}
