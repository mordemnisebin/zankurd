import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Hazır avatar seti: kültürel temalı 16 Material ikonu. Yeni asset
/// eklemeden (paket boyutu korunarak) görsel çeşitlilik sağlar; kimlikler
/// profiles.avatar_icon kolonunda saklanır, bu yüzden SABİT kalmalıdır.
const Map<String, IconData> avatarIcons = {
  'tembur': AppIcons.music,
  'dengbej': AppIcons.microphone,
  'ciya': AppIcons.mountain,
  'roj': AppIcons.sun,
  'pirtuk': AppIcons.bookOpen,
  'newroz': AppIcons.fire,
  'ster': AppIcons.star,
  'pen': AppIcons.pen,
  'cihan': AppIcons.globe,
  'mertal': AppIcons.shield,
  'tac': AppIcons.medal,
  'gul': AppIcons.seedling,
  'dar': AppIcons.tree,
  'cav': AppIcons.eye,
  'birusk': AppIcons.bolt,
  'kupa': AppIcons.trophy,
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

/// Harf avatarları için marka ailesinden türetilmiş 12 ton. Kullanıcı adı
/// hash'i bu palete eşlenir; böylece herkes aynı tek renge (ör. tek kırmızı)
/// düşmez. Tonlar beyaz harfle okunaklı kalacak doygunlukta seçildi —
/// çok açık pastel kullanılmadı (kontrast kuralı).
///
/// 2026-07-23 M25: 8'den 12'ye genişletildi — küçük havuzda hash çakışması
/// (leaderboard'da aynı anda birden fazla oyuncunun aynı rengi alması)
/// sık görülüyordu. Son 4 ton ([resolveAvatarColors] ile round-robin
/// çakışma çözümü de ekleniyor, bkz. aşağı) daha geniş bir marka ailesini
/// kapsıyor (koyu marka turuncusu dahil — ham `#F5931E` beyaz metinle
/// ~2.2:1 verdiği için değil, `#C05000` gibi koyulaştırılmış hâli kullanıldı).
const List<Color> avatarNamePalette = [
  Color(0xFF3DA968), // Kürdistan yeşili
  Color(0xFF2E9E93), // teal
  Color(0xFF2B4F7E), // deniz mavisi
  Color(0xFF6B3A7A), // erik moru
  Color(0xFF722F43), // bordo
  Color(0xFFC67A5C), // terracotta
  Color(0xFFB8860B), // koyu amber
  Color(0xFFA84D6E), // gül kurusu
  Color(0xFFC05000), // koyu marka turuncusu
  Color(0xFF4B6F44), // zeytin yeşili
  Color(0xFF3F4E73), // çelik indigo
  Color(0xFF8B5E3C), // bakır kahve
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
