import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

/// Ders ikonu haritası yalnız mock slug'larıyla eşleşiyordu.
///
/// ## Kusur
///
/// `_iconForLesson` yalnız `Lesson.slug`e bakıyordu ve yalnız mock'un
/// numaralı ailelerini (`everyday_1` → `everyday`) tanıyordu.
/// `2026-07-06_lesson_seed.sql`deki 15 gerçek dersin slug'ları Kurmancî
/// bileşik sözcüklerdir (`silav-u-nasin`, `hejmar`, `cinavk`...) — hiçbiri
/// ne tam ne aile olarak eşleşmiyordu. Sonuç: gerçek sunucu içeriğiyle
/// açılan ders listesi HER satırda aynı yedek ikonu (mezuniyet külahı)
/// gösteriyordu — görsel olarak tekdüzeydi ve hangi dersin ne hakkında
/// olduğuna dair hiçbir ipucu vermiyordu (2026-08-14 denetimi).
///
/// ## Düzeltme
///
/// Sunucu zaten her satır için özel seçilmiş bir `icon_name` (Material
/// ikon adı — `waving_hand`, `numbers`...) VE `category` (mock ile aynı
/// sekiz aile) gönderiyor; ikisi de hiç kullanılmıyordu. `iconForLesson`
/// artık önce `icon_name`i, sonra `category`yi, en son mock slug
/// eşleşmesini dener.
void main() {
  test('2026-07-06_lesson_seed.sql\'deki 15 gerçek dersin TAMAMI yedek '
      'ikona düşmez', () {
    // seed dosyasındaki (slug, icon_name, category) üçlüleri birebir.
    const realSeedLessons = [
      ('silav-u-nasin', 'waving_hand', 'everyday'),
      ('hejmar', 'numbers', 'everyday'),
      ('cinavk', 'person', 'grammar'),
      ('lekera-bun', 'link', 'grammar'),
      ('newroz', 'local_fire_department', 'culture'),
      ('dengbeji', 'music_note', 'culture'),
      ('xwarinen-kurdi', 'restaurant', 'food'),
      ('feki-u-sebze', 'eco', 'food'),
      ('ajalen-male', 'pets', 'animals'),
      ('ajalen-kovi', 'forest', 'animals'),
      ('ciya-u-cem', 'landscape', 'geography'),
      ('cih-u-war', 'map', 'geography'),
      ('hesten-bingehin', 'favorite', 'emotions'),
      ('rojen-hefteye', 'calendar_today', 'time'),
      ('demsal', 'wb_sunny', 'time'),
    ];

    for (final (slug, iconName, category) in realSeedLessons) {
      final lesson = Lesson(
        id: slug,
        slug: slug,
        titleKu: slug,
        category: category,
        iconName: iconName,
      );
      final icon = iconForLesson(lesson);
      expect(
        icon,
        isNot(AppIcons.graduationCap),
        reason:
            '"$slug" (icon_name=$iconName, category=$category) yedek '
            'ikona düştü — sunucunun gönderdiği alanlar kullanılmıyor',
      );
    }
  });

  test('icon_name eşleşmesi category eşleşmesinden önceliklidir', () {
    // İki ders aynı kategoride ama FARKLI icon_name taşıyorsa farklı
    // ikon almalı — yoksa "her ders için ayrı ikon" sözü tutmaz.
    const lessonA = Lesson(
      id: 'a',
      slug: 'silav-u-nasin',
      titleKu: 'a',
      category: 'everyday',
      iconName: 'waving_hand',
    );
    const lessonB = Lesson(
      id: 'b',
      slug: 'hejmar',
      titleKu: 'b',
      category: 'everyday',
      iconName: 'numbers',
    );
    expect(iconForLesson(lessonA), isNot(iconForLesson(lessonB)));
  });

  test('icon_name yoksa (mock) category ailesine düşer', () {
    const mockLesson = Lesson(
      id: 'everyday_1',
      slug: 'everyday_1',
      titleKu: 'x',
      category: 'everyday',
    );
    expect(iconForLesson(mockLesson), AppIcons.comment);
  });

  test('hiçbiri eşleşmezse mezuniyet külahına düşer — çökmez', () {
    const unknown = Lesson(
      id: 'z',
      slug: 'hiç-bilinmeyen-bir-slug',
      titleKu: 'z',
      category: 'hiç-bilinmeyen-kategori',
    );
    expect(iconForLesson(unknown), AppIcons.graduationCap);
  });
}
