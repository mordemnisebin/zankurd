// 2026-09-29 doğallık (K5, K7): ders yolunda elmas düğüm ve ikon karosu yok.
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/lesson.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/services/lesson_listening_speaker.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
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

Widget wrapLargeText(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    builder: (context, appChild) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: const TextScaler.linear(2)),
      child: appChild!,
    ),
    home: child,
  ),
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

class _SourceLessLessonRepository extends MockZanKurdRepository {
  @override
  Future<List<LessonSlide>> loadLessonSlides(String lessonId) async => const [
    LessonSlide(
      id: 'source-less-slide',
      lessonId: 'source-less',
      order: 1,
      contentKu: 'Naveroka dersê ya ceribandinê.',
      contentTr: 'Kaynak eşlemesi olmayan test dersi.',
    ),
  ];
}

/// Hiçbir kategoride ders döndürmeyen depo — "kategori boş" durumunu
/// taklit eder.
class _NoLessonsRepository extends MockZanKurdRepository {
  @override
  Future<List<Lesson>> loadLessonsByCategory(String category) async => const [];
}

enum _PracticeFailure { none, empty, error }

class _RetryablePracticeRepository extends MockZanKurdRepository {
  _PracticeFailure failure = _PracticeFailure.none;
  int loadCalls = 0;

  @override
  Future<List<QuizQuestion>> loadLevelQuestions({
    required String category,
    required int difficultyMin,
    required int difficultyMax,
    String? subCategory,
    int limit = 10,
  }) async {
    loadCalls += 1;
    switch (failure) {
      case _PracticeFailure.empty:
        return const [];
      case _PracticeFailure.error:
        throw StateError('practice unavailable');
      case _PracticeFailure.none:
        return super.loadLevelQuestions(
          category: category,
          difficultyMin: difficultyMin,
          difficultyMax: difficultyMax,
          subCategory: subCategory,
          limit: limit,
        );
    }
  }
}

class _LessonQuizProbeRepository extends MockZanKurdRepository {
  String? requestedCategory;
  String? requestedLessonId;

  @override
  Future<List<QuizQuestion>> loadLearningQuizQuestions({
    required String category,
    required String learningLessonId,
    int limit = 5,
  }) async {
    requestedCategory = category;
    requestedLessonId = learningLessonId;
    return const [];
  }
}

class _FakeLessonListeningSpeaker implements LessonListeningSpeaker {
  _FakeLessonListeningSpeaker({this.available = true});

  @override
  final bool available;

