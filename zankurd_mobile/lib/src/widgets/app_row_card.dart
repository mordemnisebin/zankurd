import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Tek tip satır kartı — ana ekrandaki ikincil eylemlerin tamamı bunu
/// kullanır. 2026-07-24: 11 ayrı kart bileşeni yerine tek bir gövde;
/// kategori/aksan rengi yalnız ikon karosunda görünür, kartın zeminini
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

  /// 2026-09-29 Şahnê: liste satırının standart çeşidi ([SahneListRow.icon]
  /// görünüşü) kendi yüzey kartında — Perde, L pah, gündüzde 1 px kenar;
  /// en az 64; 44'lük M ikon karosu (aksanın rolünün tonu + rol metni
  /// ikon); başlık Gövde 700, alt satır Açıklama; sağda [trailing] ya da
  /// üçüncül chevron. Metin sarar, satır uzar.
  Widget _buildBody(BuildContext context) {
    final t = SahneTokens.of(context);
    final role = sahneRoleFor(accent);
    return SahneTappable(
      shape: SahneShape.withSide(SahneShape.l, t.edge, width: 1),
      color: t.s1,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            SahneSpace.x3,
            SahneSpace.x2,
            SahneSpace.x4,
            SahneSpace.x2,
          ),
          child: Row(
            children: [
              DecoratedBox(
                decoration: ShapeDecoration(
                  color: t.roleTint(role),
                  shape: SahneShape.m,
                ),
                child: SizedBox.square(
                  dimension: 44,
                  child: Icon(icon, size: 24, color: t.roleText(role)),
                ),
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
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: SahneType.caption.copyWith(color: t.tx2),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SahneSpace.x2),
              trailing ?? Icon(AppIcons.chevronRight, size: 20, color: t.tx3),
            ],
          ),
        ),
      ),
    );
  }
}
