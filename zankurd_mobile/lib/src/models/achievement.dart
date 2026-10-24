import 'package:flutter/material.dart';

import '../l10n/strings.dart';

class Achievement {
  const Achievement({
    required this.id,
    required this.titleKu,
    required this.titleTr,
    required this.descriptionKu,
    required this.descriptionTr,
    required this.icon,
  });

  final String id;
  final String titleKu;
  final String titleTr;
  final String descriptionKu;
  final String descriptionTr;
  final IconData icon;

  String title(bool isKu) => isKu ? titleKu : titleTr;
  String description(bool isKu) => isKu ? descriptionKu : descriptionTr;
}

/// Bir ilerleme sayacının birimi (`63/100 soru`).
enum RewardUnit { none, question, day, topic, round }

/// Kilitli bir başarı/rozetin açılmasına ne kadar kaldığı: `current/target`.
///
/// ## Kusur
///
/// Kilitli rozet yalnız bir kilit simgesiydi; "100 soru" rozetine 63'te
/// olmak ile 3'te olmak aynı görünüyordu. Oyuncu hedefe ne kadar kaldığını
/// göremeyince rozet bir hedef olmaktan çıkıp süs kalıyordu.
///
/// ## Kural
///
/// Bu yalnız GÖSTERİMDİR: açılma kuralları `AchievementStore` /
/// `BadgeService` içinde değişmedi. [current] hedefi geçmez (açılmış bir
/// rozet `target/target` olur), negatif olmaz.
@immutable
class RewardProgress {
  const RewardProgress({
    required int current,
    required this.target,
    this.unit = RewardUnit.none,
  }) : current = current < 0 ? 0 : (current > target ? target : current);

  final int current;
  final int target;
  final RewardUnit unit;

  bool get isComplete => current >= target;

  /// 0–1 arası doluluk.
  double get fraction => target <= 0 ? 0 : current / target;

  /// `63/100` ya da birimli `63/100 soru`.
  String label(bool isKu) {
    final base = '$current/$target';
    final key = switch (unit) {
      RewardUnit.none => null,
      RewardUnit.question => K.rewardUnitQuestion,
      RewardUnit.day => K.rewardUnitDay,
      RewardUnit.topic => K.rewardUnitTopic,
      RewardUnit.round => K.rewardUnitRound,
    };
    return key == null ? base : '$base ${Tr.forKu(key, isKu)}';
  }

  @override
  bool operator ==(Object other) =>
      other is RewardProgress &&
      other.current == current &&
      other.target == target &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(current, target, unit);
}
