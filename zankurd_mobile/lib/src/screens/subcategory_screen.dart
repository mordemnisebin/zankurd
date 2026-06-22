import 'package:flutter/material.dart';

import '../config/subcategory_config.dart';
import '../data/zankurd_repository.dart';
import '../l10n/lang.dart';
import '../theme/app_theme.dart';
import '../utils/app_route.dart';
import '../widgets/app_panel.dart';
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          CategoryNames.localized(category, ku),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
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
              _CategoryBanner(
                category: category,
                gradient: gradient,
                isKu: ku,
              ),
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

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      height: 150 + topInset,
      width: double.infinity,
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isKu ? 'Barekî hilbijêre û dest bi lîstinê bike.' : 'Bir alt alan seçerek yarışmaya başla.',
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
      'reziman' || 'diroka_kevn' || 'helbest' || 'ciya_cem' || 'dengbeji' || 'diroka_siyasi' || 'demokratik' => Icons.library_books_outlined,
      'peyvnasi' || 'diroka_nujen' || 'klasik' || 'bajar_ci' || 'nujen' || 'siyaseta_nujen' || 'ekoloji' => Icons.menu_book_outlined,
      'rastnivisin' || 'sexsiyet' || 'roman' || 'sinor_duma' || 'amur' || 'tevger' || 'jineoloji' => Icons.draw_outlined,
      _ => Icons.bookmark_added_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = isKu ? info.nameKu : info.nameTr;
    final desc = isKu ? info.descriptionKu : info.descriptionTr;
    final icon = _iconForId(info.id);

    return AppPanel(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: gradient.colors.first.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: gradient.colors.first.withValues(alpha: 0.25)),
                ),
                child: Icon(icon, color: gradient.colors.first, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.textPrimaryColor(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        color: AppTheme.textMutedColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTheme.textMutedColor(context)),
            ],
          ),
        ),
      ),
    );
  }
}
