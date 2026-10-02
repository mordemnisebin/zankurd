import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../models/daily_mission.dart';
import 'sahne/sahne.dart';

/// Görev tamamlandı bildirimi.
///
/// 2026-09-29 Şahnê: altın dolgulu, kalın çerçeveli şerit içeriğin üstüne
/// biniyordu. Şimdi sakin bir bilgi: Kulis (`s2`) zemin, M pah, ince kenar
/// (gecede katman tonuyla ayrılır), solda Zêr şimşek glifi (XP), başlık
/// Açıklama 700 + ayrıntı Açıklama (ikincil metin). Sayfa kenarıyla hizalı
/// yüzer; alt boşluğu ve güvenli alanı Scaffold'un yüzen bildirim yerleşimi
/// verir, alt gezinmenin ve birincil düğmenin üstünde durur.
class MissionToast {
  static void show(BuildContext context, DailyMission mission) {
    if (!context.mounted) return;
    final isKu = context.isKu;
    final label = isKu ? mission.labelKu : mission.labelTr;
    final heading = Tr.forKu(K.gorevTamamlandi, isKu);
    final t = SahneTokens.of(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SahneGlyph(SahneGlyphKind.bolt, size: 24),
            const SizedBox(width: SahneSpace.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: SahneType.captionStrong.copyWith(color: t.tx),
                  ),
                  Text(
                    '$label — +${mission.xpReward} XP',
                    style: SahneType.caption.copyWith(color: t.tx2),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: t.s2,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: SahneShape.withSide(SahneShape.m, t.edge, width: 1),
        padding: const EdgeInsets.symmetric(
          horizontal: SahneSpace.x4,
          vertical: SahneSpace.x3,
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.fromLTRB(
          SahneSpace.page,
          0,
          SahneSpace.page,
          SahneSpace.x4,
        ),
      ),
    );
  }
}
