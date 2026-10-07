import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_theme.dart';
import '../theme/kilim_motifs.dart';
import 'sahne/sahne.dart';

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
    if (isPrimary) {
      // Birincil mod bir sahne kartıdır: iki temada da gece. İçindeki her
      // renk gece belirteçlerinden gelir.
      return SahneStage(
        stage: AppTheme.stage,
        child: Builder(builder: (context) => _card(context, stage: true)),
      );
    }
    return _card(context, stage: false);
  }

  Widget _card(BuildContext context, {required bool stage}) {
    final t = SahneTokens.of(context);
    final isEvent = emphasis == ModeCardEmphasis.event;
    final role = sahneRoleFor(accent);
    // 2026-09-29 Şahnê:
    //  - birincil: gece sahne zemini (L pah) — yüzeylerden ayrılır ama
    //    Agir'i taşımaz; Agir ekranın birincil düğmesidir.
    //  - ikincil: yüzey kartı (Perde, gündüzde 1 px kenar), amblem rolün
    //    ton karosu + rol metni ikon.
    //  - etkinlik: rolün ton zemini (ör. Zêr — "ödül bileti" gibi ısınır),
    //    amblem dolu rol rengi + koyu ikon.
    // Gradyan ve bulanık gölge yok (`home_play_hierarchy_test.dart`).
    final surface = stage
        ? SahneStageColors.top
        : isEvent
        ? t.roleTint(role)
        : t.s1;
    final shape = SahneShape.withSide(
      SahneShape.l,
      stage ? SahneStageColors.top : t.edge,
      width: 1,
    );
    final (tileBg, tileFg) = isEvent
        ? (
            role == SahneRole.gold ? t.gold : t.roleText(role),
            role == SahneRole.gold ? t.onGold : t.bg,
          )
        : (t.roleTint(role), t.roleText(role));
    final enabled = !busy && onTap != null;
    final tile = compact ? 40.0 : 44.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      onTap: enabled ? onTap : null,
      child: ExcludeSemantics(
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: shape,
            child: Ink(
              decoration: ShapeDecoration(color: surface, shape: shape),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  SahneSpace.x4,
                  compact ? SahneSpace.x3 : SahneSpace.x4,
                  SahneSpace.x4,
                  compact ? SahneSpace.x3 : SahneSpace.x4,
                ),
                child: Row(
                  children: [
                    Container(
                      width: tile,
                      height: tile,
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: tileBg,
                        shape: SahneShape.m,
                      ),
                      child: Icon(icon, color: tileFg, size: compact ? 20 : 24),
                    ),
                    const SizedBox(width: SahneSpace.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: SahneType.bodyStrong.copyWith(color: t.tx),
                          ),
                          Text(
                            subtitle,
                            style: SahneType.caption.copyWith(color: t.tx2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SahneSpace.x2),
                    if (busy)
                      SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(t.goldTx),
                        ),
                      )
                    else
                      Icon(AppIcons.chevronRight, size: 20, color: t.tx3),
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
