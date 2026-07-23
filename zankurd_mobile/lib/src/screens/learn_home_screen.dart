import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../utils/app_route.dart';
import 'categories_tab.dart';
import 'home_screen.dart';

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
  final VoidCallback? onOpenLearning;
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
      onOpenCategories: () => Navigator.of(
        context,
      ).push(AppRoute.to(CategoriesTab(repository: repository))),
    );
  }
}
