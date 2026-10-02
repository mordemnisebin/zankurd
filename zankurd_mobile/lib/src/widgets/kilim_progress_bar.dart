import 'package:flutter/material.dart';

import '../utils/percent_format.dart';
import 'sahne/sahne.dart';

/// İlerleme çubuğu (eski adıyla kilim çubuğu).
///
/// 2026-09-29 Şahnê: görünüş [SahneProgressBar] — S pah, iz Ray (`s3`),
/// dolgu rolün rengi: öğrenmede `learnBar`, ödülde Zêr, yarışta Boyax.
/// Kilim deseni çubuktan kaldırıldı: Şahnê'de tek sahiplenilmiş motif
/// kilim göz şerididir ve yalnız sahne kartının üst kenarında ve sonuç
/// puanının altında durur (`spec_sahne.json` → `illustrationIconRule`).
///
/// [color] ham renk olarak boyanmaz, rolüne çevrilir ([sahneRoleFor]);
/// yalnız nötr bir renk (ör. koyu bir kahramanın üstünde beyaz) çağıranın
/// kendi zemin kararı sayılır ve korunur. [trackColor] ve [borderColor]
/// renkli zeminler için dışarıdan verilebilir.
class KilimProgressBar extends StatelessWidget {
  const KilimProgressBar({
    required this.value,
    this.height = 8,
    this.color,
    this.trackColor,
    this.borderColor,
    super.key,
  });

  final double value;
  final double height;

  /// Dolgunun rolü; verilmezse öğrenme.
  final Color? color;

  /// Boş kısmın rengi. Verilmezse Ray (`s3`).
  ///
  /// Renkli bir zeminin (ör. kategori hero'su) üstünde tema izi dolgudan
  /// ayırt edilemiyor ve %0 ilerleme "tamamen dolu" gibi okunuyordu
  /// (2026-07-25). Renkli zeminlerde çağıran taraf yarı saydam bir iz
  /// vermelidir.
  final Color? trackColor;

  /// İz kenarlığı. Verilmezse kenar yok.
  final Color? borderColor;

  Color _fill(SahneTokens t) {
    final c = color;
    if (c == null) return t.learnBar;
    return switch (sahneRoleFor(c)) {
      SahneRole.learn => t.learnBar,
      SahneRole.gold => t.gold,
      SahneRole.race => t.race,
      SahneRole.neutral => c,
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = SahneTokens.of(context);
    final progress = value.clamp(0.0, 1.0);
    final shape = height <= 28 ? SahneShape.s : SahneShape.m;
    final border = borderColor;

    return Semantics(
      value: context.percentRatio(progress),
      child: Container(
        key: const ValueKey('kilim-progress-track'),
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: trackColor ?? t.s3,
          shape: border == null
              ? shape
              : SahneShape.withSide(shape, border, width: 1),
        ),
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          key: const ValueKey('kilim-progress-fill'),
          widthFactor: progress,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: ShapeDecoration(color: _fill(t), shape: shape),
          ),
        ),
      ),
    );
  }
}
