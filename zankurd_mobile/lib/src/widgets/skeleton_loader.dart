import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../providers/reduced_motion_provider.dart';
import 'sahne/sahne.dart';

/// 2026-09-29 Şahnê: iskelet Kulis (`s2`) zeminde Ray (`s3`) parıltısıyla
/// çizilir; şekil pahlıdır — kart iskeleti L, satır iskeleti S (≤ 28) ya
/// da M. Eski `borderRadius` parametreleri geriye uyum için kalır ve pah
/// boyunu seçer: 12 ve üstü L, 8 ve üstü M, altı S.
({Color base, Color highlight}) _shimmerColors(BuildContext context) {
  final t = SahneTokens.of(context);
  return (base: t.s2, highlight: t.s3);
}

BeveledRectangleBorder _shapeFor(double radius) => radius >= SahneShape.lValue
    ? SahneShape.l
    : radius >= SahneShape.mValue
    ? SahneShape.m
    : SahneShape.s;

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
    final reduceMotion = context.watch<ReducedMotionProvider>().reduceMotion;
    final colors = _shimmerColors(context);
    final shape = _shapeFor(borderRadius);

    Widget block(Color color) => SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: color, shape: shape),
      ),
    );

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: SahneSpace.cardGap),
        child: reduceMotion
            ? block(colors.base)
            : Shimmer.fromColors(
                baseColor: colors.base,
                highlightColor: colors.highlight,
                child: block(colors.base),
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
    final reduceMotion = context.watch<ReducedMotionProvider>().reduceMotion;
    final colors = _shimmerColors(context);
    // Metin satırı ≤ 28 yüksekliktedir: S pah (M pah ince satırı elmasa
    // çevirir).
    final shape = height <= 28 ? SahneShape.s : _shapeFor(borderRadius);

    Widget block(Color color) => SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: color, shape: shape),
      ),
    );

    return reduceMotion
        ? block(colors.base)
        : Shimmer.fromColors(
            baseColor: colors.base,
            highlightColor: colors.highlight,
            child: block(colors.base),
          );
  }
}
