import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';

void main() {
  group('Lesson Models', () {
    test('Lesson fromJson and toJson', () {
      final json = {
        'id': 'lesson1',
        'slug': 'alphabet',
        'title_ku': 'Alfabê',
        'title_tr': 'Alfabe',
        'description_ku': 'Hûwander',
        'category': 'everyday',
        'icon_name': 'abc',
        'order': 1,
      };

      final lesson = Lesson.fromJson(json);
      expect(lesson.id, 'lesson1');
      expect(lesson.slug, 'alphabet');
      expect(lesson.titleKu, 'Alfabê');

      final json2 = lesson.toJson();
      expect(json2['slug'], 'alphabet');
    });

    test('LessonSlide fromJson', () {
      final json = {
        'id': 'slide1',
        'lesson_id': 'lesson1',
        'order_in_lesson': 1,
        'content_ku': 'A, B, C',
        'content_tr': 'A, B, C',
      };

      final slide = LessonSlide.fromJson(json);
      expect(slide.order, 1);
      expect(slide.contentKu, 'A, B, C');
    });

    test('UserLessonProgress tracking', () {
      final progress = UserLessonProgress(
        userId: 'user1',
        lessonId: 'lesson1',
        completed: true,
        completedAt: DateTime(2026, 7, 6),
      );

      expect(progress.completed, true);
      expect(progress.completedAt?.year, 2026);
    });
  });

  group('Lesson Repository Mock', () {
    late MockZanKurdRepository repo;

    setUp(() {
      repo = MockZanKurdRepository();
    });

    test('loadLessonsByCategory returns lessons', () async {
      final lessons = await repo.loadLessonsByCategory('everyday');
      expect(lessons, isNotEmpty);
      expect(lessons.first.slug, 'everyday_1');
    });

    test('loadLesson returns lesson data', () async {
      final lesson = await repo.loadLesson('everyday_1');
      expect(lesson, isNotNull);
      expect(lesson?['slug'], 'everyday_1');
    });

    test('loadLessonSlides returns slides', () async {
      final slides = await repo.loadLessonSlides('everyday_1');
      expect(slides, isNotEmpty);
      expect(slides.first.order, 1);
    });

    test('markLessonCompleted returns true', () async {
      final marked = await repo.markLessonCompleted('everyday_1');
      expect(marked, true);
    });
  });
}
