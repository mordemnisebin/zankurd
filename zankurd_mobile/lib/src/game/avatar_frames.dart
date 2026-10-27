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
enum AvatarFrame { bronze, silver, gold, mamoste, neon, kilim, newroz, sev }

/// Mağazadan satın alınarak açılan çerçeveler (2026-10-27: kilim, newroz,
/// şev eklendi). Sunucu `protect_paid_profile_cosmetics` bunları yalnız
/// satın alana uygulatır; mağaza ürün kimliği `avatar_frame_<name>`.
const Set<AvatarFrame> shopFrames = {
  AvatarFrame.neon,
  AvatarFrame.kilim,
  AvatarFrame.newroz,
  AvatarFrame.sev,
};

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
  // 2026-09-30 simülatör: `AppTheme.violet` Şahnê'de altına bağlandığından
  // Mamoste çerçevesi Altın'la aynı sarıydı; en yüksek ustalık ayırt
  // edilemiyordu. Zimrût (öğrenme rengi): ustalık bir öğrenme başarısıdır.
  AvatarFrame.mamoste => const Color(0xFF1DB482),
  // Marka paletindeki teal'in doygun hâli: "neon" adını karşılıyor ama
  // uygulamanın renk ailesinden çıkmıyor.
  AvatarFrame.neon => const Color(0xFF2ED3B7),
  // Kilim: madder kırmızısı (yarış rengi) ile altın — dokuma halısının iki
  // temel rengi. Newroz: ateşin turuncusu. Şev: gece mavisi.
  AvatarFrame.kilim => const Color(0xFFB5333C),
  AvatarFrame.newroz => const Color(0xFFF28C28),
  AvatarFrame.sev => const Color(0xFF3D4BB5),
};

/// Mağaza çerçeveleri (altın, neon) tek renk 3 px kenarla kazanılan
/// bronz/gümüşten ayırt edilmiyordu; arkadaşın satın aldığı çerçeve
/// başkalarının gözünde "değişmedi" (2026-10-25). Bunlar çift kontur
/// çizer: gradyanlı dış halka, koyu ayırıcı, ince iç tel. Blur yok.
bool isPremiumFrame(AvatarFrame frame) =>
    frame == AvatarFrame.gold || shopFrames.contains(frame);

const Color premiumFrameSeparator = Color(0xFF142326);

LinearGradient premiumFrameGradient(AvatarFrame frame) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: switch (frame) {
    AvatarFrame.neon => const [
      Color(0xFFA4FFEF),
      Color(0xFF2ED3B7),
      Color(0xFF098F86),
    ],
    // Kilim: kırmızı–altın–kırmızı; halı bordürü gibi iki renk dönüşümlü.
    AvatarFrame.kilim => const [
      Color(0xFFE2524A),
      Color(0xFFE6AD32),
      Color(0xFF8E1F2C),
    ],
    AvatarFrame.newroz => const [
      Color(0xFFFFE08A),
      Color(0xFFF28C28),
      Color(0xFFC0391B),
    ],
    AvatarFrame.sev => const [
      Color(0xFFB9C4FF),
      Color(0xFF3D4BB5),
      Color(0xFF1B1F5E),
    ],
    _ => const [Color(0xFFFFF1B8), Color(0xFFE6AD32), Color(0xFFA86B12)],
  },
);

Color premiumFrameInner(AvatarFrame frame) => switch (frame) {
  AvatarFrame.neon => const Color(0xFFB8FFF4),
  AvatarFrame.kilim => const Color(0xFFFFD27A),
  AvatarFrame.newroz => const Color(0xFFFFE9B0),
  AvatarFrame.sev => const Color(0xFFE6EBFF),
  _ => const Color(0xFFFFE29A),
};

/// Dış halka kalınlığı: küçük avatarda (çap < 32) 3, üstünde 4. Ayırıcı ve
/// iç tel 1'er piksel. 2'de kazanılan bronzun 3 px dolu halkası satın
/// alınan çerçeveden baskın görünüyordu (önizleme, 2026-10-25).
double premiumFrameOuterWidth(double size) => size < 32 ? 3 : 4;

/// Vitrin unvanı VIP mi? Sunucu `VIP` unvanını yalnız satın alana yazdırır
/// (2026-07-29_release_readiness_hardening.sql).
bool isVipTitle(String? title) => title?.trim() == 'VIP';

/// Editörde kilitli çerçevenin yanında gösterilecek kazanım koşulu.
///
/// Metinler anahtar defterinde durur: satır içi olsalardı Kurmancî alfabe
/// bekçisinin ve `Tr.missingFor` bütünlük testinin dışında kalırlardı.
String frameRequirementLabel(AvatarFrame frame, bool isKu) =>
    Tr.forKu(switch (frame) {
      AvatarFrame.bronze => K.frameReqBronze,
      AvatarFrame.silver => K.frameReqSilver,
      AvatarFrame.gold => K.frameReqGold,
      AvatarFrame.mamoste => K.frameReqMamoste,
      AvatarFrame.neon ||
      AvatarFrame.kilim ||
      AvatarFrame.newroz ||
      AvatarFrame.sev => K.frameReqNeon,
    }, isKu);
