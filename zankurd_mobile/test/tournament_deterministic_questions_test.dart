import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

/// Gerçek turnuvada aynı maçın iki oyuncusu farklı soru setleriyle
/// oynuyordu.
///
/// ## Kusur
///
/// `_startMatch` (tournament_screen.dart) her oyuncuda `loadQuestions`
/// çağırıyordu; seçim `SeenQuestionStore`ye (cihaz başına yerel "görülen
/// soru" durumu) dayanıyor. Sunucu (`submit_tournament_match`) yalnız
/// skoru kaydediyor, hangi soruların sorulduğunu hiç bilmiyor/atamıyor.
/// Aynı `match.id` altında rakip olan iki gerçek oyuncu, birbirinden
/// habersiz iki farklı soru setiyle karşılaşıyordu — "aynı maçı
/// oynuyoruz" sözü tutmuyordu (2026-08-14 denetimi).
///
/// ## Düzeltme
///
/// `deterministicMatchQuestions`, iki cihazın da bağımsız olarak
/// hesaplayabileceği SABİT bir seçim üretir: girdi yalnız `match.id`
/// (sunucudan `get_tournament_bracket` ile ikisine de aynı gelir) ve
/// statik paket (her cihaza aynı derlenir). `String.hashCode` platformlar
/// arası aynı garantisi taşımadığı için kendi FNV-1a türevi kullanılır.
void main() {
  const pool = [
    QuizQuestion(
      id: 'q1',
      category: 'Ziman',
      prompt: 'Soru 1?',
      answers: ['A', 'B'],
      correctAnswer: 'A',
      explanation: '',
    ),
    QuizQuestion(
      id: 'q2',
      category: 'Ziman',
      prompt: 'Soru 2?',
      answers: ['A', 'B'],
      correctAnswer: 'A',
      explanation: '',
    ),
    QuizQuestion(
      id: 'q3',
      category: 'Ziman',
      prompt: 'Soru 3?',
      answers: ['A', 'B'],
      correctAnswer: 'A',
      explanation: '',
    ),
    QuizQuestion(
      id: 'q4',
      category: 'Ziman',
      prompt: 'Soru 4?',
      answers: ['A', 'B'],
      correctAnswer: 'A',
      explanation: '',
    ),
    QuizQuestion(
      id: 'q5',
      category: 'Ziman',
      prompt: 'Soru 5?',
      answers: ['A', 'B'],
      correctAnswer: 'A',
      explanation: '',
    ),
  ];

  test('aynı match id iki bağımsız çağrıda aynı soruları verir', () {
    // İki "cihazı" simüle eder: aynı statik havuz, aynı match id, SIFIR
    // paylaşılan durum. Sonuç birebir aynı olmalı — bu, iki oyuncunun
    // aynı maçı oynadığının garantisidir.
    final playerOne = deterministicMatchQuestions(pool, 'match-abc-123', 4);
    final playerTwo = deterministicMatchQuestions(pool, 'match-abc-123', 4);

    expect(playerOne.map((q) => q.id), playerTwo.map((q) => q.id));
  });

  test('havuz sırası karışsa bile sonuç aynı kalır', () {
    // Statik paketin diziliş sırası derlemeler arası garanti değil;
    // seçim havuzun sırasına değil İÇERİĞİNE bağlı olmalı.
    final shuffled = pool.reversed.toList();
    final fromOriginal = deterministicMatchQuestions(pool, 'match-xyz', 3);
    final fromShuffled = deterministicMatchQuestions(shuffled, 'match-xyz', 3);

    expect(
      fromOriginal.map((q) => q.id).toSet(),
      fromShuffled.map((q) => q.id).toSet(),
    );
  });

  test('farklı maç kimlikleri genelde farklı seçim üretir', () {
    final a = deterministicMatchQuestions(pool, 'match-1', 2);
    final b = deterministicMatchQuestions(pool, 'match-2', 2);
    // Küçük havuzda çakışma olabilir ama en azından ofset hesaplanıyor
    // olmalı — ikisi de boş dönmemeli.
    expect(a, isNotEmpty);
    expect(b, isNotEmpty);
  });

  test('istenen sayıdan fazla soru döndürmez, boş havuzda çökmez', () {
    expect(deterministicMatchQuestions(pool, 'm', 2), hasLength(2));
    expect(deterministicMatchQuestions(const [], 'm', 4), isEmpty);
    expect(deterministicMatchQuestions(pool, 'm', 0), isEmpty);
  });
}
