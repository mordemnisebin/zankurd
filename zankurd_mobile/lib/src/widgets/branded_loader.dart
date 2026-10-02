import 'package:flutter/material.dart';

import 'sahne/sahne.dart';

/// Tutarlı yükleme göstergesi.
///
/// 2026-09-29 Şahnê: halka Agir değil Zêr metni (`goldTx`) — Agir yalnız
/// birincil eylemin dolgusudur; ışık/ilerleme Zêr'in işidir. İz Ray (`s3`).
/// Gündüzde `goldTx` koyu altındır, açık zeminde okunur.
class BrandedLoader extends StatelessWidget {
  const BrandedLoader({
    super.key,
    this.size = 28,
    this.strokeWidth = 2.5,
    this.color,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? t.goldTx,
        backgroundColor: t.s3,
      ),
    );
  }
}

/// Tam ekran / merkez yerleşimli branded loader.
class BrandedLoaderCenter extends StatelessWidget {
  const BrandedLoaderCenter({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(child: BrandedLoader(size: size));
  }
}
