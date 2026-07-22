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

  /// Kategori → gradyan renk çifti. Değerler `AppTheme.categoryGradients`
  /// paletinden seçildi; kategori listesindeki yerleşik renkler korunarak
  /// eşlendi, böylece kullanıcının öğrendiği renk kimliği değişmiyor.
  static const Map<String, List<Color>> _gradients = {
    'Ziman': [Color(0xFFD47C3B), Color(0xFFC0672A)], // turuncu
    'Siyaset': [Color(0xFFB54C6F), Color(0xFF9E3C5B)], // gül
    'Paradigma': [Color(0xFF4A74B8), Color(0xFF385E9D)], // mavi
    'Muzîk': [Color(0xFFD1A23A), Color(0xFFB88C2A)], // kehribar
    'Edebiyat': [Color(0xFF2B8A50), Color(0xFF227542)], // yeşil
    'Dîrok': [Color(0xFFC75D6D), Color(0xFFB04B5A)], // kızıl
    'Cografya': [Color(0xFF865DB8), Color(0xFF704A9E)], // mor
    'Çand': [Color(0xFF288077), Color(0xFF1E6962)], // turkuaz
    'Teknolojî': [Color(0xFF4A74B8), Color(0xFF385E9D)],
  };

  static const List<Color> _fallbackGradient = [
    Color(0xFFD47C3B),
    Color(0xFFC0672A),
  ];

  /// Rengi açıkça tanımlanmış kategoriler. Yeni bir kategori eklenirse
  /// burada da tanımlanmalı; aksi halde fallback renge düşer.
  static Iterable<String> get colorDefinedCategories => _gradients.keys;

  /// Kategorinin gradyan renk çifti (adına göre, sıradan bağımsız).
  static List<Color> gradientColors(String category) =>
      _gradients[category] ?? _fallbackGradient;

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
  };

  static IconData icon(String category) =>
      _icons[category] ?? AppIcons.tableCells;

  static String imagePath(String category) =>
      _imagePaths[category] ?? 'assets/question_images/cat_ziman.webp';
}
