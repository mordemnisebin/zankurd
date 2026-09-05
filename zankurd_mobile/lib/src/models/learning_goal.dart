enum LearningGoal {
  learnKurmanci('learn_kurmanci'),
  discoverCulture('discover_culture');

  const LearningGoal(this.storageKey);

  final String storageKey;

  static LearningGoal? fromStorageKey(String? value) {
    for (final goal in values) {
      if (goal.storageKey == value) return goal;
    }
    return null;
  }
}

const _cultureCategories = ['Çand', 'Dîrok', 'Edebiyat', 'Cografya'];

/// Kullanıcının amacını ana ekrandaki tek önerilen kategoriye dönüştürür.
/// Seçim yapılmadığında eski, ilerleme odaklı sıralama aynen korunur.
String recommendedCategoryForGoal({
  required LearningGoal? goal,
  required List<String> categories,
  required List<String> startedCategories,
}) {
  if (goal == null) {
    if (startedCategories.isNotEmpty) return startedCategories.first;
    return categories.isEmpty ? 'Ziman' : categories.first;
  }

  if (goal == LearningGoal.learnKurmanci && categories.contains('Ziman')) {
    return 'Ziman';
  }

  for (final category in startedCategories) {
    if (_cultureCategories.contains(category) &&
        categories.contains(category)) {
      return category;
    }
  }
  for (final category in _cultureCategories) {
    if (categories.contains(category)) return category;
  }
  return categories.isEmpty ? 'Ziman' : categories.first;
}
