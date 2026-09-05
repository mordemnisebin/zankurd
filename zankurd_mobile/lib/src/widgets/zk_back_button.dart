import 'package:flutter/material.dart';

import '../l10n/lang.dart';
import '../l10n/strings.dart';

/// Material varsayılanı İngilizce «Back»; etiket dile bağlı olmalı.
///
/// `BackButton` tooltip parametresi bu SDK'da yok; `tester.pageBack()`
/// de «Back» arar. Testler [ZkBackButton] tipine dokunmalı.
class ZkBackButton extends StatelessWidget {
  const ZkBackButton({super.key, this.onPressed, this.color});

  final VoidCallback? onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const BackButtonIcon(),
      color: color,
      tooltip: context.t(K.back),
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}

/// Geri tuşu [K.back] tooltip'i taşıyan AppBar.
PreferredSizeWidget zkAppBar(
  BuildContext context, {
  Key? key,
  Widget? title,
  List<Widget>? actions,
  Color? backgroundColor,
  double? elevation,
  double? scrolledUnderElevation,
  bool automaticallyImplyLeading = true,
  Widget? leading,
  IconThemeData? iconTheme,
  bool? centerTitle,
}) {
  final showDefaultLeading = automaticallyImplyLeading && leading == null;
  return AppBar(
    key: key,
    title: title,
    actions: actions,
    backgroundColor: backgroundColor,
    elevation: elevation,
    scrolledUnderElevation: scrolledUnderElevation,
    iconTheme: iconTheme,
    centerTitle: centerTitle,
    automaticallyImplyLeading: showDefaultLeading,
    leading: leading ?? (showDefaultLeading ? const ZkBackButton() : null),
  );
}
