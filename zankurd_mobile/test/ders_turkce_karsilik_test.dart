import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/widgets/lesson_vocab_tiles.dart';
import 'package:zankurd_mobile/src/widgets/lexicon_lookup.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Başlangıç dersinde Kurmancî açıklamanın Türkçesi, açıklama cümlesinin
/// HEMEN altında (Opus–Astra kapışması U20, 2026-10-29).
///
/// Kusur: `content_tr` kartın sonunda, kelime kartlarının ve harf
/// karolarının ALTINDA çiziliyordu; yeni başlayan hangi Kurmancî cümlenin ne
/// dediğini eşleyemiyordu (kare 227_beginner_lesson_alphabet). Metin
/// ekranda olduğu için hiçbir test "nerede" diye sormadı.
void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const ku =
      'Alfabeya Kurmancî (Hawar) 31 tîp e:\n\n'
      'A B C Ç D E Ê F G H I Î J K L M N O P Q R S Ş T U Û V W X Y Z\n\n'
      '• Elîfbê: Alfabe\n• Tîp: Harf';
  const tr = 'Kurmancî (Hawar) alfabesi 31 harftir.';

  Widget host(Widget child, {String lang = 'tr', double scale = 1.0}) =>
      testShell(
        languageProvider: lang == 'tr' ? turkishLang() : kurmanciLang(),
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: Scaffold(body: SingleChildScrollView(child: child)),
          ),
        ),
      );

  testWidgets('karşılık ilk açıklamanın hemen altında, kartlardan önce', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const LessonContentBlocks(text: ku, translation: tr)),
    );
    await tester.pumpAndSettle();
    final first = tester.getRect(find.byType(LexiconText).first);
    final trRect = tester.getRect(find.text(tr));
    final tiles = tester.getRect(
      find.byKey(const ValueKey('lesson-vocab-tiles')),
    );
    expect(trRect.top - first.bottom, inInclusiveRange(0, 8));
    expect(trRect.bottom, lessThan(tiles.top));
  });

  testWidgets('paragraf sayısı blok sayısına eşitse her biri kendi altında', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const LessonContentBlocks(
          text: 'Birinci hevok.\n\n• A: B\n\nDuyemîn hevok.',
          translation: 'Birinci cümle.\n\nİkinci cümle.',
        ),
      ),
    );
    await tester.pumpAndSettle();
    final k1 = tester.getRect(find.byType(LexiconText).at(0));
    final t1 = tester.getRect(find.text('Birinci cümle.'));
    final k2 = tester.getRect(find.byType(LexiconText).at(1));
    final t2 = tester.getRect(find.text('İkinci cümle.'));
    expect(t1.top - k1.bottom, inInclusiveRange(0, 8));
    expect(t2.top - k2.bottom, inInclusiveRange(0, 8));
  });

  testWidgets('Kurmancî arayüzde karşılık yok; Kurmancî örnek korunur', (
    tester,
  ) async {
    final repo = freshMockRepository();
    const lesson = Lesson(
      id: 'alphabet_1',
      slug: 'alphabet_1',
      titleKu: 'Alfabe',
      category: 'alphabet',
    );
    await tester.pumpWidget(
      testShell(
        languageProvider: kurmanciLang(),
        child: LessonDetailScreen(lesson: lesson, repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lesson-content-tr')), findsNothing);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('375×667 ders slaytı TR: taşma yok, karşılık var (x$scale)', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 667);
      addTearDown(tester.view.reset);
      final repo = freshMockRepository();
      const lesson = Lesson(
        id: 'alphabet_1',
        slug: 'alphabet_1',
        titleKu: 'Alfabe',
        category: 'alphabet',
      );
      await tester.pumpWidget(
        testShell(
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: LessonDetailScreen(lesson: lesson, repository: repo),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('lesson-content-tr')), findsWidgets);
    });
  }
}
