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
                  shape: BoxShape.circle,
                  color: Color.alphaBlend(
                    accent.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.16),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(icon, color: Colors.white, size: compact ? 22 : 26),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.heading2.copyWith(
                        color: Colors.white,
                        fontSize: compact ? 17 : 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
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

/// Bölüm başlığı — sol accent çizgisi + uppercase etiket.
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
