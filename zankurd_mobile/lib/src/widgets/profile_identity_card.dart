import 'package:flutter/material.dart';

/// Profil kimlik kartının renkleri ve yüzeyi (vay katmanı 2B, B7 —
/// 2026-10-29).
///
/// Kart iki temada AYNI gece-mavi degradedir (#173C52 → #285C70) ve
/// üstündeki metin beyazdır (açık uçta bile ≥ 4.5:1; bekçi:
/// `test/vay_2b_test.dart`). Renkler ekran dosyasında ham `Color(0x…)`
/// olarak durmaz (`sahne_design_guard_test.dart`): kimlik kartının kendi
/// belirteçleri buradadır.
class ProfileIdentityColors {
  const ProfileIdentityColors._();

  static const Color cardTop = Color(0xFF173C52);
  static const Color cardBottom = Color(0xFF285C70);

  /// Kart üstünde ikincil metin (soluk beyaz).
  static const Color onCard2 = Color(0xD1FFFFFF);

  /// Seri (ateş) simgesi.
  static const Color streak = Color(0xFFFFB25C);

  /// Seviye yıldızı ve vitrin unvanı.
  static const Color gold = Color(0xFFFFD873);
}

/// Kimlik kartının yüzeyi: degrade + yumuşak gölge, L köşe.
class ProfileIdentitySurface extends StatelessWidget {
  const ProfileIdentitySurface({required this.child, super.key});

  final Widget child;

  static const ShapeDecoration decoration = ShapeDecoration(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
    ),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [ProfileIdentityColors.cardTop, ProfileIdentityColors.cardBottom],
    ),
    shadows: [
      BoxShadow(color: Color(0x33173C52), offset: Offset(0, 8), blurRadius: 14),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      DecoratedBox(decoration: decoration, child: child);
}
