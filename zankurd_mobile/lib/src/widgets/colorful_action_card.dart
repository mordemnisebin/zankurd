import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Oyun/aksiyon mod kartı — Kategorî'nin kompakt satır diliyle tutarlı:
/// koyu düz yüzey + sol renkli ikon çipi + başlık/alt başlık + sağ ok.
/// Eski "Pirs-inspired" büyük gradyan zemin + köşe filigran ikon deseni
/// (Faz 0-6'da mockup'ta referansı olmadığı için hiç güncellenmemişti)
/// burada terk edildi; her modun kimlik rengi artık ikon çipinde yaşıyor.
class ColorfulActionCard extends StatelessWidget {
  const ColorfulActionCard({
    required this.title,
    required this.icon,
    required this.colors,
    required this.onTap,
    this.subtitle,
    this.loading = false,
    this.semanticLabel,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;
  final bool loading;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint = colors.first;

    // 2026-07-23 canlı UX denetimi: Pêşbazî merkezindeki mod kartları
    // ("Şerê 1vs1 Şerê 1vs1 Bot + Zindî") ekran okuyucuda çift okunuyordu —
    // dıştaki Semantics(label:) zaten tam adı sağlıyordu ama içteki başlık
    // Text'i ayrıca kendi semantics düğümünü ekliyordu. Aynı desen
    // (styled_button.dart CTA çift okuma düzeltmesi, M28) burada da
    // uygulandı: görünür içerik ExcludeSemantics ile dışlandı, label alt
    // başlığı da içerecek şekilde genişletildi ki bilgi kaybı olmasın.
    final effectiveLabel =
        semanticLabel ??
        (subtitle != null && !loading ? '$title. $subtitle' : title);
    return Semantics(
      button: true,
      enabled: !loading,
      label: effectiveLabel,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: loading ? null : onTap,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            child: Ink(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: AppTheme.cardDecorationByType(
                context,
                type: CardType.secondary,
                radius: AppTheme.cardRadius,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: tint.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AppTheme.cardRadiusSmall,
                        ),
                        border: Border.all(color: tint.withValues(alpha: 0.2)),
                      ),
                      child: Icon(icon, color: tint, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.heading2.copyWith(
                              color: AppTheme.textPrimaryColor(context),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (loading)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: tint,
                                  strokeWidth: 2.2,
                                ),
                              ),
                            )
                          else if (subtitle != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.caption.copyWith(
                                  color: AppTheme.textSubColor(context),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!loading)
                      Icon(
                        AppIcons.chevronRight,
                        color: AppTheme.textMutedColor(context),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
