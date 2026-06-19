import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';

/// Tam genişlikte yükleniyor kartları için shimmer liste.
class SkeletonLoader extends StatelessWidget {
  const SkeletonLoader({
    this.count = 3,
    this.height = 80,
    this.borderRadius = 12,
    super.key,
  });

  final int count;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.surfaceHi : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A50) : const Color(0xFFF5F5F5);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Shimmer.fromColors(
          baseColor: baseColor,
          highlightColor: highlightColor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tek satır metin için shimmer placeholder.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
    super.key,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor =
        isDark ? AppTheme.surfaceHi : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A50) : const Color(0xFFF5F5F5);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
