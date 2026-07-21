import 'package:flutter/material.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Kategori bazlı görsel kaynak (ikon + arka plan görseli) için tek doğruluk kaynağı.
/// Gradient için AppTheme.categoryGradient(index) kullanılmaya devam eder.
class CategoryVisuals {
  const CategoryVisuals._();

  static const Map<String, IconData> _icons = {
    'Ziman': AppIcons.language,
    'Çand': AppIcons.peopleGroup,
    'Dîrok': AppIcons.buildingColumns,
    'Edebiyat': AppIcons.bookOpen,
    'Cografya': AppIcons.globe,
    'Muzîk': AppIcons.music,
    'Siyaset': AppIcons.squareCheck,
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
