import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

/// Bir tur, havuzda yeterli soru varken kısalmaz.
///
/// ## Kusur
///
/// "Dil › Kelime Bilgisi › 1. Seviye" kartı "10 soru" diyordu; tur **tek
/// soruda** bitiyor ve sonuç ekranı "Yarış tamamlandı — 1 Doğru" gösteriyordu
/// (2026-08-16 simülatör taraması, iPhone 17).
///
/// Sebep tek bir süzgeç değil, süzgeçlerin üst üste binmesiydi:
/// `preferUnseen` görülmüşleri geri plana atar, `_dedupeByTranslationPair`
/// aynı kelime çiftini soran soruları toplar, `withoutLeaks` birbirinin
/// cevabını ele verenleri eler. Kelime bilgisi havuzunda soruların hemen
/// hepsi aynı küçük şık kümesinden beslenen çeviri sorusu olduğu için üçü
/// birlikte otuz adaydan geriye bir tane bırakabiliyordu. Seçim kodu yalnız
/// sonuç BOŞSA yedeğe düşüyor, "bir" sonucunu geçerli sayıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Testler seçimin *kalitesini* ölçüyordu — tekrar yok, sızıntı yok, boş
/// değil. Hiçbiri turun **uzunluğunu** ölçmüyordu; bir soruluk bir tur bütün
/// kalite koşullarını mükemmel geçer. Üretim bankası da testlerde
/// `QuestionBankLoader` ile yüklenmediği için mevcut fixture'lar bu daralmayı
/// hiç üretmiyordu; bu yüzden bekçi mekanizmayı kendi kurar.
class _LeakyBankRepository extends MockZanKurdRepository {
  /// Hepsi aynı dört şıkkı paylaşan sorular: her sorunun doğru cevabı
  /// ötekilerin şıkları arasında geçtiği için `withoutLeaks` ilkinden
  /// sonrasını eler. Gerçek kelime bilgisi havuzunun daraldığı durumun
  /// laboratuvar hâli.
  static const _options = ['hezkirin', 'dîtin', 'bihîstin', 'xwarin'];

  @override
  List<QuizQuestion> get questions => [
    for (var i = 0; i < 24; i++)
      QuizQuestion(
        id: 'leaky-$i',
        category: 'Ziman',
        prompt: '$i. soru: bu fiilin Kurmancî karşılığı nedir?',
        answers: _options,
        correctAnswer: _options[i % _options.length],
        explanation: 'Açıklama $i',
        difficulty: 1,
      ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sızıntı süzgeci daraltsa da tur istenen uzunlukta gelir', () async {
    final repository = _LeakyBankRepository();

    final questions = await repository.loadLevelQuestions(
      category: 'Ziman',
      difficultyMin: 1,
      difficultyMax: 2,
      limit: 10,
    );

    expect(
      questions.length,
      10,
      reason:
          'Seviye kartı "10 soru" diyor; tur bundan kısa gelirse oyuncu tek '
          'soruda "tamamlandı" ekranını görür.',
    );
    expect(
      questions.map((q) => q.id).toSet().length,
      questions.length,
      reason: 'Aynı soru bir turda iki kez sorulmamalı.',
    );
  });

  test('aynı seviye üst üste oynandığında da tur kısalmaz', () async {
    final repository = _LeakyBankRepository();

    // İlk tur havuzun "görülmemiş" kısmını tüketir; kusur ikinci ve
    // üçüncü turda daha da belirginleşiyordu.
    for (var round = 1; round <= 3; round++) {
      final questions = await repository.loadLevelQuestions(
        category: 'Ziman',
        difficultyMin: 1,
        difficultyMax: 2,
        limit: 10,
      );
      expect(questions.length, 10, reason: '$round. turda uzunluk düştü');
    }
  });

  test('oda turu da istenen uzunlukta gelir', () async {
    final repository = _LeakyBankRepository();
    final room = repository.createRoom();

    final questions = await repository.loadRoomQuestions(room);

    expect(questions.length, room.questionCount);
  });

  test('havuz gerçekten küçükse fazlası uydurulmaz', () async {
    final repository = _LeakyBankRepository();

    final questions = await repository.loadLevelQuestions(
      category: 'Ziman',
      difficultyMin: 1,
      difficultyMax: 2,
      limit: 100,
    );

    expect(
      questions.length,
      lessThanOrEqualTo(24),
      reason: 'Havuzda 24 soru var; tur bundan fazlasını üretmemeli.',
    );
    expect(questions.map((q) => q.id).toSet().length, questions.length);
  });
}
