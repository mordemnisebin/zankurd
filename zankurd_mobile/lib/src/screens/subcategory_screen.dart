import 'package:flutter/material.dart';

import '../config/subcategory_config.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/kilim_pattern_painter.dart';
import 'level_screen.dart';

class SubcategoryScreen extends StatelessWidget {
  const SubcategoryScreen({
    required this.repository,
    required this.category,
    super.key,
  });

  final ZanKurdRepository repository;
  final String category;

  @override
  Widget build(BuildContext context) {
    final ku = context.isKu;
    final list = SubcategoryConfig.subcategories[category] ?? const [];
    final catIndex = repository.categories.indexOf(category);
    final gradient = AppTheme.categoryGradient(catIndex >= 0 ? catIndex : 0);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Geri oku her zaman renkli banner'ın üzerinde durur.
        iconTheme: const IconThemeData(color: Colors.white),
        // Başlık banner'da büyük yazılıyor; app bar'da tekrar etmiyoruz.
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              // Geometric category banner
              _CategoryBanner(category: category, gradient: gradient, isKu: ku),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sub = list[index];
                    return _SubcategoryCard(
                      info: sub,
                      isKu: ku,
                      gradient: gradient,
                      onTap: () {
                        Navigator.of(context).push(
                          AppRoute.to(
                            LevelScreen(
                              repository: repository,
                              category: category,
                              subCategory: sub.id,
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
}

class _CategoryBanner extends StatelessWidget {
  const _CategoryBanner({
    required this.category,
    required this.gradient,
    required this.isKu,
  });

  final String category;
  final LinearGradient gradient;
  final bool isKu;

  static IconData _bannerIcon(String category) {
    return switch (category) {
      'Ziman' => Icons.translate_rounded,
      'Çand' => Icons.diversity_2_rounded,
      'Dîrok' => Icons.account_balance_rounded,
      'Edebiyat' => Icons.auto_stories_rounded,
      'Cografya' => Icons.terrain_rounded,
      'Muzîk' => Icons.music_note_rounded,
      'Siyaset' => Icons.gavel_rounded,
      'Paradigma' => Icons.psychology_alt_rounded,
      _ => Icons.school_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final color1 = Colors.white.withValues(alpha: 0.08);
    final color2 = Colors.white.withValues(alpha: 0.03);

    return Container(
      height: 150 + topInset,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: gradient,
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Soft Glow 1
          Positioned(
            right: -40,
            top: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color1, color1.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          // Soft Glow 2
          Positioned(
            left: -50,
            bottom: -50,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color2, color2.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          // Kilim deseni filigranı — kültürel doku
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: const KilimPatternPainter(
                  drawPattern: true,
                  color: Colors.white,
                  opacity: 0.05,
                ),
              ),
            ),
          ),
          // Büyük filigran kategori ikonu — boşluğu dolduran görsel imza
          Positioned(
            right: -18,
            bottom: -26,
            child: Icon(
              _bannerIcon(category),
              size: 150,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  CategoryNames.localized(category, isKu),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isKu
                      ? 'Barekî hilbijêre û dest bi lîstinê bike.'
                      : 'Bir alt alan seçerek yarışmaya başla.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryCard extends StatelessWidget {
  const _SubcategoryCard({
    required this.info,
    required this.isKu,
    required this.gradient,
    required this.onTap,
  });

  final SubcategoryInfo info;
  final bool isKu;
  final LinearGradient gradient;
  final VoidCallback onTap;

  IconData _iconForId(String id) {
    return switch (id) {
      'reziman' ||
      'diroka_kevn' ||
      'helbest' ||
      'ciya_cem' ||
      'dengbeji' ||
      'diroka_siyasi' ||
      'demokratik' => Icons.library_books_outlined,
      'peyvnasi' ||
      'diroka_nujen' ||
      'klasik' ||
      'bajar_ci' ||
      'nujen' ||
      'siyaseta_nujen' ||
      'ekoloji' => Icons.menu_book_outlined,
      'rastnivisin' ||
      'sexsiyet' ||
      'roman' ||
      'sinor_duma' ||
      'amur' ||
      'tevger' ||
      'jineoloji' => Icons.draw_outlined,
      _ => Icons.bookmark_added_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = isKu ? info.nameKu : info.nameTr;
    final desc = isKu ? info.descriptionKu : info.descriptionTr;
    final icon = _iconForId(info.id);
    final tint = gradient.colors.first;

    return ClipRRect(
      key: ValueKey('subcategory-card-${info.id}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tint.withValues(alpha: 0.22), width: 1.1),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
              spreadRadius: -6,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -14,
              bottom: -18,
              child: Icon(icon, size: 92, color: tint.withValues(alpha: 0.10)),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppRadius.card),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: gradient,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: tint.withValues(alpha: 0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textPrimaryColor(context),
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              desc,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppTheme.textMutedColor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Dar ekranda taşmamak için chip'ler sarmalanır.
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _LevelChip(
                                  icon: Icons.stairs_rounded,
                                  label: isKu ? '5 ast' : '5 seviye',
                                  tint: tint,
                                ),
                                _LevelChip(
                                  icon: Icons.bolt_rounded,
                                  label: isKu ? 'Pêşbaz' : 'Yarış',
                                  tint: tint,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: tint,
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(color: tint.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: tint),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimaryColor(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
