import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';

/// Öğrenme konusu ile soru bankası kategorisi FARKLI isim uzayında.
///
/// ## Kusur
///
/// Dersler konuşma/dilbilgisi konularıyla (`everyday`, `grammar`, `food`,
/// `animals`, `emotions`, `time`, `culture`, `geography`) etiketlenir;
/// soru bankası geniş konu alanlarıyla (`Ziman`, `Çand`, `Cografya`...).
/// `learning_screen.dart` "Soru Çöz" ve mini quiz için
/// `loadLevelQuestions(category: lesson.category)` çağırıyordu — bu iki
/// isim hiçbir zaman eşleşmiyordu. Havuz boş kalınca depo TÜM
/// kategorilerin karışımına düşüyordu: dersle hiç ilgisi olmayan
/// rastgele sorular geliyordu (2026-08-14 denetimi).
///
/// ## Bekçi
///
/// `quizCategoryForLesson` gerçek soru bankası kategorileriyle
/// (`MockZanKurdRepository.categories`, dolayısıyla üretim bankasıyla
/// aynı isim kümesi) eşleşen bir değer döndürmeli — bir sonraki adımda
/// `loadLevelQuestions` bu değeri arayacak.
void main() {
  test('her ders konusu gerçek bir soru bankası kategorisine eşlenir', () {
    final repository = MockZanKurdRepository();
    const lessonCategories = [
      'everyday',
      'grammar',
      'culture',
      'food',
      'animals',
      'geography',
      'emotions',
      'time',
    ];
    for (final lessonCategory in lessonCategories) {
      final quizCategory = quizCategoryForLesson(lessonCategory);
      expect(
        repository.categories,
        contains(quizCategory),
        reason:
            '"$lessonCategory" konusu "$quizCategory" kategorisine '
            'eşleniyor ama bu kategori soru bankasında yok — '
            'loadLevelQuestions yine boş dönüp rastgele soruya düşer',
      );
    }
  });

  test('kültür ve coğrafya kendi birebir karşılığına gider', () {
    // Bu ikisi bankada BİREBİR karşılığı olan tek konular — uydurulmadı.
    expect(quizCategoryForLesson('culture'), 'Çand');
    expect(quizCategoryForLesson('geography'), 'Cografya');
  });

  test('sözcük dağarcığı konuları dil kategorisine gider', () {
    for (final vocab in ['everyday', 'grammar', 'food', 'animals', 'emotions', 'time']) {
      expect(quizCategoryForLesson(vocab), 'Ziman', reason: vocab);
    }
  });
}
