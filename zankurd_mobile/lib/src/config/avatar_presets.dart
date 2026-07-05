import 'package:flutter/material.dart';

/// Hazır avatar seti: kültürel temalı 16 Material ikonu. Yeni asset
/// eklemeden (paket boyutu korunarak) görsel çeşitlilik sağlar; kimlikler
/// profiles.avatar_icon kolonunda saklanır, bu yüzden SABİT kalmalıdır.
const Map<String, IconData> avatarIcons = {
  'tembur': Icons.music_note_rounded,
  'dengbej': Icons.mic_rounded,
  'ciya': Icons.landscape_rounded,
  'roj': Icons.wb_sunny_rounded,
  'pirtuk': Icons.menu_book_rounded,
  'newroz': Icons.local_fire_department_rounded,
  'ster': Icons.star_rounded,
  'pen': Icons.edit_rounded,
  'cihan': Icons.public_rounded,
  'mertal': Icons.shield_rounded,
  'tac': Icons.workspace_premium_rounded,
  'gul': Icons.local_florist_rounded,
  'dar': Icons.park_rounded,
  'cav': Icons.visibility_rounded,
  'birusk': Icons.bolt_rounded,
  'kupa': Icons.emoji_events_rounded,
};

/// Avatar arka plan renk paleti (hex, '#RRGGBB').
const List<String> avatarColors = [
  '#E94560',
  '#7C3AED',
  '#2563EB',
  '#10B981',
  '#F59E0B',
  '#EC4899',
  '#0EA5E9',
  '#F97316',
];

IconData? iconFor(String? id) => id == null ? null : avatarIcons[id];

/// '#RRGGBB' hex'ini çözer; bozuk/boş girdide [fallback] döner.
Color colorFrom(String? hex, {required Color fallback}) {
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
