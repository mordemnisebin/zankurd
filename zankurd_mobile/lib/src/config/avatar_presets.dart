import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
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

/// Sembol kimliği → anahtar defteri anahtarı (ekran okuyucu etiketi).
///
/// [avatarIcons] ile aynı sırada ve aynı anahtarlarla; biri değişirse
/// öteki de değişmeli (bekçi: avatar_accessibility_test.dart).
const Map<String, String> avatarIconLabelKeys = {
  'tembur': K.avatarIconTembur,
  'dengbej': K.avatarIconDengbej,
  'ciya': K.avatarIconCiya,
  'roj': K.avatarIconRoj,
  'pirtuk': K.avatarIconPirtuk,
  'newroz': K.avatarIconNewroz,
  'ster': K.avatarIconSter,
  'pen': K.avatarIconPen,
  'cihan': K.avatarIconCihan,
  'mertal': K.avatarIconMertal,
  'tac': K.avatarIconTac,
  'gul': K.avatarIconGul,
  'dar': K.avatarIconDar,
  'cav': K.avatarIconCav,
  'birusk': K.avatarIconBirusk,
  'kupa': K.avatarIconKupa,
};

/// Renk hex → anahtar defteri anahtarı (ekran okuyucu etiketi).
const Map<String, String> avatarColorLabelKeys = {
  '#E5533D': K.avatarColor0,
  '#E7B53C': K.avatarColor1,
  '#3DA968': K.avatarColor2,
  '#2E9E93': K.avatarColor3,
  '#6B3A7A': K.avatarColor4,
  '#C67A5C': K.avatarColor5,
  '#2B4F7E': K.avatarColor6,
  '#D4789E': K.avatarColor7,
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

/// 2026-07-23 M25b: aynı ekranda (leaderboard, oda/lobi listesi) render
/// edilen oyuncular arasında hash çakışmasını round-robin ile çözer.
///
/// Yalnızca `colorHex == null` olan (kullanıcının açıkça renk seçmediği,
/// hash fallback'ine düşen) girdiler için hesaplanır — kullanıcının
/// bilinçli seçtiği renge asla dokunulmaz. Dönüş değeri `id → Color`
/// eşlemesidir; `colorHex` dolu girdiler dönüş haritasında yer almaz
/// (çağıran taraf o girdiler için override kullanmamalı).
///
/// Palet boyutundan (12) fazla girdi varsa, döngü tükenince eşlenmemiş
/// girdiler kendi orijinal hash rengine geri döner — sonsuz döngüye
/// girmez, sadece o noktadan sonra çakışma olabilir (kabul edilebilir,
/// oda/leaderboard listeleri bu boyutu aşmıyor).
///
/// Aynı girdi listesi build başında bir kez çağrılıp cache'lenmeli;
/// `ListView.builder` gibi lazy render eden yerlerde her frame'de
/// yeniden çağrılırsa round-robin sonucu liste kaymasıyla değişip
/// renkler "titreyebilir".
Map<String, Color> resolveAvatarColors(
  Iterable<({String id, String? displayName, String? colorHex})> entries,
) {
  final result = <String, Color>{};
  final used = <Color>{};
  for (final entry in entries) {
    if (entry.colorHex != null) continue;
    final hashColor = avatarColorForName(entry.displayName);
    var color = hashColor;
    if (used.contains(color)) {
      final startIndex = avatarNamePalette.indexOf(hashColor);
      for (var step = 1; step <= avatarNamePalette.length; step++) {
        final candidate =
            avatarNamePalette[(startIndex + step) % avatarNamePalette.length];
        if (!used.contains(candidate)) {
          color = candidate;
          break;
        }
      }
      // Palet tamamen doluysa (girdi sayısı > palet boyu) orijinal hash
      // rengine geri dönülür; yeni kayıt eklenmesin diye 'color' zaten
      // hashColor'a eşit kalır.
    }
    used.add(color);
    result[entry.id] = color;
  }
  return result;
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
