import 'package:flutter/material.dart';

import '../config/category_visuals.dart';
import 'sahne/sahne.dart';

/// Soru künyesinin (ve benzer üst etiketlerin) kategori işareti.
///
/// Konunun silüeti varsa ana sayfa karosundaki ÇİZİM ([SahneTopicMarkBadge]),
/// yoksa eski çizgi ikon. Künye ile karo aynı konuyu aynı çizimle anlatır;
/// silüetsiz (bilinmeyen) kategori ikon + [fallbackColor]a düşer.
class CategoryKickerMark extends StatelessWidget {
  const CategoryKickerMark({
    super.key,
    required this.category,
    required this.fallbackColor,
    this.size = 28,
  });

  final String category;
  final Color fallbackColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final mark = CategoryVisuals.mark(category);
    if (mark == null) {
      return Icon(
        CategoryVisuals.icon(category),
        size: 20,
        color: fallbackColor,
      );
    }
    return SahneTopicMarkBadge(
      mark: mark,
      tone: CategoryVisuals.tone(category),
      size: size,
    );
  }
}
