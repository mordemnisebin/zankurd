import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/achievement.dart';
import '../utils/percent_format.dart';
import 'sahne/sahne.dart';

/// `24.10.2026` (gün.ay.yıl; iki dilde aynı yazılır).
String formatRewardDate(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.'
    '${day.month.toString().padLeft(2, '0')}.${day.year}';

/// Kilitli bir başarı/rozetin ilerlemesi: Zêr çubuk + `63/100 soru`.
///
/// ## Kusur
///
/// Kilitli rozet yalnız kilit simgesiydi: 63'te olmak ile 3'te olmak aynı
/// görünüyordu (bkz. [RewardProgress]).
///
/// ## Kural
///
/// Sayı HER ZAMAN metin olarak da yazılır (çubuk tek başına renk/uzunluk
/// bilgisi olurdu); ekran okuyucu "63/100 soru" okur. Metin sarar, kesilmez:
/// Kurmancî birimler ve %200 yazı büyüklüğünde taşma olmaz.
class RewardProgressMeter extends StatelessWidget {
  const RewardProgressMeter({
    super.key,
    required this.progress,
    required this.isKu,
    this.compact = false,
    this.centered = false,
  });

  final RewardProgress progress;
  final bool isKu;

  /// Izgara hücresi gibi dar yerlerde daha ince çubuk.
  final bool compact;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final label = progress.label(isKu);
    return Semantics(
      label: label,
      value: PercentFormat.ratio(progress.fraction, isKu: isKu),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SahneProgressBar(
            key: const ValueKey('reward-progress-bar'),
            value: progress.fraction,
            tone: SahneProgressTone.gold,
            height: compact ? 6 : 8,
            semanticLabel: label,
          ),
          const SizedBox(height: SahneSpace.x1),
          Text(
            label,
            key: const ValueKey('reward-progress-label'),
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ],
      ),
    );
  }
}

/// Açılmış başarının altındaki `Kazanıldı: 24.10.2026` satırı. Tarih kaydı
/// olmayan (bu özellikten önce açılmış) rozette yalnız `Kazanıldı` yazar;
/// tarih uydurulmaz.
class RewardUnlockedLabel extends StatelessWidget {
  const RewardUnlockedLabel({
    super.key,
    required this.unlockedOn,
    required this.isKu,
    this.centered = false,
  });

  final DateTime? unlockedOn;
  final bool isKu;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final day = unlockedOn;
    final text = day == null
        ? Tr.forKu(K.kazanildi, isKu)
        : Tr.forKu(K.rewardUnlockedOn, isKu, {'date': formatRewardDate(day)});
    return Text(
      text,
      key: const ValueKey('reward-unlocked-label'),
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: SahneType.caption.copyWith(color: t.okTx),
    );
  }
}
