import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

Widget wrapKu(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('ku')),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

class _RetryableSlidesRepository extends MockZanKurdRepository {
  bool fail = true;
  int loadCalls = 0;

  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async {
    loadCalls += 1;
    if (fail) throw StateError('slides unavailable');
    return const [];
  }
}

/// Hiçbir kategoride ders döndürmeyen depo — "kategori boş" durumunu
/// taklit eder.
class _NoLessonsRepository extends MockZanKurdRepository {
  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async => const [];
}

const _testLesson = Lesson(
  id: 'lesson-test',
  slug: 'lesson-test',
  titleKu: 'Ders',
  titleTr: 'Ders',
  category: 'everyday',
);

final _placementLessons = List<Lesson>.generate(
  6,
  (index) => Lesson(
    id: 'placement-$index',
    slug: 'placement-$index',
    titleKu: 'Ders ${index + 1}',
    titleTr: 'Ders ${index + 1}',
    category: 'everyday',
    order: index + 1,
  ),
);

class _PlacementRepository extends MockZanKurdRepository {
  _PlacementRepository(this.completedIds);

  final Set<String> completedIds;

  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async {
    return _placementLessons;
  }

  @override
  Future<Set<String>> loadCompletedLessonIds() async {
    return Set.of(completedIds);
  }
}

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
    // 2026-07-30: burada AppBar başlığı olan 'Öğren' aranıyordu. Kimlik
    // bandı 'Kurmancî öğren' derken AppBar da 'Öğren' diyordu; iki yakın
    // anlamlı başlık üst üste biniyordu. Kimlik bandı kullanan on ekranın
    // sekizi AppBar başlığını boş bırakıyor — aykırı olan buydu.
    expect(header.title, 'Kurmancî öğren');
    expect(find.text('Öğren'), findsNothing);
    expect(find.text('Bugünkü hedefin'), findsOneWidget);
    expect(find.text('Öğrenme yolları'), findsOneWidget);
    expect(find.byKey(const ValueKey('learning-next-step')), findsOneWidget);
    // 2026-07-27: rozette iki etiket yan yana duruyor ve tek cümle gibi
    // okunuyordu ("Sana önerilen Devam et"). Rozet artık yalnız tavsiyeyi
    // söyler; "devam et" kartın kendisi ve ucundaki oktur.
    expect(find.text('Sana önerilen'), findsOneWidget);
  });

  testWidgets(
    'önerilen ders Today\'s Review\'dan sonra Story ve modlardan önce gelir',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PlacementStore.resetInstance();
      addTearDown(PlacementStore.resetInstance);
      final semantics = tester.ensureSemantics();

      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrap(LearningScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      final nextStep = find.byKey(const ValueKey('learning-next-step'));
      final story = find.byKey(const ValueKey('learning-story-entry'));
      final practice = find.text('Soru çöz');

      expect(nextStep, findsOneWidget);
      expect(story, findsOneWidget);
      expect(practice, findsOneWidget);
      expect(
        tester.getTopLeft(nextStep).dy,
        lessThan(tester.getTopLeft(story).dy),
      );
      expect(
        tester.getTopLeft(nextStep).dy,
        lessThan(tester.getTopLeft(practice).dy),
      );

      final semanticsData = tester.getSemantics(nextStep).getSemanticsData();
      expect(semanticsData.hasAction(ui.SemanticsAction.tap), isTrue);
      expect(semanticsData.label, contains('Sana önerilen'));
      expect(semanticsData.label, contains('Selamlaşma'));
      semantics.dispose();

      await tester.tap(nextStep);
      await tester.pumpAndSettle();
      expect(find.byType(LessonDetailScreen), findsOneWidget);
    },
  );

  testWidgets(
    'Navîn placement top öneriyi ve sakin seviye bağlamını gösterir',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'zankurd.placement.v1.level': 'navin',
      });
      PlacementStore.resetInstance();
      addTearDown(PlacementStore.resetInstance);

      await tester.pumpWidget(
        wrap(LearningScreen(repository: _PlacementRepository(const {}))),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('learning-next-step')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('learning-next-step')),
          matching: find.text('Ders 2'),
        ),
        findsOneWidget,
      );
      expect(find.text('Mevcut seviyen: Orta'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('lesson-recommended-badge')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('learning-path-node-placement-1')),
          matching: find.byKey(const ValueKey('lesson-recommended-badge')),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('gerçek ilerlemede top öneri placement bağlamını kaldırır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.placement.v1.level': 'navin',
    });
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.pumpWidget(
      wrap(
        LearningScreen(
          repository: _PlacementRepository({'placement-0', 'placement-1'}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('learning-next-step')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-next-step')),
        matching: find.text('Ders 3'),
      ),
      findsOneWidget,
    );
    expect(find.text('Mevcut seviyen: Orta'), findsNothing);
    expect(find.text('Sana önerilen'), findsOneWidget);
  });

  // Bu test AppBar başlığının yazı tipini ölçüyordu; başlık kaldırılınca
  // hedefsiz kaldı. Niyeti hâlâ geçerli — bir ekranda iki ayrı yazı tipi
  // görünmemeli (bkz. 2026-07-26: boyayıcı metinler sistem yazı tipine
  // düşüyordu). Ölçüm ekranın adını taşıyan yere, kimlik bandına taşındı.
  testWidgets('öğrenme başlığı ürünün yazı tipini korur', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    // Aile başlığın kendi stilinde yazılı değil; temadan gelir. Eski test
    // AppBar'ın `titleTextStyle` içine **açıkça** yazdığı aileyi ölçüyordu,
    // o başlık kalkınca ölçtüğü şey de kalmadı. Burada asıl mekanizma
    // ölçülür: tema Rubik'i besler ve başlık stili onu geçersiz kılmaz.
    final context = tester.element(find.text('Kurmancî öğren'));
    expect(
      Theme.of(context).textTheme.bodyMedium?.fontFamily,
      AppTypography.fontFamily,
    );
    expect(
      AppTypography.heading2.fontFamily,
      isNull,
      reason: 'Başlık stili aileyi yazarsa tema değişimi ona ulaşmaz.',
    );
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
    expect(find.text('Selamlaşma'), findsNWidgets(2));
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

  testWidgets('seviye kaydı varsa önerilen ilk düğümde SIKIŞMAZ', (
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

    // 2026-08-14 düzeltmesinden önce öneri HER ZAMAN ilk düğüme
    // geriliyordu (kilitli bir düğüme düşmemek için) — yerleştirme
    // sınavının öğrenme yolunda görünür hiçbir etkisi yoktu.
    // `learningRecommendedIndex` bu ekranın kullandığı GERÇEK
    // fonksiyondur (bkz. test/learning_recommended_index_test.dart);
    // burada yalnız ekranın onu gerçekten çağırdığını ve ilk düğümün
    // artık koşulsuz "önerilen" olmadığını doğrularız — kaydırmaya
    // bağımlı olmayan, ilk kareden görünür bir kanıt.
    final firstNode = find.byKey(
      const ValueKey('learning-path-node-everyday_1'),
    );
    expect(firstNode, findsOneWidget);
    expect(
      find.descendant(
        of: firstNode,
        matching: find.byKey(const ValueKey('lesson-recommended-badge')),
      ),
      findsNothing,
      reason:
          'placementIndex ilk düğümden ileri (everyday_2) olmalı; rozet '
          'yine ilk düğümde kalırsa yerleştirme hiçbir şeyi değiştirmiyor '
          'demektir',
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

  testWidgets('slayt hatası görünür ve retry yeni repository çağrısı yapar', (
    tester,
  ) async {
    final repository = _RetryableSlidesRepository();
    await tester.pumpWidget(
      wrap(LessonDetailScreen(lesson: _testLesson, repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('app-error-state')), findsOneWidget);
    expect(find.text('Tekrar'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Tekrar'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
    expect(find.byKey(const ValueKey('app-empty-state')), findsOneWidget);
    expect(find.text('Slayt yok'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uzun mini quiz etiketi dar ekranda tek satırda kalır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapKu(
        LessonDetailScreen(
          lesson: const Lesson(
            id: 'everyday_1',
            slug: 'everyday-1',
            titleKu: 'Ders',
            titleTr: 'Ders',
            category: 'everyday',
          ),
          repository: MockZanKurdRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pêş'));
    await tester.pumpAndSettle();

    final miniQuizLabel = tester.widget<Text>(find.text('Quiz-a Kurt'));
    expect(miniQuizLabel.maxLines, 1);
    expect(miniQuizLabel.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'kategoride ders yokken "Dersler" düğmesi kapalı görünür ve dokunuşta '
    'hiçbir şey yapmaz',
    (tester) async {
      // 2026-08-14 denetimi: `enabled: true` sabitti — diğer iki düğme
      // (Soru Çöz/Flaş Kart) `hasLesson`e bakarken bu hep AÇIK
      // görünüyordu. Dokununca `_openCategoryFlashcards`in erken dönüşü
      // yüzünden sessizce hiçbir şey olmuyordu.
      await tester.pumpWidget(
        wrap(LearningScreen(repository: _NoLessonsRepository())),
      );
      await tester.pumpAndSettle();

      final lessonsButton = find.ancestor(
        of: find.text('Dersler'),
        matching: find.byType(Semantics),
      );
      final semantics = tester
          .widgetList<Semantics>(lessonsButton)
          .firstWhere((s) => s.properties.button == true);
      expect(
        semantics.properties.enabled,
        isFalse,
        reason: 'ders yokken düğme erişilebilirlik ağacında da kapalı olmalı',
      );

      await tester.tap(find.text('Dersler'));
      await tester.pumpAndSettle();

      // Kapalı düğmeye dokunmak hiçbir sayfa açmamalı — hâlâ öğrenme
      // ekranındayız.
      expect(find.byType(LearningScreen), findsOneWidget);
    },
  );

  testWidgets(
    'öğrenme yolu kilim baklava düğümleri ve tamamlananlar için altın dolgu kullanır',
    (tester) async {
      // 4.3 Görsel Kimlik: Ders yolu Duolingo yerine kilim baklava motifleriyle
      // ve tamamlanan dersler altın düğümle çizilir.
      tester.view.physicalSize = const Size(480, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final mockRepo = MockZanKurdRepository();
      await tester.pumpWidget(wrap(LearningScreen(repository: mockRepo)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('learning-path-node-everyday_1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('learning-path-node-everyday_2')),
        findsOneWidget,
      );

      // Baklava kilit düğümü ikonlarının mevcut olduğu kontrolü
      expect(find.byIcon(AppIcons.lock), findsWidgets);
    },
  );
}
