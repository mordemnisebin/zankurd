// Ders kartının alt başlığı Türkçe modda da Kurmancî görünüyordu: Lesson
// modelinde ve lessons tablosunda Türkçe açıklama hiç yoktu, ekran
// descriptionKu'yu dil sormadan okuyordu. Yanlış dilde metin hata vermez;
// yalnız gözle fark edilir (2026-10-15 denetimi).
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';

void main() {
  const categories = [
    'everyday',
    'grammar',
    'culture',
    'food',
    'animals',
    'geography',
    'emotions',
    'time',
  ];

  test(
    'Kurmancî açıklaması olan her çevrimdışı dersin Türkçesi de var',
    () async {
      final repository = MockZanKurdRepository();
      var checked = 0;
      for (final category in categories) {
        for (final lesson in await repository.loadLessonsByCategory(category)) {
          if ((lesson.descriptionKu ?? '').trim().isEmpty) continue;
          checked++;
          expect(
            (lesson.descriptionTr ?? '').trim(),
            isNotEmpty,
            reason: '${lesson.slug} Türkçe açıklamasız',
          );
          expect(lesson.descriptionTr, isNot(lesson.descriptionKu));
        }
      }
      expect(checked, greaterThan(0));
    },
  );

  test('açıklama dile göre seçilir; Türkçesi yoksa Kurmancıya düşmez', () {
    final lesson = Lesson.fromJson(const {
      'id': 'x',
      'slug': 'x',
      'title_ku': 'Malbat',
      'description_ku': 'Endamên malbatê',
      'description_tr': 'Aile bireyleri',
    });
    expect(lesson.description(true), 'Endamên malbatê');
    expect(lesson.description(false), 'Aile bireyleri');
    expect(lesson.toJson()['description_tr'], 'Aile bireyleri');

    const onlyKu = Lesson(
      id: 'y',
      slug: 'y',
      titleKu: 'Reng',
      descriptionKu: 'Rengên bingehîn',
      category: 'everyday',
    );
    expect(onlyKu.description(false), isNull);
  });
}
