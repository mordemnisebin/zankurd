import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/kilim_motifs.dart';

/// Visual priority for a mode entry.
///
/// A mode keeps its identity in the emblem, while the card surface follows the
/// shared ZanKurd hierarchy. This prevents every mode from looking like a
/// separate campaign tile.
enum ModeCardEmphasis { primary, secondary, event }

/// Ana sayfa ve Oyna merkezindeki ortak mod kartı.
///
/// Birincil mod yalnız marka yeşiliyle öne çıkar; kategori rengi kartın
/// tamamını boyamaz. Ama 2026-09-27'ye kadar ikincil ve etkinlik modları
/// TEK bir soluk amblemin dışında hiç renk taşımıyordu — sahip oyun
/// merkezini bu yüzden "renksiz" buldu. İki değişiklik bunu düzeltir, ikisi
/// de `home_play_hierarchy_test.dart`daki "düz yüzey: gradyan/gölge yok"
/// bekçisini bozmadan:
///  - İkincil ve etkinlik amblemleri artık DOLU aksan rengi taşır (önce
///    soluk bir tondu), ikon üstünde `AppColors.onSolid` ile okunur kalır.
///  - Etkinlik kartının YÜZEYİ aksanın hafif bir tonuyla karışır
///    (`Color.alphaBlend`) — gradyan değil, düz bir renk karışımı; kart hâlâ
///    listenin geri kalanıyla aynı düz geometriyi paylaşır ama "ödül
///    bileti" gibi hafifçe ısınır.
/// Kategori kimliği yine kartı ayrı bir kampanya afişine çevirmez: ikon +
/// başlık + bu iki rol (ikincil/etkinlik) üzerinden anlatılır.
class ModeCard extends StatelessWidget {
  const ModeCard({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.motif = KilimMotif.step,
    this.compact = false,
    this.busy = false,
    this.emphasis = ModeCardEmphasis.primary,
    super.key,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final KilimMotif motif;

  /// Sunucu isteği sürerken chevron yerine ilerleme gösterilir ve dokunuş
  /// kapanır; çift dokunuş ikinci bir istek başlatmamalı.
  final bool busy;

  /// Dar düzende yüksekliği kısar; iki satır metin yerine bir satır.
  final bool compact;
  final ModeCardEmphasis emphasis;

  @override
  Widget build(BuildContext context) {
    final isPrimary = emphasis == ModeCardEmphasis.primary;
    final isEvent = emphasis == ModeCardEmphasis.event;
    final accentOnSurface = AppColors.readableAccent(context, accent);
    final progressColor = isPrimary ? Colors.white : accentOnSurface;
    final titleColor = isPrimary
        ? Colors.white
        : AppTheme.textPrimaryColor(context);
    final subtitleColor = isPrimary
        ? Colors.white.withValues(alpha: 0.88)
        : AppTheme.textSubColor(context);
    // Etkinlik yüzeyi: aksanın hafif bir tonu düz kart zeminine karışır
    // (gradyan DEĞİL — `home_play_hierarchy_test.dart` bu kartlarda
    // gradyan/gölge OLMAMASINI bekler). Karanlıkta biraz daha yüksek alfa
    // kullanılır çünkü koyu zemin aynı oranı daha soluk emiyor; ikisi de
    // `test/play_hub_stage_test.dart`ta metin kontrastına (≥4.5:1) karşı
    // ölçülür.
    final eventSurface = Color.alphaBlend(
      accent.withValues(alpha: AppTheme.isLight(context) ? 0.16 : 0.20),
      AppTheme.surfaceColor(context),
    );
    final cardDecoration = BoxDecoration(
      color: isPrimary
          ? AppTheme.culturalBrandBg
          : (isEvent ? eventSurface : AppTheme.surfaceColor(context)),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: isPrimary
            ? Colors.white.withValues(alpha: 0.10)
            : (isEvent
                  ? accent.withValues(alpha: 0.5)
                  : AppTheme.borderColor(context)),
      ),
      boxShadow: isPrimary ? AppTheme.cardShadow(context) : const <BoxShadow>[],
    );
    final enabled = !busy && onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Ink(
              decoration: cardDecoration,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  compact ? AppSpacing.sm : AppSpacing.md,
                  AppSpacing.md,
                  compact ? AppSpacing.sm : AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Container(
                      width: compact ? 40 : 44,
                      height: compact ? 40 : 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        // İkincil ve etkinlik amblemleri DOLU aksan rengi
                        // taşır (önce soluk bir tondu — `iconTileBg` — ve
                        // ekranın tek renkli anını CTA'ya bırakıyordu; sahip
                        // bunu "renksiz" olarak adlandırdı). İkon üstünde
                        // `onSolid` ile okunur kalır.
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.10)
                            : accent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        icon,
                        color: isPrimary
                            ? Colors.white
                            : AppColors.onSolid(accent),
                        size: compact ? 20 : 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: AppTypography.subtitle.copyWith(
                              fontSize: compact ? 16 : 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: titleColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTypography.caption.copyWith(
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    if (busy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progressColor,
                          ),
                        ),
                      )
                    else
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isPrimary
                            ? Colors.white.withValues(alpha: 0.82)
                            : AppTheme.textMutedColor(context),
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
