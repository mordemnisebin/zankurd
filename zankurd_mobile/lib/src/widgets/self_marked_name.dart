import 'package:flutter/material.dart';

import 'sahne/sahne.dart';

/// Ad + kendi işareti ("(Sen)"): işaret hiçbir zaman kesilmez.
///
/// Kurul 3 D5 / Astra 2. inceleme: 3:1 esnek düzende işaret genişliğin en çok
/// dörtte birini alıyor, dar ekranda ya da büyük yazıda "(Se" diye
/// kırpılıyordu. İşaret ölçülür ve tam genişliğini alır; ad kalan alanda
/// esner. Yan yana en az [minNameWidth] ad alanı kalmıyorsa işaret adın
/// ALTINA iner (tam metin, tek satır).
class SelfMarkedName extends StatelessWidget {
  const SelfMarkedName({
    super.key,
    required this.name,
    required this.mark,
    required this.markStyle,
    this.markKey,
    this.end = false,
    this.minNameWidth = 48,
  });

  final Widget name;
  final String? mark;
  final TextStyle markStyle;
  final Key? markKey;
  final bool end;
  final double minNameWidth;

  @override
  Widget build(BuildContext context) {
    final text = mark;
    if (text == null) {
      return Align(
        alignment: end
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: name,
      );
    }
    final scaler = MediaQuery.textScalerOf(context);
    final dts = DefaultTextStyle.of(context).style.merge(markStyle);
    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: dts.copyWith(fontFamily: dts.fontFamily),
          ),
          textDirection: Directionality.of(context),
          textScaler: scaler,
          maxLines: 1,
        )..layout();
        final markWidth = painter.width.ceilToDouble() + 1;
        painter.dispose();
        final markText = Text(
          text,
          key: markKey,
          maxLines: 1,
          softWrap: false,
          style: markStyle,
        );
        const gap = SahneSpace.x1;
        final sideBySide =
            !c.maxWidth.isFinite ||
            c.maxWidth - markWidth - gap >= minNameWidth;
        if (sideBySide) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: end
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Flexible(child: name),
              const SizedBox(width: gap),
              SizedBox(width: markWidth, child: markText),
            ],
          );
        }
        return Column(
          crossAxisAlignment: end
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            name,
            FittedBox(fit: BoxFit.scaleDown, child: markText),
          ],
        );
      },
    );
  }
}
