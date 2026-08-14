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
/// tamamlanır tamamlanmaz doğal ilerlemeye geçer ve onunla birlikte
/// ilerlemeye devam eder.
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

  test('ilk ders tamamlanınca öneri SIKIŞMAZ, doğal ilerlemeye geçer', () {
    // Yerleştirme 2'yi önerdi ama kullanıcı 0'ı tamamladı (elle gidip
    // baştan başladı ya da yerleştirmeden önce zaten oradaydı). Öneri
    // artık gerçek ilerlemeyi (1) izlemeli — 2'de sıkışıp kalmamalı.
    expect(
      learningRecommendedIndex(
        lessons: lessons,
        completedLessonIds: const {'l0'},
        placementIndex: 2,
      ),
      1,
    );
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
