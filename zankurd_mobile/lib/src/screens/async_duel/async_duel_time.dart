import 'package:flutter/material.dart';

import '../../l10n/lang.dart';
import '../../l10n/strings.dart';
import '../../models/async_duel.dart';
import '../../widgets/sahne/sahne.dart';

/// Kalan süreyi kısa metne çevirir: bir saat ve üstü "18 sa kaldı" (yarım
/// saatten yukarı yuvarlanır, taze 24 saat "24 sa" der), bir saatin altı
/// "35 dk kaldı" (en az 1). Süre kalmadıysa null.
///
/// Dil: [context.t] (KU/TR); sayı yer tutucusu `{n}`.
String? asyncDuelTimeLeftLabel(BuildContext context, Duration? left) {
  if (left == null || left <= Duration.zero) return null;
  if (left.inMinutes >= 60) {
    final hours = (left.inMinutes / 60).round();
    return context.t(K.asyncDuelTimeLeftHours, {'n': '$hours'});
  }
  final minutes = (left.inSeconds / 60).ceil().clamp(1, 59);
  return context.t(K.asyncDuelTimeLeftMinutes, {'n': '$minutes'});
}

/// Kalan süre oranı (0–1): [left] / [asyncDuelWindow]. Eski 48 saatlik
/// düellolar 1'e kırpılır.
double asyncDuelTimeFraction(Duration left) {
  final ratio = left.inSeconds / asyncDuelWindow.inSeconds;
  return ratio.clamp(0.0, 1.0);
}

/// Satırın/kartın alt parçası: "18 sa kaldı" (acele ise kırmızı) ve isteğe
/// bağlı ince kalan-süre çubuğu ("Sıra sende" satırlarında).
///
/// Metin DAİMA ayrı bir `Text`tir (alt satırla birleştirilmez): satır
/// metinleri ("Rakip bekleniyor") tek başına bulunabilir kalır. Süre
/// bilinmiyorsa ya da bittiyse hiçbir şey çizilmez.
class AsyncDuelTimeLeft extends StatelessWidget {
  const AsyncDuelTimeLeft({
    required this.left,
    this.showBar = false,
    this.closesOnExpiry = false,
    this.textKey,
    super.key,
  });

  final Duration? left;

  /// Kurul C30 (2026-10-29, 3/3): yarım kalan düelloda çubuğun neyi
  /// saydığı ve süre dolunca ne olduğu yazmıyordu. `true` iken çubuğun
  /// altında "Süre dolunca düello kapanır" yazar (sunucu süpürmesi düelloyu
  /// kapatır, bkz. [K.asyncDuelUnfinishedBody]).
  final bool closesOnExpiry;

  /// İnce (4 px) kalan-süre çubuğunu da çiz.
  final bool showBar;

  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final remaining = left;
    final label = asyncDuelTimeLeftLabel(context, remaining);
    if (remaining == null || label == null) return const SizedBox.shrink();
    final t = SahneTokens.of(context);
    final urgent = remaining <= asyncDuelUrgentWithin;
    final text = Text(
      label,
      key: textKey,
      style: SahneType.captionStrong.copyWith(
        color: urgent ? t.errTx : t.tx2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    if (!showBar && !closesOnExpiry) return text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        text,
        if (showBar) ...[
          const SizedBox(height: SahneSpace.x1),
          SahneProgressBar(
            key: const ValueKey('async-duel-time-bar'),
            value: asyncDuelTimeFraction(remaining),
            height: 4,
            fillColor: urgent ? t.errFill : t.raceFill,
            // Ekran okuyucu yüzdeyi değil, satırın etiketindeki süreyi okur.
            semanticLabel: label,
          ),
        ],
        if (closesOnExpiry) ...[
          const SizedBox(height: SahneSpace.x1),
          Text(
            context.t(K.asyncDuelClosesOnExpiry),
            key: const ValueKey('async-duel-closes-note'),
            style: SahneType.caption.copyWith(color: t.tx2),
          ),
        ],
      ],
    );
  }
}
