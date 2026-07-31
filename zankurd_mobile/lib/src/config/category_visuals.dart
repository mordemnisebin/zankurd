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

  /// Kategori → renk çifti. 2026-07-24 yenilemesi: tonlar tek bir doygunluk
  /// bandına çekildi (orta ton, düşük kroma) — böylece sekiz kategori yan yana
  /// durduğunda göz yorulmuyor ve hiçbiri eylem turuncusuyla (Tîrêj)
  /// yarışmıyor. Ziman turuncudan çıkarıldı çünkü CTA rengiyle çakışıyordu.
  ///
  /// Bu renkler artık kartın tamamını doldurmaz; ikon karosu ve ince kenar
  /// şeridi gibi küçük kimlik alanlarında kullanılır.
  static const Map<String, List<Color>> _gradients = {
    'Ziman': [Color(0xFF2F6F62), Color(0xFF24564C)], // çam yeşili
    'Çand': [Color(0xFF6B5AA6), Color(0xFF55458A)], // mor
    'Dîrok': [Color(0xFFA85A7A), Color(0xFF8C4763)], // gül
    'Edebiyat': [Color(0xFF3C6EA5), Color(0xFF2F5885)], // mavi
    'Cografya': [Color(0xFF8A6A2F), Color(0xFF6E5325)], // toprak sarısı
    'Muzîk': [Color(0xFF5C7A3A), Color(0xFF48602C)], // zeytin
    'Siyaset': [Color(0xFF9E5B4A), Color(0xFF80463A)], // terracotta
    'Paradigma': [Color(0xFF566B7F), Color(0xFF425364)], // arduvaz
    // Teknolojî kategori açılana kadar Paradigma'nın arduvaz tonunu
    // paylaşıyordu; iki kart yan yana ayırt edilemiyordu (2026-07-26).
    // Turkuaz, mevcut dokuz tonun hiçbirine yakın değil ve aynı doygunluk
    // bandında kalıyor.
    'Teknolojî': [Color(0xFF2E7D8A), Color(0xFF23626C)], // turkuaz
    // Sînema: koyu bordo — mevcut sekiz tonun hiçbiriyle çakışmayan, aynı
    // doygunluk bandında kalan bir kimlik.
    'Sînema': [Color(0xFF8C4A5C), Color(0xFF703A49)],
  };

  static const List<Color> _fallbackGradient = [
    Color(0xFF2F6F62),
    Color(0xFF24564C),
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
