import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Kategori bazlı görsel kaynak (ikon + arka plan görseli + renk) için tek
/// doğruluk kaynağı.
///
/// Renkler daha önce `AppTheme.categoryGradient(index)` ile **sıraya** göre
/// veriliyordu: kategori listesi `widget.index`, alt kategori/quiz ekranları
/// ise `repository.categories.indexOf(...)` kullanıyordu. İki sıralama
/// örtüşmediği için aynı kategori ekrandan ekrana renk değiştiriyordu —
/// Muzîk listede hardal, detayda bordo; Dîrok listede bordo, düelloda
/// lacivert (2026-07-22 canlı UX denetimi). Artık renk kategorinin *adına*
/// bağlıdır ve her yüzeyde aynıdır.
class CategoryVisuals {
  const CategoryVisuals._();

  /// Türkçe çeviri veya alternatif gösterim etiketlerini ana kategori kimliğine eşler.
  static const Map<String, String> _aliases = {
    'Dil': 'Ziman',
    'Kültür': 'Çand',
    'Tarih': 'Dîrok',
    'Wêje': 'Edebiyat',
    'Coğrafya': 'Cografya',
    'Erdnîgarî': 'Cografya',
    'Müzik': 'Muzîk',
    'Paradîgma': 'Paradigma',
    'Teknoloji': 'Teknolojî',
    'Sinema': 'Sînema',
    'Film': 'Sînema',
  };

  static String _resolveKey(String category) {
    if (_gradients.containsKey(category)) return category;
    return _aliases[category] ?? category;
  }

  /// Kategori adını canonical (ana) kategori kimliğine eşler.
  static String canonicalName(String category) => _resolveKey(category);

  /// Kategori → renk çifti. **Rengîn Editorial Arena** (2026-08-03).
  ///
  /// Önceki set bilerek düşük kromaya çekilmişti ve kartın yalnız küçük bir
  /// köşesini boyuyordu. Sonuç, gerçek cihazda pastel bir yıkamaydı: on
  /// kategori yan yana durduğunda hiçbiri kimlik taşımıyor, ekran renkli
  /// değil soluk görünüyordu. Renk artık kartın TAMAMINI dolduruyor, bu
  /// yüzden doygunluk geri getirildi.
  ///
  /// Altı ana hue ailesi (zümrüt, ametist, madder, safir, safran, turkuaz)
  /// ve bunların ton varyantları kullanılır — on bağımsız rastgele renk
  /// değil. Her ton beyaz metinle WCAG AA'yı KENDİ BAŞINA geçer (ölçülen
  /// aralık 5.00:1 – 8.08:1), çünkü kategori adı artık dolu renk zeminin
  /// üstünde duruyor ve okunurluk rengin kendisine bağlı.
  ///
  /// İkinci ton yalnız derinlik içindir; gradyanın koyu ucu olarak birinci
  /// tonun ~%18 karartılmışıdır, ayrı bir hue değildir.
  static const Map<String, List<Color>> _gradients = {
    // ── Zümrüt ailesi ──
    'Ziman': [Color(0xFF0E7A57), Color(0xFF0A5C41)],
    'Muzîk': [Color(0xFF4C7A17), Color(0xFF3A5D11)],
    // ── Ametist ailesi ──
    'Çand': [Color(0xFF6A38BE), Color(0xFF522B92)],
    'Sînema': [Color(0xFF8B2A60), Color(0xFF6B204A)],
    // ── Madder ailesi ──
    'Dîrok': [Color(0xFFB31E3B), Color(0xFF8B172E)],
    'Siyaset': [Color(0xFFBC4318), Color(0xFF933412)],
    // ── Safir ailesi ──
    'Edebiyat': [Color(0xFF1E4FA6), Color(0xFF173D80)],
    'Paradigma': [Color(0xFF2A5A8C), Color(0xFF20456C)],
    // ── Safran / turkuaz ──
    'Cografya': [Color(0xFF9C6300), Color(0xFF784C00)],
    'Teknolojî': [Color(0xFF04697C), Color(0xFF03505F)],
  };

  static const List<Color> _fallbackGradient = [
    Color(0xFF0E7A57),
    Color(0xFF0A5C41),
  ];

  /// Rengi açıkça tanımlanmış kategoriler. Yeni bir kategori eklenirse
  /// burada da tanımlanmalı; aksi halde fallback renge düşer.
  static Iterable<String> get colorDefinedCategories => _gradients.keys;

  /// Kategorinin gradyan renk çifti (adına göre, sıradan bağımsız).
  static List<Color> gradientColors(String category) {
    final key = _resolveKey(category);
    return _gradients[key] ?? _fallbackGradient;
  }

  /// Kategorinin baskın rengi — ikon tonu, kenarlık ve vurgu için.
  static Color color(String category) => gradientColors(category).first;

  /// Kategorinin gradyanı; kart ve panel zeminlerinde kullanılır.
  static LinearGradient gradient(String category) => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: gradientColors(category),
  );

  static const Map<String, IconData> _icons = {
    'Ziman': AppIcons.language,
    'Çand': AppIcons.peopleGroup,
    'Dîrok': AppIcons.buildingColumns,
    'Edebiyat': AppIcons.bookOpen,
    'Cografya': AppIcons.globe,
    'Muzîk': AppIcons.music,
    // Onay kutusu siyasetle ilgisiz bir metafordu (2026-07-22 UX denetimi);
    // terazi hem siyaset hem hukuk/yönetişim için okunur bir simge.
    'Siyaset': AppIcons.scaleBalanced,
    'Paradigma': AppIcons.brain,
    'Teknolojî': AppIcons.mobileScreen,
    'Sînema': AppIcons.clapperboard,
  };

  static const Map<String, String> _imagePaths = {
    'Ziman': 'assets/question_images/cat_ziman.webp',
    'Çand': 'assets/question_images/cat_cand.webp',
    'Dîrok': 'assets/question_images/cat_dirok.webp',
    'Edebiyat': 'assets/question_images/cat_edebiyat.webp',
    'Cografya': 'assets/question_images/cat_cografya.webp',
    'Muzîk': 'assets/question_images/cat_muzik.webp',
    'Siyaset': 'assets/question_images/cat_siyaset.webp',
    'Paradigma': 'assets/question_images/cat_paradigma.webp',
    // Henüz ayrı teknoloji görseli yok; mevcut soyut paradigma görseli
    // kategori kartında güvenli geçici kaynak olarak kullanılır.
    'Teknolojî': 'assets/question_images/cat_paradigma.webp',
    // Sînema için henüz ayrı görsel yok; kültür görseli geçici kaynaktır.
    'Sînema': 'assets/question_images/cat_cand.webp',
  };

  static IconData icon(String category) {
    final key = _resolveKey(category);
    return _icons[key] ?? AppIcons.tableCells;
  }

  static String imagePath(String category) {
    final key = _resolveKey(category);
    return _imagePaths[key] ?? 'assets/question_images/cat_ziman.webp';
  }
}
