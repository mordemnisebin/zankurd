import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'support/widget_test_helpers.dart';

/// Ders slayt metinlerinde yazım artığı yok: çift nokta, çift boşluk,
/// noktalamadan önce boşluk.
///
/// ## Kusur
///
/// "Xwe nasandin" 3. slaytının açıklaması `Stenbol → Stenbolê..` diye
/// bitiyordu (2026-10-07 simülatör QA'sı): cümle sonu noktası, örnekteki
/// "Stenbolê." sonuna bir kez daha eklenmişti.
///
/// Sessizdi çünkü slayt metni serbest dizgedir; hiçbir test içeriğini
/// okumuyordu (yalnız slayt SAYISI ve sıra sabitleniyordu) ve görsel
/// turda iki nokta gözden kaçar.
void main() {
  test(
    'slayt metinlerinde "..", çift boşluk ve boşluk+noktalama yok',
    () async {
      final repository = freshMockRepository();
      final lessons = [
        for (final category in const [
          'everyday',
          'grammar',
          'culture',
          'food',
          'animals',
          'emotions',
          'time',
          'alphabet',
          'greetings',
          'family',
          'intro',
          'numbers',
          'body',
        ])
          ...await repository.loadLessonsByCategory(category),
      ];
      expect(lessons, isNotEmpty);
      final bad = <String>[];
      final seen = <String>{};
      for (final lesson in lessons) {
        if (!seen.add(lesson.id)) continue;
        final slides = await repository.loadLessonSlides(lesson.id);
        for (final LessonSlide slide in slides) {
          for (final text in [
            slide.contentKu,
            slide.contentTr,
            slide.exampleKu,
          ]) {
            final value = text ?? '';
            // Üç nokta (…) yazımı "..." serbest; tam iki nokta artıktır.
            if (RegExp(r'(?<!\.)\.\.(?!\.)').hasMatch(value) ||
                value.contains('  ') ||
                RegExp(r'[^\s\n] +[,;:!?.](?=\s|$)').hasMatch(value)) {
              bad.add('${lesson.slug}#${slide.order}: $value');
            }
          }
        }
      }
      expect(bad, isEmpty, reason: bad.join('\n'));
    },
  );
}
