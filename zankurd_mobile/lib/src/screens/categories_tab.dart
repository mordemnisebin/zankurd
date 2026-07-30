import 'package:flutter/material.dart';

import '../config/category_visibility.dart';
import '../config/category_visuals.dart';
import '../data/mastery_store.dart';
import '../data/zankurd_repository.dart';
import '../models/mastery_level.dart';
import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../utils/error_reporter.dart';
import 'subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

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
  // Gizli kategoriler (içerik hazır olana dek) listede gösterilmez.
  late List<String> _categories = visibleCategories(
    widget.repository.categories,
  );
  bool _loading = false;
  Map<String, MasteryLevel> _masteryLevels = {};
  Map<String, int> _masteryCounts = {};
  Map<String, int> _masteryThresholds = {};
  Map<String, int> _questionCounts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final cats = await widget.repository.loadCategories();
      if (mounted && cats.isNotEmpty) {
        setState(() => _categories = visibleCategories(cats));
      }
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
    await _loadQuestionCounts();
  }

  Future<void> _loadQuestionCounts() async {
    try {
      final counts = await widget.repository.loadCategoryQuestionCounts();
      if (mounted && counts.isNotEmpty) {
        setState(() => _questionCounts = counts);
      }
    } catch (error, stack) {
      // Sayılar süs bilgisi; hata durumunda statik metin kalır.
      ErrorReporter.record(error, stack, reason: 'category counts failed');
    }
  }

  Future<void> _loadMastery() async {
    final store = await MasteryStore.load();
    if (!mounted) return;
    final levels = <String, MasteryLevel>{};
    final counts = <String, int>{};
    final thresholds = <String, int>{};
    for (final cat in _categories) {
      levels[cat] = store.levelFor(cat);
      counts[cat] = store.correctCount(cat);
      thresholds[cat] = store.nextThreshold(cat);
    }
    setState(() {
      _masteryLevels = levels;
      _masteryCounts = counts;
      _masteryThresholds = thresholds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    // Ana sayfadan bağımsız route olarak da açılıyor; Material sarmalayıcı
    // olmadan Text'ler sarı alt çizgiyle çizilir ve geri butonu kalmaz.
    final canPop = Navigator.of(context).canPop();

    return Material(
      type: MaterialType.transparency,
      child: Container(
        color: AppTheme.bgOf(context),
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
                    // Geri, uygulamanın her yerinde Material'ın standart
                    // `arrow_back` okudur (AppBar'lı ekranlar, seviye
                    // haritası). Burada [AppIcons.arrowLeft] kullanılıyordu
                    // ve ard arda gezilen üç ekranda üç farklı geri işareti
                    // görünüyordu (2026-07-25 canlı denetimi).
                    if (canPop)
                      BackButton(
                        key: const ValueKey('categories-back-button'),
                        onPressed: () => Navigator.of(context).pop(),
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    Container(
                      key: const ValueKey('categories-header-accent'),
                      width: 4,
                      height: 44,
                      margin: const EdgeInsets.only(right: AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: AppTheme.brand,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t(K.categories),
                            style: AppTypography.heading1.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontSize: 26,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            context.t(K.categoriesSubtitle),
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
                child: _loading && _categories.isEmpty
                    ? _buildSkeletonGrid(context)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final bottomPadding =
                              MediaQuery.paddingOf(context).bottom +
                              AppSpacing.xxl;
                          final isNarrow = constraints.maxWidth <= 600;
                          // Poster kart: dar ekranda tek sütun ~148px yükseklik;
                          // genişte 2 sütun dergi kapağı oranı.
                          final crossCount = isNarrow ? 1 : 2;
                          // Sakin satır kartı: poster yüksekliği gerekmiyor.
                          // Grid'in gerçek çocuk genişliği sayfa boşlukları
                          // çıktıktan sonra kalandır. Tam ekran genişliğiyle
                          // oran hesaplamak kartı fark edilmeden 11 px kadar
                          // kısaltıyordu. Büyük yazıda da iki metin satırı
                          // için kontrollü ek yükseklik gerekir.
                          final textScale =
                              MediaQuery.textScalerOf(context).scale(16) / 16;
                          final targetH =
                              88.0 + (textScale - 1).clamp(0.0, 1.0) * 40.0;
                          final availableWidth =
                              constraints.maxWidth -
                              (2 * AppSpacing.page) -
                              ((crossCount - 1) * AppSpacing.md);
                          final itemWidth = availableWidth / crossCount;
                          final aspectRatio = itemWidth / targetH;
                          return GridView.builder(
                            controller: widget.scrollController,
                            padding: EdgeInsets.fromLTRB(
                              AppSpacing.page,
                              AppSpacing.sm,
                              AppSpacing.page,
                              bottomPadding,
                            ),
                            itemCount: _categories.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossCount,
                                  mainAxisSpacing: AppSpacing.md,
                                  crossAxisSpacing: AppSpacing.md,
                                  childAspectRatio: aspectRatio,
                                ),
                            itemBuilder: (context, index) {
                              final cat = _categories[index];
                              return _CategoryCard(
                                key: ValueKey('category-card-$cat'),
                                category: cat,
                                index: index,
                                isKu: ku,
                                questionCount: _questionCounts[cat],
                                masteryLevel:
                                    _masteryLevels[cat] ?? MasteryLevel.none,
                                masteryCount: _masteryCounts[cat] ?? 0,
                                masteryThreshold: _masteryThresholds[cat] ?? 20,
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
      ),
    );
  }

  Widget _buildSkeletonGrid(BuildContext context) {
    const skeletonCount = 6;
    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomPadding =
            MediaQuery.paddingOf(context).bottom + AppSpacing.xxl;
        final isNarrow = constraints.maxWidth <= 600;
        final crossCount = isNarrow ? 1 : 2;
        final availableWidth =
            constraints.maxWidth -
            (2 * AppSpacing.page) -
            ((crossCount - 1) * AppSpacing.md);
        final aspectRatio = (availableWidth / crossCount) / 120;
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            bottomPadding,
          ),
          itemCount: skeletonCount,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) => const _ShimmerCard(),
        );
      },
    );
  }
}

/// Shimmer / skeleton card shown while categories load.
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _anim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: AppTheme.shimmerGradient(context, _anim.value),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const Spacer(),
                // Title placeholder
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle placeholder
                Container(
                  width: 140,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 16),
                // Progress bar placeholder
                Container(
                  width: double.infinity,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Pirs-inspired vibrant category card with gradient background,
/// prominent icon, clean typography, and a mastery progress bar.
class _CategoryCard extends StatefulWidget {
  const _CategoryCard({
    required this.category,
    required this.index,
    required this.isKu,
    required this.masteryLevel,
    required this.masteryCount,
    required this.masteryThreshold,
    required this.onTap,
    this.questionCount,
    super.key,
  });

  final String category;
  final int index;
  final bool isKu;

  /// Kategorideki onaylı soru sayısı; null ise statik metin gösterilir.
  final int? questionCount;
  final MasteryLevel masteryLevel;
  final int masteryCount;
  final int masteryThreshold;
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
    // Renk kategorinin adından gelir. Daha önce liste sırası (widget.index)
    // kullanılıyordu; alt kategori/quiz ekranları ise repository sırasını
    // kullandığı için aynı kategori ekrandan ekrana renk değiştiriyordu
    // (2026-07-22 canlı UX denetimi).
    final accent = CategoryVisuals.color(widget.category);
    final icon = CategoryVisuals.icon(widget.category);
    final catName = CategoryNames.localized(widget.category, widget.isKu);

    // Mastery progress (0.0 - 1.0)
    final progress = widget.masteryThreshold > 0
        ? (widget.masteryCount / widget.masteryThreshold).clamp(0.0, 1.0)
        : 0.0;
    final hasProgress = widget.masteryLevel != MasteryLevel.none;
    // İçeriği yetersiz kategori (ör. 3 soruluk Teknolojî) oynanabilir gibi
    // sunulmaz; "yakında" olarak işaretlenir ve dokunuş kapatılır.
    final comingSoon =
        widget.questionCount != null && widget.questionCount! < 20;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        // 2026-07-24: poster + dolu gradyan kart yerine sakin satır. Kategori
        // rengi yalnız ikon karosunda ve 3px sol şeritte görünür; sekiz
        // kategori yan yana dururken göz yorulmuyor ve hiçbiri eylem
        // turuncusuyla yarışmıyor.
        child: Semantics(
          button: !comingSoon,
          label: comingSoon
              ? '$catName — ${widget.isKu ? 'Nêzîk de tê' : 'Yakında'}'
              : widget.questionCount != null
              ? '$catName, ${widget.questionCount} ${widget.isKu ? 'pirs' : 'soru'}'
              : catName,
          child: ExcludeSemantics(
            child: GestureDetector(
              onTapDown: comingSoon
                  ? null
                  : (_) => setState(() => _pressed = true),
              onTapUp: comingSoon
                  ? null
                  : (_) {
                      setState(() => _pressed = false);
                      widget.onTap();
                    },
              onTapCancel: () => setState(() => _pressed = false),
              child: AnimatedScale(
                scale: _pressed ? 0.98 : 1.0,
                duration: const Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                child: Opacity(
                  opacity: comingSoon ? 0.55 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      child: Row(
                        children: [
                          // Kategori kimliği: ince renk şeridi.
                          Container(width: 3, height: 74, color: accent),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.sm,
                                AppSpacing.sm,
                                AppSpacing.sm,
                                AppSpacing.sm,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.badge,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              catName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.subtitle
                                                  .copyWith(
                                                    fontSize: 16,
                                                    color:
                                                        AppTheme.textPrimaryColor(
                                                          context,
                                                        ),
                                                  ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              comingSoon
                                                  ? (widget.isKu
                                                        ? 'Nêzîk de tê…'
                                                        : 'Yakında geliyor…')
                                                  : widget.questionCount != null
                                                  ? (widget.isKu
                                                        ? '${widget.questionCount} pirs · 5 ast'
                                                        : '${widget.questionCount} soru · 5 seviye')
                                                  : (widget.isKu
                                                        ? '5 ast'
                                                        : '5 seviye'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTypography.bodyMedium
                                                  .copyWith(
                                                    fontSize: 12.5,
                                                    color:
                                                        AppTheme.textSubColor(
                                                          context,
                                                        ),
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      if (hasProgress)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.pill,
                                            ),
                                            color: accent.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                          child: Text(
                                            widget.isKu
                                                ? widget.masteryLevel.titleKu
                                                : widget.masteryLevel.titleTr,
                                            style: AppTypography.caption
                                                .copyWith(
                                                  fontSize: 10,
                                                  color:
                                                      AppColors.readableAccent(
                                                        context,
                                                        accent,
                                                      ),
                                                ),
                                          ),
                                        )
                                      else
                                        Icon(
                                          comingSoon
                                              ? AppIcons.hourglass
                                              : AppIcons.chevronRight,
                                          size: 14,
                                          color: AppTheme.textMutedColor(
                                            context,
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (hasProgress) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.pill,
                                      ),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 4,
                                        backgroundColor: AppTheme.borderColor(
                                          context,
                                        ),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              accent,
                                            ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
