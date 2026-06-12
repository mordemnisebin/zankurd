import 'package:flutter/material.dart';

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
