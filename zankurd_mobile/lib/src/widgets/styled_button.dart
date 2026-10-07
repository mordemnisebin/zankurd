import 'package:flutter/material.dart';

import 'sahne/sahne.dart';

/// Ekranın birincil eylemi.
///
/// 2026-09-29 Şahnê: görünüş [SahneButton.primary] — Agir dolgu, KOYU
/// metin (`onAct`), 52 boy, M pah, ekrandaki tek bulanık gölge. Eski düğme
/// Agir üstüne beyaz yazıyordu: 2,35:1 (erişilebilirlik kılavuzu testinde
/// "Başla", "Yarışı Başlat", "Davet Kodu Gir" bu yüzden kırmızıydı).
/// Pasif: Perde + üçüncül metin (opaklık değil). Yüklenirken Agir plaka
/// içinde koyu bir ilerleme halkası döner; düğme o sırada basılamaz.
class GeometricGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  const GeometricGradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final isEnabled = onPressed != null && !isLoading;

    final Widget body;
    if (isLoading) {
      body = SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: t.act, shape: SahneShape.m),
          child: Center(
            child: SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(t.onAct),
              ),
            ),
          ),
        ),
      );
    } else {
      body = SahneButton.primary(
        label: label,
        icon: icon,
        arrow: icon == null,
        expand: true,
        onPressed: isEnabled ? onPressed : null,
      );
    }

    return Semantics(
      button: true,
      label: label,
      enabled: isEnabled,
      excludeSemantics: true,
      onTap: isEnabled ? onPressed : null,
      child: body,
    );
  }
}
