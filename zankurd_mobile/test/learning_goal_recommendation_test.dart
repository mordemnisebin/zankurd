import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';

void main() {
  const categories = ['Ziman', 'Çand', 'Dîrok', 'Edebiyat', 'Cografya'];

  test('seçim yoksa mevcut ilerleme odaklı öneriyi korur', () {
    expect(
      recommendedCategoryForGoal(
        goal: null,
        categories: categories,
        startedCategories: const ['Dîrok', 'Ziman'],
      ),
      'Dîrok',
    );
  });

  test('Kurmancî öğrenme amacı dil yolunu önerir', () {
    expect(
      recommendedCategoryForGoal(
        goal: LearningGoal.learnKurmanci,
        categories: categories,
        startedCategories: const ['Dîrok'],
      ),
      'Ziman',
    );
  });

  test('kültür amacı başlanmış kültür yolunu önerir', () {
    expect(
      recommendedCategoryForGoal(
        goal: LearningGoal.discoverCulture,
        categories: categories,
        startedCategories: const ['Ziman', 'Dîrok'],
      ),
      'Dîrok',
    );
  });

  test('kültür ilerlemesi yoksa Çand yoluna düşer', () {
    expect(
      recommendedCategoryForGoal(
        goal: LearningGoal.discoverCulture,
        categories: categories,
        startedCategories: const ['Ziman'],
      ),
      'Çand',
    );
  });
}
