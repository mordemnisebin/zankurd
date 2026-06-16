import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum MasteryLevel { none, xwendekar, pispor, mamoste }

extension MasteryLevelDetails on MasteryLevel {
  static MasteryLevel fromCorrectCount(int count) {
    if (count >= 400) return MasteryLevel.mamoste;
    if (count >= 100) return MasteryLevel.pispor;
    if (count >= 20) return MasteryLevel.xwendekar;
    return MasteryLevel.none;
  }

  int get threshold => switch (this) {
    MasteryLevel.none => 0,
    MasteryLevel.xwendekar => 20,
    MasteryLevel.pispor => 100,
    MasteryLevel.mamoste => 400,
  };

  String get titleKu => switch (this) {
    MasteryLevel.none => '',
    MasteryLevel.xwendekar => 'Xwendekar',
    MasteryLevel.pispor => 'Pispor',
    MasteryLevel.mamoste => 'Mamoste',
  };

  String get titleTr => switch (this) {
    MasteryLevel.none => '',
    MasteryLevel.xwendekar => 'Öğrenci',
    MasteryLevel.pispor => 'Uzman',
    MasteryLevel.mamoste => 'Usta',
  };

  Color get badgeColor => switch (this) {
    MasteryLevel.none => AppTheme.textMuted,
    MasteryLevel.xwendekar => Colors.blue,
    MasteryLevel.pispor => Colors.purple,
    MasteryLevel.mamoste => AppTheme.gold,
  };

  IconData get icon => switch (this) {
    MasteryLevel.none => Icons.circle_outlined,
    MasteryLevel.xwendekar => Icons.school_outlined,
    MasteryLevel.pispor => Icons.psychology_outlined,
    MasteryLevel.mamoste => Icons.workspace_premium_outlined,
  };
}
