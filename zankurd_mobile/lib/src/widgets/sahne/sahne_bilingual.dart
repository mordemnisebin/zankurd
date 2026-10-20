import 'package:flutter/material.dart';

import '../../theme/sahne.dart';

/// İki dilli etiketin KÜÇÜK satırı — öbür dilin aynı anahtarlı karşılığı.
///
/// 2026-10-20 kimlik kararı (temel "Tîp") ve kullanıcı geri bildirimi:
/// sade arayüzde bile oyuncu bir şeyi bulmakta zorlanıyordu. Yön bulduran
/// etiketlerde (alt sekmeler, ekran ve bölüm başlıkları, konu kartları)
/// seçili dil büyük, öbür dil bu bileşenle küçük ve ikincil renkte yazılır.
/// Her yerde AYNI biçim: açıklama (14/20, 400) + ikincil metin ([SahneTokens.tx2]);
/// gezinme çubuğunda [compact] (10/12, [SahneType.navHint]).
///
/// Metin çağırandan gelir ve YALNIZ `context.secondLabel(K.…)` ile okunur:
/// yeni metin yazılmaz, aynı anahtarın öbür dildeki değeri kullanılır.
///
/// Tek satırdır ve SARMAZ, KESİLMEZ: verilen genişliğe sığmıyorsa hiç
/// çizilmez (dar ekran, büyük yazı). Yarım kalmış bir söz yön bulduran bir
/// etiket olmaz; asıl etiket zaten yerinde durur. Ekran okuyucuya
/// duyurulmaz: asıl ad seçili dilde okunur, aynı yeri iki kez söylemez.
class SahneBilingualLabel extends StatelessWidget {
  const SahneBilingualLabel(
    this.text, {
    super.key,
    this.compact = false,
    this.textAlign = TextAlign.start,
  });

  final String text;

  /// Gezinme çubuğu boyutu (10/12).
  final bool compact;
  final TextAlign textAlign;

  /// Bu bileşenin anahtarı: bekçiler ve ekran turu bununla sayar.
  static const valueKey = ValueKey('sahne-bilingual-label');

  TextStyle styleFor(BuildContext context) {
    final t = SahneTokens.of(context);
    return (compact ? SahneType.navHint : SahneType.caption).copyWith(
      color: t.tx2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = styleFor(context);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: DefaultTextStyle.of(
                context,
              ).style.merge(style).copyWith(fontFamily: style.fontFamily),
            ),
            textDirection: Directionality.of(context),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final fits = painter.width <= constraints.maxWidth;
          painter.dispose();
          if (!fits) return const SizedBox.shrink();
        }
        return ExcludeSemantics(
          child: Text(
            text,
            key: valueKey,
            maxLines: 1,
            softWrap: false,
            textAlign: textAlign,
            overflow: TextOverflow.clip,
            style: style,
          ),
        );
      },
    );
  }
}
