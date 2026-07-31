import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/mastery_level.dart';
import '../theme/app_theme.dart';

/// Kazanılabilir avatar çerçeveleri. Kimlikler (name) profiles.avatar_frame
/// kolonunda saklanır; SABİT kalmalıdır.
///
/// [neon] diğerlerinden farklı: ilerlemeyle değil, mağazadan satın alarak
/// açılır ([unlockedFrames] onu hiç eklemez, `avatar_editor_screen`
/// `hasPurchased('avatar_frame_neon')` ile ekler). 2026-07-31'e kadar
/// mağaza kataloğunda tanımlıydı ama karşılığı yoktu — 600 coinlik
/// ürün hiçbir yerde görünmüyordu.
enum AvatarFrame { bronze, silver, gold, mamoste, neon }

AvatarFrame? frameFromId(String? id) {
  if (id == null) return null;
  for (final frame in AvatarFrame.values) {
    if (frame.name == id) return frame;
  }
  return null;
}

/// Oyuncunun mevcut ilerlemesine göre açılmış çerçeveler.
/// - bronze: en az 1 rozet
/// - silver: en az 5 rozet
/// - gold: herhangi bir kategoride Pispor eşiği
/// - mamoste: herhangi bir kategoride Mamoste eşiği
/// Eşikler MasteryLevel.threshold'dan okunur (100/400 kopyalanmaz).
Set<AvatarFrame> unlockedFrames({
  required int unlockedBadgeCount,
  required Map<String, int> masteryCorrectByCategory,
}) {
  final frames = <AvatarFrame>{};
  if (unlockedBadgeCount >= 1) frames.add(AvatarFrame.bronze);
  if (unlockedBadgeCount >= 5) frames.add(AvatarFrame.silver);
  final bestCorrect = masteryCorrectByCategory.values.fold<int>(
    0,
    (max, v) => v > max ? v : max,
  );
  if (bestCorrect >= MasteryLevel.pispor.threshold) {
    frames.add(AvatarFrame.gold);
  }
  if (bestCorrect >= MasteryLevel.mamoste.threshold) {
    frames.add(AvatarFrame.mamoste);
  }
  return frames;
}

Color frameColor(AvatarFrame frame) => switch (frame) {
  AvatarFrame.bronze => const Color(0xFFCD7F32),
  AvatarFrame.silver => const Color(0xFFB6BDC9),
  AvatarFrame.gold => AppTheme.gold,
  AvatarFrame.mamoste => AppTheme.violet,
  // Marka paletindeki teal'in doygun hâli: "neon" adını karşılıyor ama
  // uygulamanın renk ailesinden çıkmıyor.
  AvatarFrame.neon => const Color(0xFF2ED3B7),
};

/// Editörde kilitli çerçevenin yanında gösterilecek kazanım koşulu.
///
/// Metinler anahtar defterinde durur: satır içi olsalardı Kurmancî alfabe
/// bekçisinin ve `Tr.missingFor` bütünlük testinin dışında kalırlardı.
String frameRequirementLabel(AvatarFrame frame, bool isKu) => Tr.forKu(switch (
  frame
) {
  AvatarFrame.bronze => K.frameReqBronze,
  AvatarFrame.silver => K.frameReqSilver,
  AvatarFrame.gold => K.frameReqGold,
  AvatarFrame.mamoste => K.frameReqMamoste,
  AvatarFrame.neon => K.frameReqNeon,
}, isKu);
