/// Ders slaydında Türkçe açıklama yalnız Türkçe arayüzde görünür.
///
/// ## Kusur
///
/// `LessonSlide.contentTr` (sunucuda `content_tr`) her iki arayüz dilinde
/// Kurmancî metnin altına yazılıyordu: Kurmancî arayüzde okuyan, kendi
/// dilindeki bir kartın altında Türkçe düz yazı görüyordu (2026-10-16).
///
/// ## Niçin sessizdi
///
/// Alan veri olarak doğruydu ve Türkçe modda gerekliydi; testler yalnız Türkçe
/// modu (`wrap`) kuruyordu. `content_ku` içine gömülü Türkçe sözcük
/// karşılıkları ("roj: güneş") ayrı bir alan değildir ve burada AYRILMAZ:
/// biçim serbesttir (`—`, `:`, parantez, düz cümle) ve içerik yeniden
/// yazılmaz.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

const _lesson = Lesson(
  id: 'gloss-lesson',
  slug: 'gloss-lesson',
  titleKu: 'Ders',
  titleTr: 'Ders',
  category: 'everyday',
);

const _turkish = 'Bu cümle yalnız Türkçe arayüzde görünür.';

class _Repository extends MockZanKurdRepository {
  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async => const [
    LessonSlide(
      id: 's1',
      lessonId: 'gloss-lesson',
      order: 1,
      contentKu: 'Silav û rêz.',
      contentTr: _turkish,
    ),
  ];
}

Widget _app(String lang) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang(lang)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: LessonDetailScreen(lesson: _lesson, repository: _Repository()),
  ),
);

void main() {
  testWidgets('Türkçe arayüzde Türkçe açıklama görünür', (tester) async {
    await tester.pumpWidget(_app('tr'));
    await tester.pumpAndSettle();
    expect(find.text(_turkish), findsOneWidget);
  });

  testWidgets('Kurmancî arayüzde Türkçe açıklama görünmez', (tester) async {
    await tester.pumpWidget(_app('ku'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Silav'), findsWidgets);
    expect(find.text(_turkish), findsNothing);
  });
}
