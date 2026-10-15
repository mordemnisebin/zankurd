import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';

/// Yerleştirme sınavının öğrenme yolunda hiçbir etkisi yoktu; "Sana
/// önerilen" rozeti ilk ders tamamlanınca bir daha hiç görünmüyordu.
///
/// ## Kusur
///
/// Öneri kilitli bir düğüme düşerse (yani `placementIndex` sıralı
/// ilerlemenin İLERİSİNDEYSE — ki dersler kilitli olduğu için bu neredeyse
/// her zaman doğrudur) HER ZAMAN ilk açık derse geriliyordu. Sonuç iki
/// katlıydı:
///
/// 1. Yeni, ileri seviyeye yerleşen bir kullanıcı için önerilen düğüm her
///    zaman 0. sırada kalıyordu — yerleştirme sınavının SONUCU öğrenme
///    yolunda görünür hiçbir şey değiştirmiyordu.
/// 2. Kullanıcı ilk dersi tamamladığında öneri o (artık tamamlanmış)
///    derste sonsuza dek KİLİTLENİYORDU: `firstOpenIndex` ilerlerken
///    öneri ilerlemiyordu, rozet bir daha hiçbir karta düşmüyordu.
///
/// ## Bekçi
///
/// `learningRecommendedIndex` artık: (a) hiçbir ders tamamlanmamışken
/// yerleştirmenin önerdiği noktayı GERÇEKTEN kullanır, (b) bir ders
/// tamamlanınca yerleştirme noktasından ileriye doğru ilk açık dersi
/// önerir, (c) önerilene kadar her ders açıktır (`learningLessonLocked`).
///
/// ## Kusur 2 (2026-10-15)
///
/// Yerleştirmenin 2'yi önerdiği biri 2. dersi bitirince öneri 0'a dönüyor,
/// 3 ve sonrası kilitleniyordu; 0 ve 1 önerinin önünde oldukları için
/// kilitli kalmıştı. Testler yalnız tek tamamlanan ders senaryosuna
/// bakıyor, "kilit kimde" sorusunu sormuyordu.
void main() {
  const lessons = [
    Lesson(id: 'l0', slug: 'l0', titleKu: 'Yek', category: 'everyday'),
    Lesson(id: 'l1', slug: 'l1', titleKu: 'Du', category: 'everyday'),
    Lesson(id: 'l2', slug: 'l2', titleKu: 'Sê', category: 'everyday'),
    Lesson(id: 'l3', slug: 'l3', titleKu: 'Çar', category: 'everyday'),
  ];

  test(
    'hiçbir ders tamamlanmamışken yerleştirmenin önerdiği nokta kullanılır',
    () {
      // İleri seviyeye yerleşen kullanıcı en baştan başlamaz — bu, sınav
      // sonucunun öğrenme yoluna gerçek etkisidir.
      expect(
        learningRecommendedIndex(
          lessons: lessons,
          completedLessonIds: const {},
          placementIndex: 2,
        ),
        2,
      );
    },
  );

  test('ders tamamlanınca öneri yerleştirme noktasının gerisine düşmez', () {
    // 2026-10-15: bu test eskiden 1 bekliyordu ve kusuru kodluyordu —
    // yerleştirmenin 2'yi önerdiği biri 0'ı bitirince öneri 1'e geri
    // çekiliyordu. Öneri ileriye doğru aranır: 2'de kalır.
    expect(
      learningRecommendedIndex(
        lessons: lessons,
        completedLessonIds: const {'l0'},
        placementIndex: 2,
      ),
      2,
    );
  });

  test('önerilen dersten sonra bitirilen ders öneriyi 0\'a döndürmez', () {
    // Kusurun kalbi: yerleştirme 2'yi önerdi, kullanıcı 2'yi bitirdi.
    expect(
      learningRecommendedIndex(
        lessons: lessons,
        completedLessonIds: const {'l2'},
        placementIndex: 2,
      ),
      3,
    );
  });

  test('yerleştirmeden sonra açık ders kalmadıysa baştaki ilk açığa düşer', () {
    expect(
      learningRecommendedIndex(
        lessons: lessons,
        completedLessonIds: const {'l2', 'l3'},
        placementIndex: 2,
      ),
      0,
    );
  });

  group('kilit', () {
    test('önerilene kadar (kendisi dahil) her ders açık, sonrası kilitli', () {
      bool locked(int i, {bool done = false}) =>
          learningLessonLocked(index: i, completed: done, recommendedIndex: 2);
      expect(locked(0), isFalse);
      expect(locked(1), isFalse);
      expect(locked(2), isFalse);
      expect(locked(3), isTrue);
    });

    test('tamamlanan ders önerinin ilerisinde de açık kalır', () {
      expect(
        learningLessonLocked(index: 3, completed: true, recommendedIndex: 1),
        isFalse,
      );
    });

    test('hepsi tamamlanınca (-1) hiçbir ders kilitli değildir', () {
      expect(
        learningLessonLocked(index: 3, completed: false, recommendedIndex: -1),
        isFalse,
      );
    });
  });

  test(
    'yerleştirmenin önerdiği ders tamamlanınca öneri bir sonrakine geçer',
    () {
      // Kusurun kalbi: kullanıcı TAM DA yerleştirmenin önerdiği dersi
      // tamamladı. Eski kodda öneri hâlâ o (artık tamamlanmış) derse
      // işaret ediyordu — rozet bir daha hiçbir yerde görünmüyordu.
      expect(
        learningRecommendedIndex(
          lessons: lessons,
          completedLessonIds: const {'l0', 'l1', 'l2'},
          placementIndex: 2,
        ),
        3,
        reason:
            'l2 (placementIndex) tamamlandı; öneri sonraki açık derse '
            '(l3) geçmeli, l2\'de sıkışıp kalmamalı',
      );
    },
  );

  test('tüm dersler tamamlanınca -1 döner (indexWhere sözleşmesi)', () {
    expect(
      learningRecommendedIndex(
        lessons: lessons,
        completedLessonIds: const {'l0', 'l1', 'l2', 'l3'},
        placementIndex: 1,
      ),
      -1,
    );
  });
}
