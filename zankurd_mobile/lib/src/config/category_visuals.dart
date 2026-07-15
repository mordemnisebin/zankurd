import 'package:flutter/material.dart';

/// Kategori bazlı görsel kaynak (ikon + arka plan görseli) için tek doğruluk kaynağı.
/// Gradient için AppTheme.categoryGradient(index) kullanılmaya devam eder.
class CategoryVisuals {
  const CategoryVisuals._();

  static const Map<String, IconData> _icons = {
    'Ziman': Icons.translate_outlined,
    'Çand': Icons.diversity_3_outlined,
    'Dîrok': Icons.account_balance_outlined,
    'Edebiyat': Icons.menu_book_outlined,
    'Cografya': Icons.public_outlined,
    'Muzîk': Icons.music_note_outlined,
    'Siyaset': Icons.how_to_vote_outlined,
    'Paradigma': Icons.psychology_outlined,
    'Teknolojî': Icons.devices_other_outlined,
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
      _icons[category] ?? Icons.category_outlined;

  static String imagePath(String category) =>
      _imagePaths[category] ?? 'assets/question_images/cat_ziman.webp';
}
