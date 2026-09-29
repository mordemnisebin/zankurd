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
/// (`androidTapTargetGuideline`) 48'in altını reddeder. Stat çipindeki
/// gibi plaka 48'lik saydam bir dokunma kutusunun ortasında durur; ekran
/// okuyucu tek bir 48'lik düğme görür.
class ZkBackButton extends StatelessWidget {
  const ZkBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  /// Dokunma kutusunun kenarı.
  static const double tapTarget = 48;

  @override
  Widget build(BuildContext context) {
    final label = context.t(K.back);
    final onTap = onPressed ?? () => Navigator.maybePop(context);
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: tapTarget,
          child: Center(
            child: SahneIconButton(
              icon: AppIcons.arrowLeft,
              semanticLabel: label,
              onPressed: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

/// Varsayılan geri düğmesinin dokunma kutusunun sayfa kenarından boşluğu:
/// plakanın (44) görsel kenarı 16'ya oturur.
const double _backInset = SahneSpace.page - (ZkBackButton.tapTarget - 44) / 2;

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
  final Widget? heading = title == null
      ? null
      : Semantics(
          header: true,
          child: subtitle == null
              ? title
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    DefaultTextStyle.merge(
                      style: SahneType.caption.copyWith(color: t.tx2),
                      child: subtitle,
                    ),
                  ],
                ),
        );
  return AppBar(
    key: key,
    toolbarHeight: 64,
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
