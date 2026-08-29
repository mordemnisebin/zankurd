import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_row_card.dart';
import '../../utils/percent_format.dart';

/// "Kaldığın yer" — oyuncunun ilerlediği kategoriler, ilerleme çubuğuyla.
///
/// Hiç ilerleme yokken bölüm, %0'lık kategorileri "Kaldığın yer" başlığı
/// altında listeliyordu. Artık yalnız gerçekten ilerlenmiş kategoriler
/// listelenir; ilerleme yoksa bölüm çizilmez. Keşif, ders yolunun
/// içindeki "Tüm konular"dır — ikinci bir kapı değildir.
class ContinueSection extends StatelessWidget {
  const ContinueSection({
    required this.isKu,
    required this.entries,
    this.onOpenCategory,
    super.key,
  });

  final bool isKu;
  final List<CategoryProgress> entries;
  final ValueChanged<String>? onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final started = entries.where((e) => e.ratio > 0).toList();
    if (started.isEmpty) return const SizedBox.shrink();
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
