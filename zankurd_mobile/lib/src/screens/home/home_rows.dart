import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_row_card.dart';
import '../../utils/percent_format.dart';
import '../../theme/app_icons.dart';

/// "Kaldığın yer" — oyuncunun ilerlediği kategoriler, ilerleme çubuğuyla.
///
/// Hiç ilerleme yokken bölüm, %0'lık kategorileri "Kaldığın yer" başlığı
/// altında listeliyordu: kullanıcı hiçbir yerde kalmamışken üç satır
/// "Henüz başlamadın" diyordu (2026-07-25 canlı denetimi). Artık yalnız
/// gerçekten ilerlenmiş kategoriler "Kaldığın yer" olur; ilerleme yoksa
/// bölüm bir keşif davetine dönüşür.
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    required this.isKu,
    required this.entries,
    this.onOpenCategory,
    this.onBrowseCategories,
    super.key,
  });

  final bool isKu;
  final List<CategoryProgress> entries;
  final ValueChanged<String>? onOpenCategory;

  /// Tüm kategori listesini açar — ilerleme yokken gösterilen davet.
  final VoidCallback? onBrowseCategories;

  @override
  Widget build(BuildContext context) {
    final started = entries.where((e) => e.ratio > 0).toList();
    if (started.isEmpty) return _buildDiscovery(context);
    return Column(
      key: const ValueKey('home-continue-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: 2),
          child: Text(
            Tr.forKu(K.kaldiginYer, isKu),
            style: AppTypography.heading2.copyWith(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        for (final entry in started)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            // Satır dokunulabilir bir gezinme hedefidir; semantiği
            // [AppRowCard] taşır. Görsel ilerleme çubuğu `trailing` içinde
            // ExcludeSemantics ile dışlanır, oran ise `semanticValue`
            // olarak duyurulur — aksi halde LinearProgressIndicator kendi
            // rolünü yukarı taşıyıp satırı "progressbar" gibi sunuyordu
            // (2026-07-25 denetimi).
            child: AppRowCard(
              icon: CategoryVisuals.icon(entry.category),
              accent: CategoryVisuals.color(entry.category),
              title: CategoryNames.localized(entry.category, isKu),
              subtitle: Tr.forKu(K.pPDogru, isKu, {
                'p0': '${entry.correct}',
                'p1': '${entry.threshold}',
              }),
              semanticValue: context.percentRatio(entry.ratio),
              onTap: onOpenCategory == null
                  ? null
                  : () => onOpenCategory!(entry.category),
              trailing: ExcludeSemantics(
                child: SizedBox(
                  width: 52,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.percentRatio(entry.ratio),
                        style: AppTypography.caption.copyWith(
                          color: AppTheme.textMutedColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: LinearProgressIndicator(
                          value: entry.ratio,
                          minHeight: 4,
                          backgroundColor: AppTheme.borderColor(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            CategoryVisuals.color(entry.category),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Hiç ilerleme yokken: yanlış başlıklı bir "%0" listesi yerine tek bir
  /// keşif satırı. Kategori listesi ana ekrandan başka türlü görünür
  /// değildi — bu satır aynı zamanda o gezinme boşluğunu kapatır.
  Widget _buildDiscovery(BuildContext context) {
    if (onBrowseCategories == null) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-discover-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: 2),
          child: Text(
            Tr.forKu(K.start, isKu),
            style: AppTypography.heading2.copyWith(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        AppRowCard(
          key: const ValueKey('home-browse-categories-row'),
          icon: AppIcons.layerGroup,
          accent: AppTheme.brand,
          title: Tr.forKu(K.tumKategoriler, isKu),
          subtitle: Tr.forKu(K.birKonuSecVe, isKu),
          onTap: onBrowseCategories,
        ),
      ],
    );
  }
}

/// Bir kategorideki ustalık ilerlemesi (MasteryStore verisinden türetilir).
class CategoryProgress {
  const CategoryProgress({
    required this.category,
    required this.correct,
    required this.threshold,
  });

  final String category;
  final int correct;
  final int threshold;

  double get ratio =>
      threshold <= 0 ? 0 : (correct / threshold).clamp(0.0, 1.0);
}
