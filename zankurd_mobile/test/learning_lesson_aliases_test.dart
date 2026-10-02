// 2026-10-02 uçtan uca QA: sunucu dersinde "Kısa test" boş dönüyordu.
//
// ## Kusur
//
// Kısa test soruları YEREL ders kimlikleriyle (`everyday_1`) etiketlidir;
// sunucudaki dersin kimliği UUID, slug'ı `silav-u-nasin`. Ders ekranı sunucu
// dersinde UUID ile soru arıyor, bankada karşılığı olmadığı için
// "Selamlaşma ve Tanışma" ile "Zamirler" boş kalıyordu (aynı ekrandaki "Soru
// çöz" kategori havuzundan çektiği için çalışıyordu).
//
// ## Niçin sessiz kalıyordu
//
// Bütün testler yerel dersleri (`id == slug`) kullanır; sunucu kataloğuyla
// hiç koşulmuyordu. Boş durum da "Quiz yüklenemedi" diye ağ hatası gibi
// yazıyordu.
//
// ## Bekçi
//
// Üretim `lessons` tablosunun 15 slug'ı (2026-10-02) burada sabittir. Her biri
// ya eşlenir (ve eşlenen ders KENDİ etiketli sorularını döndürür) ya da
// [LearningLessonAliases.unmapped] içinde adıyla durur ve boş döner. Yerel
// katalogdaki her ders kimliği de soru döndürmek zorundadır.
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/learning_lesson_aliases.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';

import 'support/widget_test_helpers.dart';

/// Üretim `lessons` tablosu, 2026-10-02: slug -> kategori.
const _productionLessons = <String, String>{
  'silav-u-nasin': 'everyday',
  'hejmar': 'everyday',
  'cinavk': 'grammar',
  'lekera-bun': 'grammar',
  'newroz': 'culture',
  'dengbeji': 'culture',
  'xwarinen-kurdi': 'food',
  'feki-u-sebze': 'food',
  'ajalen-male': 'animals',
  'ajalen-kovi': 'animals',
  'ciya-u-cem': 'geography',
  'cih-u-war': 'geography',
  'hesten-bingehin': 'emotions',
  'rojen-hefteye': 'time',
  'demsal': 'time',
};

void main() {
  late MockZanKurdRepository repository;
  setUp(() => repository = freshMockRepository());

  test('her üretim dersi eşlenmiş ya da açıkça eşlenmemiş sayılır', () {
    final mapped = LearningLessonAliases.bySlug.keys.toSet();
    const unmapped = LearningLessonAliases.unmapped;
    expect(mapped.intersection(unmapped), isEmpty);
    expect(
      {...mapped, ...unmapped},
      _productionLessons.keys.toSet(),
      reason: 'sunucuya ders eklendiyse eşle ya da unmapped içine yaz',
    );
    for (final ids in LearningLessonAliases.bySlug.values) {
      for (final id in ids) {
        expect(
          LearnerLexicon.sources.containsKey(id),
          isTrue,
          reason: '$id yerel ölçme bankasında yok',
        );
      }
    }
  });

  for (final entry in _productionLessons.entries) {
    final slug = entry.key;
    final category = quizCategoryForLesson(entry.value);
    final mapped = LearningLessonAliases.bySlug.containsKey(slug);
    test('sunucu dersi $slug: kısa test ${mapped ? 'dolu' : 'boş'}', () async {
      final questions = await repository.loadLearningQuizQuestions(
        category: category,
        learningLessonId: slug,
        limit: 5,
      );
      if (!mapped) {
        expect(questions, isEmpty);
        return;
      }
      final bankIds = LearningLessonAliases.bankIdsFor(slug);
      expect(questions, isNotEmpty, reason: '$slug kısa testi boş döndü');
      expect(
        questions.every((q) => bankIds.contains(q.metadata?.learningLessonId)),
        isTrue,
        reason: 'yalnız bu dersin soruları gelmeli',
      );
      // Etiketli soru varsa başta gelir.
      final tagged = repository.playableQuestions.where(
        (q) =>
            q.category == category &&
            bankIds.contains(q.metadata?.learningLessonId),
      );
      if (tagged.isNotEmpty) {
        expect(
          tagged.map((q) => q.id),
          contains(questions.first.id),
          reason: 'etiketli soru dolgudan önce gelmeli',
        );
      }
    });
  }

  test('yerel katalogdaki her ders kimliği kısa test soru döndürür', () async {
    for (final category in const [
      'everyday',
      'grammar',
      'culture',
      'food',
      'animals',
      'geography',
      'emotions',
      'time',
    ]) {
      final lessons = await repository.loadLessonsByCategory(category);
      expect(lessons, isNotEmpty, reason: category);
      for (final lesson in lessons) {
        final questions = await repository.loadLearningQuizQuestions(
          category: quizCategoryForLesson(lesson.category),
          learningLessonId: lesson.slug,
          limit: 5,
        );
        expect(questions, isNotEmpty, reason: '${lesson.slug} boş');
      }
    }
  });

  test(
    'Selamlaşma ve Tanışma iki yerel dersin sorularını karıştırır',
    () async {
      final questions = await repository.loadLearningQuizQuestions(
        category: 'Ziman',
        learningLessonId: 'silav-u-nasin',
        limit: 10,
      );
      final ids = questions
          .map((q) => q.metadata?.learningLessonId)
          .whereType<String>()
          .toSet();
      expect(ids, containsAll(['everyday_1', 'everyday_2']));
    },
  );
}
