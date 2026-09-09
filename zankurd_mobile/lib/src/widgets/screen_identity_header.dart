import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../theme/app_theme.dart';

/// İkincil ekranların ortak kimlik kartı — soft accent gradyan + ikon.
class ScreenIdentityHeader extends StatelessWidget {
  const ScreenIdentityHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    this.compact = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;

  /// Daha alçak kart (liste üstü şerit).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // 2026-07-24 canlı denetim: 34 ekran başlığı 8 farklı renkte zemin
    // taşıyordu (mor ayarlar, altın mağaza, camgöbeği turnuva…) — her ekran
    // başka bir uygulamadan gelmiş gibi görünüyordu. Zemin artık her yerde
    // marka kimliğidir (Kesk); ekrana özgü [accent] yalnız ikon çemberini
    // tonlar. Böylece hem tutarlılık hem ekran kimliği korunur.
    return Semantics(
      header: true,
      container: true,
      child: DecoratedBox(
        decoration: AppTheme.identityHeaderDecoration(
          context,
          radius: AppTheme.panelRadius,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            compact ? AppSpacing.sm : AppSpacing.md,
            AppSpacing.md,
            compact ? AppSpacing.sm : AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 44 : 52,
                height: compact ? 44 : 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.iconTileBg(context, accent),
                  borderRadius: BorderRadius.circular(
                    compact ? AppRadius.sm : AppRadius.md,
                  ),
                  border: Border.all(
                    color: AppColors.readableAccent(
                      context,
                      accent,
                    ).withValues(alpha: 0.22),
                  ),
                ),
                child: Icon(
                  icon,
                  color: AppColors.onAccentTint(context, accent),
                  size: compact ? 22 : 26,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.heading2.copyWith(
                        color: AppTheme.textPrimaryColor(context),
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppTheme.textSubColor(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ana içerik içinde tekrar eden bölüm başlığı.
///
/// Play ve Learning ekranlarının ayrı ayrı tanımladığı başlıklar aynı
/// tipografiyi taşıdığı hâlde küçük spacing/fallback farklarıyla ayrışıyordu.
/// Bu bileşen kart çizmez; yalnız başlık, açıklama ve gerekirse sağ eylemi
/// aynı sakin ritimde hizalar. Böylece sayfanın gerçek CTA'sıyla yarışmaz.
class ScreenSectionHeading extends StatelessWidget {
  const ScreenSectionHeading({
    required this.title,
    this.subtitle,
    this.trailing,
    this.semanticHeader = true,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  /// Normal bölüm başlıkları ekran okuyucuda heading olarak duyurulur.
  /// Başlığın kendisi daha büyük bir düğmenin etiketi olduğunda (ör. Play
  /// "Daha fazla") iç içe button+heading rolü oluşmaması için kapatılabilir.
  final bool semanticHeader;

  @override
  Widget build(BuildContext context) {
    Widget copy() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppTypography.heading2.copyWith(
            color: AppTheme.textPrimaryColor(context),
          ),
        ),
        if (subtitle case final subtitle? when subtitle.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            style: AppTypography.caption.copyWith(
              color: AppTheme.textSubColor(context),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      header: semanticHeader,
      container: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final stackTrailing =
              trailing != null &&
              (constraints.maxWidth < 360 || textScale >= 1.5);

          if (stackTrailing) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                copy(),
                const SizedBox(height: AppSpacing.xs),
                Align(alignment: Alignment.centerRight, child: trailing!),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: copy()),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Bölüm etiketi — sol accent çizgisi + uppercase etiket.
class ScreenSectionLabel extends StatelessWidget {
  const ScreenSectionLabel({
    required this.label,
    required this.accent,
    super.key,
  });

  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, AppSpacing.xs, 2, AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: AppTheme.sectionAccent(accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.upper(label),
              style: AppTypography.caption.copyWith(
                color: AppColors.readableAccent(context, accent),
                letterSpacing: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