  @override
  final ValueNotifier<bool> speakingListenable = ValueNotifier(false);

  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    speakingListenable.value = false;
  }
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
  testWidgets('öğrenme yolu kart değil doğrudan rota durakları kullanır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final firstNode = find.byKey(
      const ValueKey('learning-path-node-everyday_1'),
    );
    expect(firstNode, findsOneWidget);
    expect(
      find.descendant(of: firstNode, matching: find.byType(AppPanel)),
      findsNothing,
      reason: 'Rêya Zanînê üzerindeki dersler ayrı kartlar olmamalı.',
    );
    expect(
      find.byKey(const ValueKey('learning-route-stop-everyday_1')),
      findsOneWidget,
    );
  });

  // 2026-07-23 canlı UX denetimi: öğrenme modu butonları ekran okuyucuda
  // çift okunuyordu (M28 devamı). 2026-09-27: üç simgeli şerit, derslerin
  // altında adıyla duran iki düğmeye ("Soru çöz", "Kelime kartları") dönüştü;
  // "Dersler" yolun kendisini tekrar ettiği için kalktı. Bekçi aynı:
  // her eylem ekran okuyucuda bir kez, dokunulabilir olarak duyurulur.
  testWidgets('konu eylemleri ekran okuyucuda çift okunmaz', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('learning-topic-actions')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('learning-mode-strip')), findsNothing);
    expect(find.bySemanticsLabel('Dersler'), findsNothing);
    for (final label in ['Soru çöz', 'Kelime kartları']) {
      final action = find.bySemanticsLabel(label);
      expect(action, findsOneWidget, reason: label);
      expect(
        tester
            .getSemantics(action)
            .getSemanticsData()
            .hasAction(ui.SemanticsAction.tap),
        isTrue,
        reason: label,
      );
    }
    handle.dispose();
  });

  testWidgets(
    'kategori sekmesi 48dp dokunma hedefi ve seçili semantiği taşır',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        wrap(LearningScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      // 2026-09-29 Şahnê: çip görselde 44 (`SahneRailChip`), dokunma
      // alanı 48'lik saydam kutu; ölçülen şey dokunma kutusudur (anahtar
      // onda), görsel çipin kendi InkWell'i değil.
      final tab = find.byKey(const ValueKey('learning-tab-everyday'));
      expect(tester.getSize(tab).height, greaterThanOrEqualTo(48));
      final data = tester.getSemantics(tab).getSemanticsData();
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.flagsCollection.isSelected, ui.Tristate.isTrue);
      expect(data.label, 'Günlük');
      expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
      semantics.dispose();
    },
  );

  // 2026-09-29 Şahnê: B iskeleti. Sayfa adı ve alt satırı çubukta durur;
  // içerikte başlık kartı (eski orman gradyanlı kimlik kartı) ve ayrı
  // "Öğrenme yolları" bölüm başlığı yoktur — maket: çubuk → konu rayı →
  // yol. Bekçi aynı kuralı korur: ad bir kez yazılır, ortak
  // `ScreenIdentityHeader` kullanılmaz.
  testWidgets(
    'öğrenme sayfası adını B çubuğunda bir kez taşır, başlık kartı yok',
    (tester) async {
      await tester.pumpWidget(
        wrap(LearningScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ScreenIdentityHeader), findsNothing);
      expect(find.byKey(const ValueKey('learning-scene-header')), findsNothing);
      expect(find.text('Kurmancî öğren'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Kurmancî öğren'),
        ),
        findsOneWidget,
      );
      // 2026-09-29 doğallık: çubuğun alt satırı ("Ders ders, konu konu
      // ilerle") kaldırıldı; çubuk yalnız sayfanın adını taşır.
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Ders ders, konu konu ilerle'),
        ),
        findsNothing,
      );
      expect(find.text('Öğren'), findsNothing);
      // "Bugünkü hedefin" bölümü 2026-09-27'de kalktı: hiç ders çözmemiş
      // birine "Tekrarlar tamam" diyordu. Tekrar kartı artık yalnız vadesi
      // gelmiş tekrar varken, ekranın en üstünde çizilir.
      expect(find.text('Bugünkü hedefin'), findsNothing);
      expect(find.byKey(const ValueKey('todays-review-empty')), findsNothing);
      expect(find.text('Öğrenme yolları'), findsNothing);
      expect(find.byKey(const ValueKey('learning-next-step')), findsOneWidget);
      // Rozet Etiket biçemindedir: yerele duyarlı büyük harf.
      // 2026-09-29 doğallık: rozet artık cümle düzeninde (K8, `SahneBadge` captionStrong); bu bekçi eskiden büyük harfi bekliyordu.
      expect(find.text('Sıradaki ders'), findsOneWidget);
    },
  );

  for (final isKu in [false, true]) {
    for (final dark in [false, true]) {
      testWidgets('ilk ders kaydırmadan açılır ku=$isKu dark=$dark', (
        tester,
      ) async {
        SharedPreferences.setMockInitialValues({});
        PlacementStore.resetInstance();
        addTearDown(PlacementStore.resetInstance);
        await tester.binding.setSurfaceSize(const Size(360, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              home: LearningScreen(repository: MockZanKurdRepository()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final nextStep = find.byKey(const ValueKey('learning-next-step'));
        expect(tester.getRect(nextStep).bottom, lessThanOrEqualTo(740));
        expect(nextStep.hitTestable(), findsOneWidget);
        await tester.tap(nextStep);
        await tester.pumpAndSettle();
        expect(find.byType(LessonDetailScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('önerilen rota düğümü erişilebilir ve ders detayını açar', (
    tester,
  ) async {
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

    expect(nextStep, findsOneWidget);
    expect(find.byKey(const ValueKey('story-catalog')), findsOneWidget);

    final semanticsData = tester.getSemantics(nextStep).getSemanticsData();
    expect(semanticsData.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(semanticsData.label, contains('Sıradaki ders'));
    expect(semanticsData.label, contains('Selamlaşma'));
    semantics.dispose();

    await tester.ensureVisible(nextStep);
    await tester.pumpAndSettle();
    await tester.tap(nextStep);
    await tester.pumpAndSettle();
    expect(find.byType(LessonDetailScreen), findsOneWidget);
  });

  // 2026-09-29 Şahnê: etkin ders artık turuncu dolu bir satır değil, gece
  // sahne kartıdır (`SahneStageCard.lesson`); Agir (turuncu) yalnız kartın
  // içindeki TEK birincil düğmededir ve üstündeki metin koyu `onAct`tır.
  // Ekranda başka Agir dolgu yoktur.
  testWidgets('önerilen ders sahne kartında tek birincil Agir düğme taşır', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final nextStep = find.byKey(const ValueKey('learning-next-step'));
    expect(
      find.descendant(of: nextStep, matching: find.byType(SahneStageCard)),
      findsOneWidget,
    );
    final title = tester.widget<Text>(
      find.descendant(of: nextStep, matching: find.text('Selamlaşma')),
    );
    // Sahne kartı gündüz temasında da gece çizilir.
    expect(title.style?.color, SahneTokens.night.tx);

    final primary = find.descendant(
      of: nextStep,
      matching: find.byType(FilledButton),
    );
    expect(primary, findsOneWidget);
    final fill = tester.widget<Material>(
      find.descendant(of: primary, matching: find.byType(Material)).first,
    );
    expect(fill.color, SahneTokens.night.act);
    final label = tester.widget<RichText>(
      find.descendant(of: primary, matching: find.byType(RichText)).first,
    );
    expect(label.text.style?.color, SahneTokens.night.onAct);

    // Tek birincil: yoldaki kartın dışında Agir dolgulu düğme yok.
    final agirButtons = tester
        .widgetList<Material>(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(Material),
          ),
        )
        .where((m) => m.color == SahneTokens.day.act);
    expect(agirButtons.length, 1);
  });

  testWidgets('öğrenme yolu durumları Türkçe semantics ile adlandırılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);
    final semantics = tester.ensureSemantics();

    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrap(LearningScreen(repository: _PlacementRepository({'placement-0'}))),
    );
    await tester.pumpAndSettle();

    final completed = tester.getSemantics(
      find.bySemanticsLabel('Ders 1. Ders tamamlandı'),
    );
    final current = tester.getSemantics(
      find.bySemanticsLabel('Sıradaki ders. Ders 2. Sonraki'),
    );
    final locked = tester.getSemantics(
      find.bySemanticsLabel('Ders 3. Kilitli'),
    );

    expect(completed.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      completed.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    expect(current.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(
      current.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isTrue,
    );
    expect(locked.getSemanticsData().flagsCollection.isButton, isFalse);
    expect(
      locked.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets('öğrenme yolu durumları Kurmancî semantics ile adlandırılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);
    final semantics = tester.ensureSemantics();

    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      wrapKu(LearningScreen(repository: _PlacementRepository({'placement-0'}))),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.bySemanticsLabel('Ders 1. Ders qediya')),
      isNotNull,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('Dersa din. Ders 2. Ya din')),
      isNotNull,
    );
    final locked = tester.getSemantics(find.bySemanticsLabel('Ders 3. Girtî'));
    expect(locked.getSemanticsData().flagsCollection.isButton, isFalse);
    expect(
      locked.getSemanticsData().hasAction(ui.SemanticsAction.tap),
      isFalse,
    );
    semantics.dispose();
  });

  testWidgets(
    'Navîn placement öneriyi rota düğümüne ve seviye bağlamına taşır',
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
        findsOneWidget,
      );
    },
  );

  testWidgets('gerçek ilerlemede rota önerisi placement bağlamını kaldırır', (
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
    expect(find.text('Sıradaki ders'), findsOneWidget);
  });

  // Niyet: bir ekranda sistem yazı tipine düşen metin olmamalı (bkz.
  // 2026-07-26: boyayıcı metinler sistem yazı tipine düşüyordu).
  // 2026-09-29 Şahnê: yazı iki ailedir — başlıklar Bricolage Grotesque
  // (`SahneType.display`), metin Onest (`SahneType.text`). Eski bekçi
  // Rubik'i ve "başlık stili aileyi yazmaz" kuralını ölçüyordu; Şahnê'de
  // aile belirteçte yazılıdır. Ölçülen: çubuktaki sayfa adı başlık
  // ailesiyle, gövde metni metin ailesiyle çizilir.
  testWidgets('öğrenme başlığı ürünün yazı tipini korur', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final title = tester.element(find.text('Kurmancî öğren'));
    expect(DefaultTextStyle.of(title).style.fontFamily, SahneType.display);
    expect(Theme.of(title).textTheme.bodyMedium?.fontFamily, SahneType.text);
  });

  // 2026-09-27: seçili sekme soluk bir zemindi, sahip ekranı renksiz buldu.
  // 2026-09-29 Şahnê: konu rayı `SahneRail` + `SahneRailChip`; seçili çip
  // öğrenme rolünü taşır (Zimrût tonu + Halka 2 + Zimrût metni), seçili
  // olmayan ikincil metinde kalır. Kontrast ölçümü
  // learning_color_identity_test.dart'ta.
  testWidgets('seçili konu çipi öğrenme rolünü taşır, ötekiler taşımaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    SahneRailChip chip(String key) => tester.widget<SahneRailChip>(
      find.descendant(
        of: find.byKey(ValueKey(key)),
        matching: find.byType(SahneRailChip),
      ),
    );
    expect(chip('learning-tab-everyday').selected, isTrue);
    expect(chip('learning-tab-everyday').role, SahneRole.learn);
    expect(chip('learning-tab-grammar').selected, isFalse);

    final label = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('learning-tab-everyday')),
        matching: find.text('Günlük'),
      ),
    );
    expect(label.style?.color, SahneTokens.day.learnTx);
    final other = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('learning-tab-grammar')),
        matching: find.text('Dilbilgisi'),
      ),
    );
    expect(other.style?.color, SahneTokens.day.tx2);
  });

  testWidgets('önerilen ders rota içinde tek kez görünür', (tester) async {
    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    // Arayüz Türkçe: ders adı da Türkçe listelenir. Kurmancî adı
    // ("Silavkirin") yalnız Kurmancî arayüzde görünür — bkz.
    // `test/lesson_title_language_test.dart` (2026-07-27).
    // Önerilen ders ayrı bir üst kart olarak tekrarlanmaz; rota üzerindeki
    // aktif durak hem dersin kendisini hem öneri işaretini taşır.
    expect(find.text('Selamlaşma'), findsOneWidget);
    final firstNode = find.byKey(
      const ValueKey('learning-path-node-everyday_1'),
    );
    expect(
      find.descendant(
        of: firstNode,
        matching: find.byKey(const ValueKey('learning-next-step')),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: firstNode,
        matching: find.byKey(const ValueKey('lesson-recommended-badge')),
      ),
      findsOneWidget,
    );
    expect(firstNode, findsOneWidget);
    expect(
      find.byKey(const ValueKey('learning-path-node-everyday_2')),
      findsOneWidget,
    );
    // Yolun sonundaki "Konu ustalık hedefi" durağı 2026-09-27'de kalktı
    // (ne olduğu ekranda yazmıyordu). Yolun ardından konu eylemleri gelir.
    expect(find.byKey(const ValueKey('learning-mastery-goal')), findsNothing);
    final actions = find.byKey(const ValueKey('learning-topic-actions'));
    await tester.ensureVisible(actions);
    expect(
      tester.getTopLeft(actions).dy,
      greaterThan(tester.getTopLeft(firstNode).dy),
      reason: 'Konu eylemleri ders yolunun altında durmalı.',
    );
  });

  // Hikâyeler destekleyici içerik; ana öğrenme yolunu ilk ekrandan aşağı
  // itmemeli. 2026-09-27'de yana kayan şerit (ikinci hikâyeyi yarım
  // gösteriyordu) alt alta tam listeye döndü; bekçinin kuralı aynı kaldı:
  // yol önce gelir, hikâyeler ondan sonra.
  testWidgets('hikâyeler ders yolunu gömmez, yolun altında durur', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final nextStep = find.byKey(const ValueKey('learning-next-step'));
    final catalog = find.byKey(const ValueKey('story-catalog'));
    expect(nextStep, findsOneWidget);
    expect(catalog, findsOneWidget);
    expect(
      tester.getBottomLeft(nextStep).dy,
      lessThan(844),
      reason: 'Önerilen ders ilk ekranda görünmeli.',
    );
    expect(
      tester.getTopLeft(catalog).dy,
      greaterThan(tester.getBottomLeft(nextStep).dy),
    );
    // Dört hikâyenin hepsi tam görünür (yarım kart yok).
    for (final id in ['cayxane', 'xwe-nasandin', 'kirin', 'rê-pirsîn']) {
      expect(
        find.byKey(ValueKey('story-card-$id'), skipOffstage: false),
        findsOneWidget,
        reason: id,
      );
    }
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

  testWidgets('390×844 telefonda öğrenme üst bölümü overflow yapmaz', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('%200 yazıda önerilen birincil CTA taşmadan erişilebilir kalır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrapLargeText(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final nextStep = find.byKey(const ValueKey('learning-next-step'));
    expect(nextStep, findsOneWidget);
    await tester.ensureVisible(nextStep);
    await tester.pumpAndSettle();

    final rect = tester.getRect(nextStep);
    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(390));
    expect(rect.height, greaterThanOrEqualTo(48));
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

  testWidgets('Flaş kart doğrudan kart kipinde açılır', (tester) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final flashcards = find.text('Kelime kartları');
    await tester.ensureVisible(flashcards);
    await tester.tap(flashcards);
    await tester.pumpAndSettle();

    expect(find.byType(LessonDetailScreen), findsOneWidget);
    expect(find.text('Çeviri için dokun'), findsOneWidget);
  });

  testWidgets('Soru çöz boş havuzda görünür retry sunar', (tester) async {
    final repository = _RetryablePracticeRepository()
      ..failure = _PracticeFailure.empty;

    await tester.pumpWidget(wrap(LearningScreen(repository: repository)));
    await tester.pumpAndSettle();

    final practice = find.text('Soru çöz');
    await tester.ensureVisible(practice);
    await tester.tap(practice);
    await tester.pumpAndSettle();

    expect(find.text('Soru bulunamadı.'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(repository.loadCalls, 1);

    repository.failure = _PracticeFailure.none;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
  });

  testWidgets('Soru çöz yükleme hatasında görünür retry sunar', (tester) async {
    final repository = _RetryablePracticeRepository()
      ..failure = _PracticeFailure.error;

    await tester.pumpWidget(wrap(LearningScreen(repository: repository)));
    await tester.pumpAndSettle();

    final practice = find.text('Soru çöz');
    await tester.ensureVisible(practice);
    await tester.tap(practice);
    await tester.pumpAndSettle();

    expect(find.text('Quiz yüklenemedi'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
    expect(repository.loadCalls, 1);

    repository.failure = _PracticeFailure.none;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();

    expect(repository.loadCalls, 2);
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
    expect(find.text('Tekrar dene'), findsOneWidget);

    repository.fail = false;
    await tester.tap(find.text('Tekrar dene'));
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

    // 2026-09-29 Şahnê: "Kısa test" dar ekranda tam genişlik ikincil
    // düğmedir; etiket küçültülmeden (FittedBox yok) tek satıra sığar.
    // Ölçülen şey sonuçtur: çizilen etiket tek satır yüksekliğinde.
    final miniQuizLabel = find.text('Azmûna kurt');
    expect(miniQuizLabel, findsOneWidget);
    expect(
      tester.getSize(miniQuizLabel).height,
      lessThanOrEqualTo(SahneType.button.fontSize! * SahneType.button.height!),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ders mini quiz isteği açık lesson id ile repositoryye gider', (
    tester,
  ) async {
    final repository = _LessonQuizProbeRepository();
    const lesson = Lesson(
      id: 'everyday_3',
      slug: 'everyday-3',
      titleKu: 'Pratikên Rojane',
      titleTr: 'Günlük Pratik İfadeler',
      category: 'everyday',
    );

    await tester.pumpWidget(
      wrapKu(LessonDetailScreen(lesson: lesson, repository: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pêş'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azmûna kurt'));
    await tester.pumpAndSettle();

    expect(repository.requestedCategory, 'Ziman');
    expect(repository.requestedLessonId, 'everyday_3');
  });

  // 2026-08-14 denetimi: "Dersler" düğmesi `enabled: true` sabitti — ders
  // yokken açık görünüyor, dokununca sessizce hiçbir şey yapmıyordu.
  // 2026-09-27: "Dersler" kalktı; aynı kural kalan iki konu eylemine
  // uygulanır. Aynı tarihte düğmeler outlined'dan dolu `FilledButton`'a
  // geçti (renksiz bulunan ekran kimliği düzeltmesi) — bekçinin aradığı
  // widget tipi buna göre güncellendi, davranış (onPressed null → dokunuş
  // hiçbir şey yapmaz) aynı kaldı.
  testWidgets(
    'kategoride ders yokken konu eylemleri kapalıdır ve dokunuşta hiçbir '
    'şey yapmaz',
    (tester) async {
      await tester.pumpWidget(
        wrap(LearningScreen(repository: _NoLessonsRepository())),
      );
      await tester.pumpAndSettle();

      for (final key in [
        'learning-topic-practice',
        'learning-topic-flashcards',
      ]) {
        final button = find.descendant(
          of: find.byKey(ValueKey(key)),
          matching: find.byType(FilledButton),
        );
        expect(
          tester.widget<FilledButton>(button).onPressed,
          isNull,
          reason: '$key ders yokken kapalı olmalı',
        );
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button, warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(find.byType(LearningScreen), findsOneWidget, reason: key);
      }
    },
  );

  // 2026-09-27: kelime kartları her zaman konunun İLK dersini açıyordu;
  // ikinci derse gelmiş biri kartlarda hep "Selamlaşma"yı görüyordu.
  // Kusur sessizdi: kartlar açılıyordu, yalnız yanlış dersle. Aynı tarihte
  // düğme outlined'dan dolu `FilledButton`'a geçti; bekçi buna göre bulur.
  testWidgets('kelime kartları sıradaki dersi açar, ilk dersi değil', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    await repository.markLessonCompleted('everyday_1');
    await tester.pumpWidget(wrap(LearningScreen(repository: repository)));
    await tester.pumpAndSettle();

    final flashcards = find.descendant(
      of: find.byKey(const ValueKey('learning-topic-flashcards')),
      matching: find.byType(FilledButton),
    );
    await tester.ensureVisible(flashcards);
    await tester.pumpAndSettle();
    await tester.tap(flashcards);
    await tester.pumpAndSettle();

    final detail = tester.widget<LessonDetailScreen>(
      find.byType(LessonDetailScreen),
    );
    expect(detail.lesson.id, 'everyday_2');
    expect(detail.initialFlashcardMode, isTrue);
  });

  testWidgets('öğrenme yolu sade işaretleyicilerle kilit durumunu korur', (
    tester,
  ) async {
    // Yol artık oyun haritası/baklava motifleri yerine tek, sakin bir
    // ilerleme rayı kullanır; kilit davranışı görünür kalır.
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

    // Kilitli dersler yine açıkça işaretlenir.
    expect(find.byIcon(AppIcons.lock), findsWidgets);

    // 2026-09-29 doğallık (K5, K7): yolun elmas düğümleri ve her dersin
    // ikon karosu kalktı; kilitli ders tek işaret (kilit) taşır, öteki
    // dersler ikonsuz liste satırıdır.
    expect(find.byType(SahnePathNode), findsNothing);
    final locked = find.byKey(const ValueKey('learning-route-stop-everyday_2'));
    expect(
      find.descendant(of: locked, matching: find.byIcon(AppIcons.lock)),
      findsOneWidget,
    );
    expect(
      find.ancestor(of: locked, matching: find.byType(SahneListGroup)),
      findsOneWidget,
    );
  });

  testWidgets('öğrenme ekranından sözlük açılır ve iki dilde arama yapılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    addTearDown(PlacementStore.resetInstance);

    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      wrap(LearningScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final entry = find.byKey(const ValueKey('learning-lexicon-entry'));
    expect(entry, findsOneWidget);
    await tester.ensureVisible(entry);
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.text('Sözlük'), findsOneWidget);
    final search = find.byKey(const ValueKey('lexicon-search-field'));
    expect(search, findsOneWidget);

    await tester.enterText(search, 'av');
    await tester.pump();

    expect(find.byKey(const ValueKey('lexicon-entry-av')), findsOneWidget);
    expect(find.text('Av'), findsOneWidget);
    expect(find.text('Su'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lexicon-entry-av')),
        matching: find.text('Kaynak: Temel Yemekler'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('lexicon-entry-nan')), findsNothing);

    await tester.enterText(search, 'güney');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('lexicon-entry-basur')),
      findsOneWidget,
      reason: 'Türkçe anlam alanı da aranabilmeli.',
    );
    expect(find.text('Başûr'), findsOneWidget);
  });

  testWidgets(
    'sözlük Kurmancî başlıkla açılır ve arama büyük/küçük harfe duyarsızdır',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      PlacementStore.resetInstance();
      addTearDown(PlacementStore.resetInstance);

      await tester.pumpWidget(
        wrapKu(LearningScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();

      final entry = find.byKey(const ValueKey('learning-lexicon-entry'));
      expect(entry, findsOneWidget);
      await tester.ensureVisible(entry);
      await tester.tap(entry);
      await tester.pumpAndSettle();

      expect(find.text('Ferheng'), findsOneWidget);
      final search = find.byKey(const ValueKey('lexicon-search-field'));
      await tester.enterText(search, 'ROJBAŞ');
      await tester.pump();

      expect(
        find.byKey(const ValueKey('lexicon-entry-rojbas')),
        findsOneWidget,
      );
      expect(find.text('Rojbaş'), findsOneWidget);
      expect(find.text('Günaydın / İyi günler'), findsOneWidget);
    },
  );

  testWidgets('kaynaklı ders son slaytta ders-özel hızlı hatırlama gösterir', (
    tester,
  ) async {
    const lesson = Lesson(
      id: 'everyday_1',
      slug: 'selamlasma',
      titleKu: 'Silavkirin',
      titleTr: 'Selamlaşma',
      category: 'everyday',
    );
    await tester.pumpWidget(
      wrap(
        LessonDetailScreen(lesson: lesson, repository: MockZanKurdRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-recall-card')), findsNothing);
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-recall-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-recall-term')), findsOneWidget);
    expect(find.text('Rojbaş'), findsOneWidget);
    expect(find.text('Günaydın / İyi günler'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lesson-recall-reveal')));
    await tester.pump();
    expect(find.text('Günaydın / İyi günler'), findsOneWidget);
    expect(find.byKey(const ValueKey('lesson-recall-reveal')), findsNothing);
    expect(find.byKey(const ValueKey('lesson-recall-next')), findsOneWidget);

    // 2026-09-29 Şahnê: düğmeler 52 boyda; açılan anlam "Sonraki"yi alt
    // gezinme çubuğunun altına itebiliyor — kullanıcı gibi önce kaydır.
    await tester.ensureVisible(
      find.byKey(const ValueKey('lesson-recall-next')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('lesson-recall-next')));
    await tester.pump();
    expect(find.text('Êvarbaş'), findsOneWidget);
    expect(find.text('Günaydın / İyi günler'), findsNothing);
  });

  testWidgets('kaynaklı ders güvenli TTS varsa son slaytta dinleme sunar', (
    tester,
  ) async {
    final speaker = _FakeLessonListeningSpeaker();
    const lesson = Lesson(
      id: 'everyday_1',
      slug: 'selamlasma',
      titleKu: 'Silavkirin',
      titleTr: 'Selamlaşma',
      category: 'everyday',
    );
    await tester.pumpWidget(
      wrap(
        LessonDetailScreen(
          lesson: lesson,
          repository: MockZanKurdRepository(),
          listeningSpeaker: speaker,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-listening-card')), findsOneWidget);
    expect(find.text('Rojbaş'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('lesson-listening-card')),
        matching: find.text('Rojbaş'),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('lesson-listening-play')));
    await tester.pump();
    expect(speaker.spoken, ['Rojbaş']);
  });

  testWidgets('Kurmancî TTS yoksa ders dinleme kartı görünmez', (tester) async {
    const lesson = Lesson(
      id: 'everyday_1',
      slug: 'selamlasma',
      titleKu: 'Silavkirin',
      titleTr: 'Selamlaşma',
      category: 'everyday',
    );
    await tester.pumpWidget(
      wrap(
        LessonDetailScreen(
          lesson: lesson,
          repository: MockZanKurdRepository(),
          listeningSpeaker: _FakeLessonListeningSpeaker(available: false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-listening-card')), findsNothing);
  });

  testWidgets('kaynağı olmayan derste hızlı hatırlama uydurulmaz', (
    tester,
  ) async {
    const lesson = Lesson(
      id: 'source-less',
      slug: 'source-less',
      titleKu: 'Dersa Bê Çavkanî',
      titleTr: 'Kaynaksız Ders',
      category: 'test',
    );
    await tester.pumpWidget(
      wrap(
        LessonDetailScreen(
          lesson: lesson,
          repository: _SourceLessLessonRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('lesson-recall-card')), findsNothing);
  });

  testWidgets('%200 yazıda dar telefonda hızlı hatırlama taşmaz', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const lesson = Lesson(
      id: 'everyday_1',
      slug: 'selamlasma',
      titleKu: 'Silavkirin',
      titleTr: 'Selamlaşma',
      category: 'everyday',
    );
    await tester.pumpWidget(
      wrapLargeText(
        LessonDetailScreen(lesson: lesson, repository: MockZanKurdRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('İleri'));
    await tester.pumpAndSettle();

    final reveal = find.byKey(const ValueKey('lesson-recall-reveal'));
    await tester.ensureVisible(reveal);
    await tester.pumpAndSettle();
    await tester.tap(reveal);
    await tester.pump();

    expect(find.byKey(const ValueKey('lesson-recall-answer')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
