import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Tek tip satır kartı — ana ekrandaki ikincil eylemlerin tamamı bunu
/// kullanır. 2026-07-24: 11 ayrı kart bileşeni yerine tek bir gövde;
/// kategori/aksan rengi yalnız 34px ikon karosunda görünür, kartın zeminini
/// asla doldurmaz.
class AppRowCard extends StatelessWidget {
  const AppRowCard({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticValue,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Satırın durumunu anlatan ek değer (ör. "%40"). Ekran okuyucuya
  /// `value` olarak verilir; görsel [trailing] içeriği zaten dışlanır.
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    // Bu kart uygulamadaki neredeyse tüm ikincil gezinme satırlarının
    // gövdesi. Semantiği olmadığı için ekran okuyucu başlık, alt başlık ve
    // varsa sondaki rozeti üç ayrı, bağlamsız metin olarak okuyor; satırın
    // dokunulabilir bir hedef olduğu hiç duyurulmuyordu (2026-07-25
    // denetimi). Tek düğüm + button rolü, satırı kullanan her ekranı
    // birden düzeltir.
    return Semantics(
      button: onTap != null,
      enabled: onTap != null,
      label: subtitle == null ? title : '$title. $subtitle',
      value: semanticValue,
      excludeSemantics: true,
      onTap: onTap,
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor(context),
      borderRadius: BorderRadius.circular(AppTheme.panelRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.panelRadius),
            border: Border.all(color: AppTheme.borderColor(context)),
          ),
          child: Row(
            children: [
              _IconTile(icon: icon, color: accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.subtitle.copyWith(
                        fontSize: 15,
                        color: AppTheme.textPrimaryColor(context),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(
                          fontSize: 12.5,
                          color: AppTheme.textSubColor(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              trailing ??
                  Icon(
                    AppIcons.chevronRight,
                    size: 14,
                    color: AppTheme.textMutedColor(context),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.badge),
      ),
      child: Icon(icon, size: 16, color: Colors.white),
    );
  }
}
