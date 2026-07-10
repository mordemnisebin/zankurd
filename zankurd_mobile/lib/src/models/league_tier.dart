import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Haftalık lig kademeleri. v1 sunum katmanıdır: kademe, canlı haftalık
/// sıralamadaki yerden türetilir (küme düşme/çıkma mekaniği için sunucu
/// tarafı ayrı bir iş kalemidir).
enum LeagueTier {
  zer,
  ziv,
  bronz;

  /// Haftalık sıralamadan kademe: ilk 10 Zêr, 11-25 Zîv, gerisi Bronz.
  /// Sıralamada görünmeyen oyuncu (rank == null) Bronz'dan başlar.
  static LeagueTier forRank(int? rank) {
    if (rank == null || rank <= 0) return LeagueTier.bronz;
    if (rank <= 10) return LeagueTier.zer;
    if (rank <= 25) return LeagueTier.ziv;
    return LeagueTier.bronz;
  }

  String label(bool isKu) => switch (this) {
    LeagueTier.zer => isKu ? 'Lîga Zêr' : 'Altın Lig',
    LeagueTier.ziv => isKu ? 'Lîga Zîv' : 'Gümüş Lig',
    LeagueTier.bronz => isKu ? 'Lîga Bronz' : 'Bronz Lig',
  };

  Color get color => switch (this) {
    LeagueTier.zer => AppTheme.gold,
    LeagueTier.ziv => const Color(0xFFB8C4CE),
    LeagueTier.bronz => const Color(0xFFC77B4A),
  };

  IconData get icon => switch (this) {
    LeagueTier.zer => Icons.workspace_premium_rounded,
    LeagueTier.ziv => Icons.military_tech_rounded,
    LeagueTier.bronz => Icons.shield_moon_rounded,
  };
}
