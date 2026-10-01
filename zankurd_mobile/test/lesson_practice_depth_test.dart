import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Dersin sonundaki alıştırmanın derinliği.
///
/// ## Kusur
///
/// On dört dersin (günlük konuşma, zamirler, yemek, hayvan, duygu, zaman,
/// folklor, bayramlar) uçtaki alıştırması için `learningLessonId` ile
/// etiketli soru ya hiç yoktu ya da bir elin parmağı kadardı:
/// `everyday_2` ve `emotions_2` 0, `emotions_1` ve `time_1` 1,
/// `animals_2` 2, `culture_2`, `everyday_1` ve `grammar_1` 3. `loadLearningQuizQuestions` eksiği
/// sözlük çiftlerinden üretilen ölçme sorularıyla
/// (`LearningAssessmentBank`) doldurur; yani ekran hiç boş görünmedi,
/// hiçbir test kırılmadı. Fark yalnız şuydu: oyuncu ders başına
/// şablondan üretilmiş birkaç soruyla (kelime → anlam, anlam → kelime)
/// karşılaşıyordu; editörün yazdığı, çeşitli soru tipleri (durum, cümle
/// tamamlama) gelmiyordu.
///
/// Sessizdi, çünkü dolgu mekanizması tam da "etiketli soru yok" durumunu
/// görünmez kılmak için yazılmıştı; hiçbir şey etiketli sorunun sayısını
/// ölçmüyordu.
///
/// 2026-10-01: eksik dersler için 77 soru yazıldı (`ders_2026_10_01_questions.json`).
/// Üçü ilk turda kalite bekçilerine takıldı (`_0005` cevabı sorunun içinde
/// veriyordu; `_0012`/`_0013`'te soruda alıntılanan cümle şıklardan biriydi)
/// ve aynı gün yeniden yazılıp eklendi. Bu bekçi, her dersin en az
/// [_minTagged] OYNANABİLİR ve dersin kendi test kategorisinde etiketli
/// soruya sahip olduğunu sabitler (alt sınır; daha fazlası serbest).
const _minTagged = 8;

/// Bilerek 8'in altında kalan dersler (şu an yok).
const _minOverrides = <String, int>{};

/// Eksiği giderilen dersler ve kategorileri
/// (`quizCategoryForLesson(lesson.category)`).
const _lessonCategories = <String, String>{
  'everyday_1': 'everyday',
  'everyday_2': 'everyday',
  'everyday_3': 'everyday',
  'grammar_1': 'grammar',
  'culture_1': 'culture',
  'culture_2': 'culture',
  'food_1': 'food',
  'food_2': 'food',
  'animals_1': 'animals',
  'animals_2': 'animals',
  'emotions_1': 'emotions',
  'emotions_2': 'emotions',
  'time_1': 'time',
  'time_2': 'time',
};

/// Her ders için bu dosyanın eklediği soru sayısı.
const _added = <String, int>{
  'everyday_1': 5,
  'everyday_2': 8,
  'everyday_3': 3,
  'grammar_1': 5,
  'culture_1': 4,
  'culture_2': 6,
  'food_1': 4,
  'food_2': 8,
  'animals_1': 4,
  'animals_2': 6,
  'emotions_1': 7,
  'emotions_2': 8,
  'time_1': 7,
  'time_2': 2,
};

void main() {
  const policy = QuestionContentPolicy();
  late List<QuizQuestion> playable;

  setUpAll(() {
    playable = QuestionBankLoader.instance.allQuestions
        .where(policy.isPlayable)
        .toList();
  });

  for (final entry in _lessonCategories.entries) {
    final min = _minOverrides[entry.key] ?? _minTagged;
    test('${entry.key}: en az $min etiketli oynanabilir alıştırma', () {
      final category = quizCategoryForLesson(entry.value);
      final tagged = playable.where(
        (q) =>
            q.category == category && q.metadata?.learningLessonId == entry.key,
      );
      expect(
        tagged.length,
        greaterThanOrEqualTo(min),
        reason:
            '${entry.key} dersinin "$category" kategorisinde etiketli '
            'oynanabilir soru sayısı düştü; ders alıştırması sözlük '
            'dolgusuna yaslanıyor olabilir.',
      );
    });
  }

  test('yeni 77 soru oynanabilir ve derslerine dağılmış', () {
    final added = playable.where((q) => q.id.startsWith('ders_2026_10_01_'));
    expect(added.length, 77);
    expect(_added.values.fold<int>(0, (a, b) => a + b), 77);
    for (final entry in _added.entries) {
      expect(
        added.where((q) => q.metadata?.learningLessonId == entry.key).length,
        entry.value,
        reason: entry.key,
      );
    }
  });
}
