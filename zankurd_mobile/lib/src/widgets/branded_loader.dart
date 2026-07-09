import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marka rengi (coral primary) ile tutarlı yükleme göstergesi.
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
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color ?? AppTheme.primaryGradientStart,
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
