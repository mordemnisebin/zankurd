import 'package:flutter/material.dart';

import '../../config/category_visuals.dart';
import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_theme.dart';
import '../../utils/percent_format.dart';
import 'home_rows.dart' show CategoryProgress;

/// Ana ekranın bölüm başlığı: kısa bir başlık ve tek satır açıklama.
///
/// Ana ekran 2026-09-27'ye kadar "Öğrenme yolları" başlığı altında dört ayrı
/// öğrenme kapısını (ders listesi, seviye yolu, tüm konular, kaldığın yer)
/// üst üste diziyordu. Yeni gelen hangisinin ne olduğunu ayırt edemiyordu.
/// Artık her bölümün tek bir işi var ve başlığı o işi söylüyor.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppTypography.heading2.copyWith(
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textMutedColor(context),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}

/// İlk oturumda görünen üç adımlık yol gösterici.
///
/// Uygulamaya ilk giren kişi iki soruyu yanıtlamak zorunda: "burada ne
/// yapılıyor?" ve "nereden başlarım?". Ana ekran bunu yalnız düzeniyle
/// anlatmaya çalışıyordu. Bu kart aynı şeyi üç cümleyle söyler ve oyuncu
/// ilk turunu bitirince kaybolur (bkz. `HomeScreen._firstSession`).
class HomeFirstSteps extends StatelessWidget {
  const HomeFirstSteps({required this.isKu, super.key});

  final bool isKu;

  @override
  Widget build(BuildContext context) {
    final steps = [
      Tr.forKu(K.homeStep1, isKu),
      Tr.forKu(K.homeStep2, isKu),
      Tr.forKu(K.homeStep3, isKu),
    ];
    final accent = AppColors.readableAccent(context, AppTheme.playGreen);
    return Container(
      key: const ValueKey('home-first-steps'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppTheme.borderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              Tr.forKu(K.homeStepsTitle, isKu),
              style: AppTypography.bodyLarge.copyWith(
                color: AppTheme.textPrimaryColor(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < steps.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.iconTileBg(context, AppTheme.playGreen),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.caption.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      steps[i],
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (i != steps.length - 1) const SizedBox(height: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

/// Ana ekranın iki kapısı: öğrenme alanı ve yarış.
///
/// Uygulama iki şeyi birden yapar: Kurmancî ve Kürt kültürünü öğretir,
/// insanları birbiriyle yarıştırır. Bu ikiliği ilk bakışta göstermek için
/// iki kapı hero'nun hemen altında yan yana durur. Yarış kapısı eskiden
/// yalnız ikinci oturumdan sonra, sayfanın dibinde düz bir satırdı; yeni
/// gelen, uygulamada yarış olduğunu ancak alt menüden tahmin edebiliyordu.
class HomeDoors extends StatelessWidget {
  const HomeDoors({required this.learn, required this.play, super.key});

  final HomeDoorTile learn;
  final HomeDoorTile play;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 18;
        if (constraints.maxWidth < 340 || largeText) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              learn,
              const SizedBox(height: AppSpacing.sm),
              play,
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: learn),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: play),
            ],
          ),
        );
      },
    );
  }
}

/// Kapılardan biri: renkli ikon, başlık, tek satırlık vaat.
class HomeDoorTile extends StatelessWidget {
  const HomeDoorTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLight(context);
    final background = Color.alphaBlend(
      accent.withValues(alpha: isLight ? 0.08 : 0.16),
      AppTheme.surfaceColor(context),
    );
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 128),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: accent.withValues(alpha: isLight ? 0.22 : 0.34),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Icon(
                        icon,
                        size: 19,
                        color: AppColors.onSolid(accent),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      AppIcons.arrowRight,
                      size: 14,
                      color: AppColors.onAccentTint(
                        context,
                        accent,
                        tintAlpha: isLight ? 0.08 : 0.16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyLarge.copyWith(
                    color: AppColors.onTintedSurface(context),
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.onTintedSurface(context, secondary: true),
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Konu ızgarası: her kategori bir karo, ilerleme karonun içinde.
///
/// Eskiden konulara üç ayrı yoldan gidiliyordu: seviye yolunun içindeki
/// "Tüm konular" bağlantısı, ayrı kategori ekranı ve yalnız başlanmış
/// konuları listeleyen "Kaldığın yer". Izgara üçünü tek yerde toplar:
/// bütün konular görünür, başlanmışların ilerlemesi karonun altında durur.
class HomeTopicGrid extends StatelessWidget {
  const HomeTopicGrid({
    required this.isKu,
    required this.categories,
    required this.progress,
    required this.questionCounts,
    required this.onOpen,
    super.key,
  });

  final bool isKu;
  final List<String> categories;
  final Map<String, CategoryProgress> progress;
  final Map<String, int> questionCounts;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 1 : 2;
        const gap = AppSpacing.sm;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          key: const ValueKey('home-topic-grid'),
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final category in categories)
              SizedBox(
                width: tileWidth,
                child: _HomeTopicTile(
                  key: ValueKey('home-topic-$category'),
                  category: category,
                  isKu: isKu,
                  progress: progress[category],
                  questionCount: questionCounts[category],
                  onTap: onOpen == null ? null : () => onOpen!(category),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _HomeTopicTile extends StatelessWidget {
  const _HomeTopicTile({
    required this.category,
    required this.isKu,
    required this.progress,
    required this.questionCount,
    required this.onTap,
    super.key,
  });

  final String category;
  final bool isKu;
  final CategoryProgress? progress;
  final int? questionCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = CategoryNames.localized(category, isKu);
    final color = CategoryVisuals.color(category);
    final ratio = progress?.ratio ?? 0;
    final started = ratio > 0;
    final count = questionCount;
    final meta = started
        ? context.percentRatio(ratio)
        : count == null
        ? null
        : '$count ${Tr.forKu(K.soru, isKu)}';

    return Semantics(
      button: onTap != null,
      label: meta == null ? name : '$name, $meta',
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: onTap,
          excludeFromSemantics: true,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppTheme.borderColor(context)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.iconTileBg(context, color),
                    borderRadius: BorderRadius.circular(AppRadius.badge),
                  ),
                  child: Icon(
                    CategoryVisuals.icon(category),
                    size: 17,
                    color: AppColors.readableAccent(context, color),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppTheme.textPrimaryColor(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      if (started) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 4,
                            backgroundColor: AppTheme.borderColor(context),
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ),
                      ] else if (meta != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: AppTheme.textMutedColor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
