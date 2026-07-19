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

/// Avatar arka plan renk paleti (hex, '#RRGGBB'). Marka ailesinden — jenerik
/// Tailwind tonları yerine kategori paletiyle aynı kimlik. DB'de saklanan
/// eski hex değerleri (varsa) yine [colorFrom] ile render edilmeye devam
/// eder; bu liste yalnızca yeni seçimde sunulan seçenekleri belirler.
const List<String> avatarColors = [
  '#E5533D', // nar kırmızısı
  '#E7B53C', // pirinç altını
  '#3DA968', // Kürdistan yeşili
  '#2E9E93', // teal
  '#6B3A7A', // erik moru
  '#C67A5C', // terracotta
  '#2B4F7E', // deniz mavisi
  '#D4789E', // gül pembesi
];

/// Harf avatarları için marka ailesinden türetilmiş 8 ton. Kullanıcı adı
/// hash'i bu palete eşlenir; böylece herkes aynı tek renge (ör. tek kırmızı)
/// düşmez. Tonlar beyaz harfle okunaklı kalacak doygunlukta seçildi —
/// çok açık pastel kullanılmadı (kontrast kuralı).
const List<Color> avatarNamePalette = [
  Color(0xFF3DA968), // Kürdistan yeşili
  Color(0xFF2E9E93), // teal
  Color(0xFF2B4F7E), // deniz mavisi
  Color(0xFF6B3A7A), // erik moru
  Color(0xFF722F43), // bordo
  Color(0xFFC67A5C), // terracotta
  Color(0xFFB8860B), // koyu amber
  Color(0xFFA84D6E), // gül kurusu
];

/// İsme bağlı deterministik avatar rengi üretir (basit, kararlı hash).
/// Aynı isim her oturumda aynı rengi alır; boş isimde ilk palet rengi döner.
Color avatarColorForName(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return avatarNamePalette.first;
  var hash = 0;
  for (final unit in trimmed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return avatarNamePalette[hash % avatarNamePalette.length];
}

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
