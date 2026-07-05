import 'package:flutter/material.dart';

import '../models/mastery_level.dart';
import '../theme/app_theme.dart';

/// Kazanılabilir avatar çerçeveleri. Kimlikler (name) profiles.avatar_frame
/// kolonunda saklanır; SABİT kalmalıdır.
enum AvatarFrame { bronze, silver, gold, mamoste }

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
};

/// Editörde kilitli çerçevenin yanında gösterilecek kazanım koşulu.
String frameRequirementLabel(AvatarFrame frame, bool isKu) => switch (frame) {
  AvatarFrame.bronze => isKu ? '1 nîşan veke' : '1 rozet aç',
  AvatarFrame.silver => isKu ? '5 nîşanan veke' : '5 rozet aç',
  AvatarFrame.gold =>
    isKu ? 'Di kategoriyekê de bibe Pispor' : 'Bir kategoride Pispor ol',
  AvatarFrame.mamoste =>
    isKu ? 'Di kategoriyekê de bibe Mamoste' : 'Bir kategoride Mamoste ol',
};
