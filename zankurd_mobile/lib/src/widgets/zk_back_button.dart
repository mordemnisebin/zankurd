import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';
import '../theme/app_icons.dart';
import 'sahne/sahne.dart';

/// Material varsayılanı İngilizce «Back»; etiket dile bağlı olmalı.
///
/// `BackButton` tooltip parametresi bu SDK'da yok; `tester.pageBack()`
/// de «Back» arar. Testler [ZkBackButton] tipine dokunmalı.
///
/// 2026-09-29 Şahnê: B iskeletinin geri düğmesi — 44'lük M pahlı Perde
/// plaka ([SahneIconButton]). Plaka kendi zeminini taşıdığı için renkli
/// bir kahramanın üstünde de okunur; [color] geriye uyum için kalır ve
/// yok sayılır (ikon rengi belirteçten gelir).
///
/// Görsel 44, dokunma alanı 48: erişilebilirlik kılavuzu testi
/// (`androidTapTargetGuideline`) 48'in altını reddeder. 48'lik kutuyu
/// artık bileşenin kendisi verir ([SahneIconButton]); ekran okuyucu tek bir
/// 48'lik düğme görür.
class ZkBackButton extends StatelessWidget {
  const ZkBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  /// Dokunma kutusunun kenarı.
  static const double tapTarget = sahneTapTarget;

  @override
  Widget build(BuildContext context) {
    return SahneIconButton(
      icon: AppIcons.arrowLeft,
      semanticLabel: context.t(K.back),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}

/// Varsayılan geri düğmesinin dokunma kutusunun sayfa kenarından boşluğu:
/// plakanın (44) görsel kenarı 16'ya oturur.
const double _backInset = SahneSpace.page - SahneIconButton.inset;

/// Geri tuşu [K.back] tooltip'i taşıyan AppBar.
///
/// 2026-09-29 Şahnê: B iskeletinin çubuğu — en az 64 yükseklik, solda
/// sayfa kenarından 16 içeride 44'lük geri plakası, 12 boşluk, Manşet 22
/// başlık ve isteğe bağlı Açıklama alt satırı ([subtitle]). Zemin sayfa
/// zeminidir (`bg`); çağıran bir renk verirse o korunur.
PreferredSizeWidget zkAppBar(
  BuildContext context, {
  Key? key,
  Widget? title,
  Widget? subtitle,
  List<Widget>? actions,
  Color? backgroundColor,
  double? elevation,
  double? scrolledUnderElevation,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  IconThemeData? iconTheme,
  bool? centerTitle,
  SystemUiOverlayStyle? systemOverlayStyle,
}) {
  final t = SahneTokens.of(context);
  final showDefaultLeading = automaticallyImplyLeading && leading == null;
  final hasLeading = leading != null || showDefaultLeading;
  // Başlık metinse sözleri bölünmeden sarar ([SahneUnbrokenText]) ve çubuk
  // büyük yazıda başlığın gerçek yüksekliği kadar uzar (eskiden sabit 64'tü:
  // %200'de başlık ve alt satır kesiliyordu).
  final titleText = title is Text && title.data != null ? title : null;
  final Widget? shownTitle = titleText == null
      ? title
      : SahneUnbrokenText(
          titleText.data!,
          style: SahneType.headline.copyWith(color: t.tx),
        );
  final toolbarHeight = _barHeight(
    context,
    title: titleText?.data,
    subtitle: subtitle is Text ? subtitle.data : null,
    hasSubtitle: subtitle != null,
    hasLeading: hasLeading,
    actionCount: actions?.length ?? 0,
  );
  final Widget? heading = shownTitle == null
      ? null
      : Semantics(
          header: true,
          child: subtitle == null
              ? shownTitle
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    shownTitle,
                    DefaultTextStyle.merge(
                      style: SahneType.caption.copyWith(color: t.tx2),
                      child: subtitle,
                    ),
                  ],
                ),
        );
  return AppBar(
    key: key,
    toolbarHeight: toolbarHeight,
    title: heading,
    titleSpacing: hasLeading ? SahneSpace.x3 : SahneSpace.page,
    titleTextStyle: SahneType.headline.copyWith(color: t.tx),
    actions: actions == null
        ? null
        : [...actions, const SizedBox(width: SahneSpace.x2)],
    backgroundColor: backgroundColor ?? t.bg,
    surfaceTintColor: Colors.transparent,
    elevation: elevation ?? 0,
    scrolledUnderElevation: scrolledUnderElevation ?? 0,
    iconTheme: iconTheme ?? IconThemeData(color: t.tx),
    centerTitle: centerTitle ?? false,
    systemOverlayStyle: systemOverlayStyle,
    automaticallyImplyLeading: showDefaultLeading,
    // Çağıranın kendi öncülü (ör. 48'lik kapat düğmesi) olduğu gibi kalır;
    // yalnız varsayılan geri plakası sayfa kenarına hizalanır.
    // Plakanın görsel kenarı sayfa kenarına (16) oturur; 48'lik dokunma
    // kutusu 2 px dışarı taşar.
    leadingWidth: leading == null && showDefaultLeading
        ? _backInset + ZkBackButton.tapTarget
        : null,
    leading:
        leading ??
        (showDefaultLeading
            ? const Padding(
                padding: EdgeInsetsDirectional.only(start: _backInset),
                child: Center(child: ZkBackButton()),
              )
            : null),
  );
}

/// B çubuğunun yüksekliği: en az 64; büyük yazıda başlığın (ve alt
/// satırın) ölçülen yüksekliği + 16. Başlık metin değilse tek satır sayılır.
double _barHeight(
  BuildContext context, {
  required String? title,
  required String? subtitle,
  required bool hasSubtitle,
  required bool hasLeading,
  required int actionCount,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  final width = MediaQuery.sizeOf(context).width;
  final lead = hasLeading ? _backInset + ZkBackButton.tapTarget : 0.0;
  final room = math.max(
    48.0,
    width -
        lead -
        (hasLeading ? SahneSpace.x3 : SahneSpace.page) -
        actionCount * sahneTapTarget -
        SahneSpace.page,
  );
  double measure(String? text, TextStyle style) {
    if (text == null) return scaler.scale(style.fontSize!) * style.height!;
    final merged = DefaultTextStyle.of(context).style.merge(style);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: merged.copyWith(fontFamily: merged.fontFamily ?? SahneType.text),
      ),
      textDirection: direction,
      textScaler: sahneUnbrokenScaler(context, text, style, room, scaler),
    )..layout(maxWidth: room);
    final h = painter.height;
    painter.dispose();
    return h;
  }

  var h = measure(title, SahneType.headline);
  if (hasSubtitle) h += measure(subtitle, SahneType.caption);
  return math.max(64, h + SahneSpace.x4);
}
