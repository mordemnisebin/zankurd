import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../utils/app_route.dart';
import 'categories_tab.dart';
import 'home_screen.dart';
import 'subcategory_screen.dart';

/// Faz 3: Birleşik "Fêr Bibe" sekmesi. Ana ekran içeriğini ([HomeScreen])
/// gösterir ve Kategorî akışını ayrı bir sekme yerine bu ekran içinden
/// erişilebilir kılar (kart → push [CategoriesTab]).
class LearnHomeScreen extends StatelessWidget {
  const LearnHomeScreen({
    required this.repository,
    this.displayName,
    this.scrollController,
    this.refreshSignal,
    this.onOpenLearning,
    this.onOpenPlay,
    super.key,
  });

  final ZanKurdRepository repository;
  final String? displayName;
  final ScrollController? scrollController;
  final Listenable? refreshSignal;
  final Future<void> Function()? onOpenLearning;
  final VoidCallback? onOpenPlay;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      repository: repository,
      displayName: displayName,
      scrollController: scrollController,
      refreshSignal: refreshSignal,
      onOpenLearning: onOpenLearning,
      onOpenPlay: onOpenPlay,
      onOpenCategories: () async {
        await Navigator.of(
          context,
        ).push(AppRoute.to(CategoriesTab(repository: repository)));
      },
      // "Kaldığın yer" satırı artık genel listeye değil doğrudan dokunulan
      // kategoriye gider (2026-08-14 denetimi, bkz. home_screen.dart
      // HomeScreen.onOpenCategory doc yorumu).
      onOpenCategory: (category) async {
        await Navigator.of(context).push(
          AppRoute.to(
            SubcategoryScreen(repository: repository, category: category),
          ),
        );
      },
    );
  }
}
