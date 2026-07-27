import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  test(
    'öğrenme yolu kartları ikon çipi solid gradient kullanır, glow/boxShadow yok',
    () {
      final source = File(
        'lib/src/screens/learning_screen.dart',
      ).readAsStringSync();
      final lessonStart = source.indexOf('class _LessonCard');
      final detailStart = source.indexOf('class LessonDetailScreen');
      final lessonSource = source.substring(lessonStart, detailStart);
      // Solid gradient ikon çipi (tinted alpha yerine)
      expect(lessonSource, contains('AppTheme.playGreen, Color(0xFF16A34A)'));
      // İkon beyaz (gradient zemin üzerinde kontrast)
      expect(lessonSource, contains('color: Colors.white,'));
    },
  );

  // 2026-07-23 canlı UX denetimi: öğrenme modu butonları ("Dersler" vb.)
  // ekran okuyucuda çift okunuyordu — dıştaki Semantics(label:) ile
  // içteki Text(label) birleşiyordu (M28 devamı).
  testWidgets('öğrenme modu butonu ekran okuyucuda çift okunmaz', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Dersler'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('kimlik bandı playGreen ScreenIdentityHeader olur', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<ScreenIdentityHeader>(
      find.byType(ScreenIdentityHeader),
    );
    expect(header.accent, AppTheme.playGreen);
    expect(find.text('Öğren'), findsOneWidget);
    expect(find.text('Bugünkü hedefin'), findsOneWidget);
    expect(find.text('Öğrenme yolları'), findsOneWidget);
    expect(find.byKey(const ValueKey('learning-next-step')), findsOneWidget);
    // 2026-07-27: rozette iki etiket yan yana duruyor ve tek cümle gibi
    // okunuyordu ("Sana önerilen Devam et"). Rozet artık yalnız tavsiyeyi
    // söyler; "devam et" kartın kendisi ve ucundaki oktur.
    expect(find.text('Sana önerilen'), findsOneWidget);
  });

  testWidgets('seçili sekme düz playGreen dolgu taşır', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final tab = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('learning-tab-everyday')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final decoration = tab.decoration as BoxDecoration;
    expect(decoration.color, AppTheme.playGreen);
    expect(decoration.gradient, isNull);
  });

  testWidgets('dersler mock repodan listelenir', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    // Arayüz Türkçe: ders adı da Türkçe listelenir. Kurmancî adı
    // ("Silavkirin") yalnız Kurmancî arayüzde görünür — bkz.
    // `test/lesson_title_language_test.dart` (2026-07-27).
    expect(find.text('Selamlaşma'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('learning-path-node-everyday_1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('learning-path-node-everyday_2')),
      findsOneWidget,
    );
    final lessonsList = find.byType(ListView).last;
    for (
      var i = 0;
      i < 5 &&
          find
              .byKey(const ValueKey('learning-mastery-goal'))
              .evaluate()
              .isEmpty;
      i++
    ) {
      await tester.drag(lessonsList, const Offset(0, -400));
      await tester.pump();
    }
    expect(find.byKey(const ValueKey('learning-mastery-goal')), findsOneWidget);
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('seviye kaydı varsa önerilen başlangıç rozeti gösterilir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.placement.v1.level': 'pesketi',
    });
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    // Önerilen düğüm işaretlenir (kilit/tamamlanma değişmeden).
    expect(
      find.byKey(const ValueKey('lesson-recommended-badge')),
      findsOneWidget,
    );
  });

  testWidgets('seviye kaydı yoksa önerilen rozet ilk düğümde olur', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
    // Destpêk/kayıt yok → ilk düğüm önerilir; rozet yine tek olur.
    expect(
      find.byKey(const ValueKey('lesson-recommended-badge')),
      findsOneWidget,
    );
  });
}
