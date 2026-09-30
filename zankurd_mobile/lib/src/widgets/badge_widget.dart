import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Rozet görsel widget'ı — profil ekranında ve sonuç ekranında kullanılır.
class BadgeWidget extends StatelessWidget {
  const BadgeWidget({
    required this.badgeId,
    required this.titleKu,
    required this.titleTr,
    required this.descriptionKu,
    required this.descriptionTr,
    required this.iconName,
    required this.isUnlocked,
    required this.isKu,
    super.key,
  });

  final String badgeId;
  final String titleKu;
  final String titleTr;
  final String descriptionKu;
  final String descriptionTr;
  final String iconName;
  final bool isUnlocked;
  final bool isKu;

  String get title => isKu ? titleKu : titleTr;
  String get description => isKu ? descriptionKu : descriptionTr;

  IconData get _icon {
    return switch (iconName) {
      'emoji_events' => AppIcons.trophy,
      'workspace_premium' => AppIcons.medal,
      'military_tech' => AppIcons.medal,
      'stars' => AppIcons.star,
      'speed' => AppIcons.gaugeHigh,
      _ => AppIcons.idBadge,
    };
  }

  @override
  Widget build(BuildContext context) {
    // 2026-09-29 Şahnê: rozet karosu yüzey kartıdır (Perde, L pah).
    // Kazanılmış rozet: altın kaş (Halka 1) + Zêr dolgulu M karo, koyu ikon
    // (`onGold`) ve "kazanıldı" Rast tonu + ✓. Kilitli: gündüz kenarı, Ray
    // karo, üçüncül ikon ve kilit. Durum yalnız renkle verilmez (✓ / kilit).
    // Bulanık gölge ve gradyan yok.
    final t = SahneTokens.of(context);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: t.s1,
        shape: SahneShape.withSide(
          SahneShape.l,
          isUnlocked ? t.gold : t.edge,
          width: isUnlocked ? SahneRing.r1 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x1,
          vertical: SahneSpace.x2,
        ),
        // Dar ızgara hücresinde büyük yazı taşmasın: içerik küçülerek sığar.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 104,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: ShapeDecoration(
                    color: isUnlocked ? t.gold : t.s3,
                    shape: SahneShape.m,
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      _icon,
                      color: isUnlocked ? t.onGold : t.tx3,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: SahneSpace.x2),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: SahneType.captionStrong.copyWith(
                    color: isUnlocked ? t.tx : t.tx2,
                  ),
                ),
                const SizedBox(height: SahneSpace.x1),
                if (isUnlocked)
                  DecoratedBox(
                    decoration: ShapeDecoration(
                      color: t.okTint,
                      shape: SahneShape.s,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SahneSpace.x1,
                      ),
                      // Onay işareti metin değil ikon: U+2713 yazı tipinde
                      // yok, sistem yazı tipine düşüyordu (2026-07-26).
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(AppIcons.check, size: 12, color: t.okTx),
                          const SizedBox(width: SahneSpace.x1),
                          // 2026-09-30 simülatör: "Hat qezenckirin" 104
                          // px'lik sütunda satıra sığmayıp yanda 27 px
                          // taşıyordu (Kurmancî etiket Türkçeden uzun;
                          // turlar Türkçe ve 1.0 ölçekteydi). Etiket
                          // sütuna sığar, gerekirse ikinci satıra iner.
                          Flexible(
                            child: Text(
                              Tr.forKu(K.kazanildi, isKu),
                              textAlign: TextAlign.center,
                              style: SahneType.caption.copyWith(color: t.okTx),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Icon(AppIcons.lock, size: 16, color: t.tx3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
