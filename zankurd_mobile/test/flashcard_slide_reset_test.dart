import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Flashcard slayt değişince ön yüzle açılır.
///
/// ## Kusur
///
/// İleri/Geri yalnız `_currentSlideIndex`'i değiştiriyordu; çevrilmiş kartın
/// `_isFlipped` ve denetleyici değeri yalnız mod düğmesinde sıfırlanıyordu.
/// Kullanıcı bir kartın cevabına bakıp ilerleyince sonraki kart CEVAP yüzü
/// açık geliyordu: soruyu görmeden cevabı okuyor, kendini sınayamıyordu.
///
/// ## Niçin sessizdi
///
/// Hata vermez, taşma olmaz; her kart çizilir ve çevrilir. Yalnız hangi yüzle
/// açıldığına bakan bir test yoktu.
class _TwoSlides extends MockZanKurdRepository {
  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async => [
    for (var i = 1; i <= 2; i++)
      LessonSlide(
        id: 's$i',
        lessonId: lessonId,
        order: i,
        contentKu: 'Naverok $i',
        contentTr: 'Icerik $i',
      ),
  ];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('sonraki ve önceki kart ön yüzle açılır', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('ku'),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: LessonDetailScreen(
            lesson: const Lesson(
              id: 'everyday_1',
              slug: 'everyday-1',
              titleKu: 'Ders',
              titleTr: 'Ders',
              category: 'everyday',
            ),
            repository: _TwoSlides(),
            initialFlashcardMode: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Naverok 1'));
    await tester.pumpAndSettle();
    expect(find.text('Icerik 1'), findsOneWidget);

    await tester.tap(find.text('Pêş'));
    await tester.pumpAndSettle();
    expect(find.text('Naverok 2'), findsOneWidget);
    expect(find.text('Icerik 2'), findsNothing);

    await tester.tap(find.text('Naverok 2'));
    await tester.pumpAndSettle();
    expect(find.text('Icerik 2'), findsOneWidget);

    await tester.tap(find.text('Paş'));
    await tester.pumpAndSettle();
    expect(find.text('Naverok 1'), findsOneWidget);
    expect(find.text('Icerik 1'), findsNothing);
  });
}
