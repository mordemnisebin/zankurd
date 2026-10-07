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

  test('hedef yoksa yeterli kanıttaki odak kategori yolu yönlendirir', () {
    expect(
      recommendedCategoryForGoal(
        goal: null,
        categories: categories,
        startedCategories: const ['Ziman'],
        focusCategory: 'Dîrok',
      ),
      'Dîrok',
    );
  });

  test('Kurmancî hedefi kültür odağı tarafından ezilmez', () {
    expect(
      recommendedCategoryForGoal(
        goal: LearningGoal.learnKurmanci,
        categories: categories,
        startedCategories: const ['Dîrok'],
        focusCategory: 'Dîrok',
      ),
      'Ziman',
    );
  });

  test('kültür hedefi uyumlu zayıf kültür kategorisine odaklanabilir', () {
    expect(
      recommendedCategoryForGoal(
        goal: LearningGoal.discoverCulture,
        categories: categories,
        startedCategories: const ['Çand'],
        focusCategory: 'Dîrok',
      ),
      'Dîrok',
    );
  });

  test('kültür hedefi Ziman odağını reddedip mevcut kültür yolunu korur', () {
    expect(
      recommendedCategoryForGoal(
        goal: LearningGoal.discoverCulture,
        categories: categories,
        startedCategories: const ['Çand'],
        focusCategory: 'Ziman',
      ),
      'Çand',
    );
  });
}
