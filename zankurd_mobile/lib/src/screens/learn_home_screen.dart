import 'package:flutter/material.dart';

import '../data/zankurd_repository.dart';
import '../utils/app_route.dart';
import 'home_screen.dart';
import 'subcategory_screen.dart';

/// Faz 3: Birleşik "Fêr Bibe" sekmesi. Ana ekran içeriğini ([HomeScreen])
/// gösterir; kategoriler ana ekrandaki konu ızgarasından doğrudan
/// [SubcategoryScreen]'e açılır.
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
      // Konu ızgarasında dokunulan kategori doğrudan açılır (bkz.
      // home_screen.dart HomeScreen.onOpenCategory).
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
