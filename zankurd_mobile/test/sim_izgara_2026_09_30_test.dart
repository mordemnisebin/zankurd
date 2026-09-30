// 2026-09-30 simülatör: ızgara ve yerleşim kusurları (L4, L5, L10, L13, L14,
// S2, S8, S9, S10).
//
// Ortak sebep: ekran turu ve widget testleri hep 1.0 yazı ölçeğinde ve 390
// px genişlikte koşuyordu. Kusurların hepsi büyük yazıda (iOS Ekstra Büyük,
// 2.35x) ya da Kurmancî'nin daha uzun etiketlerinde ortaya çıkıyor:
// sütunlar sabit kaldığı için adlar kelime ortasından bölünüyor, düğmeler
// yan yana yarım genişliğe sıkışıyor, satır kırılınca kardeş karolar eşit
// yükseklikte kalmıyordu. Bu dosyanın her bekçisi iki yazı ölçeğinde (1.0 ve
// 2.35) ve iki telefon boyunda (375x667, 390x844) koşar; başarısızlık
// istisna (RenderFlex taşması), kelime ortasında kırılma ya da eşit
// olmayan boy olarak görünür.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/home/home_rows.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/badge_widget.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/weekly_performance_chart.dart';

import 'support/realistic_device.dart';

const _sizes = [Size(375, 667), Size(390, 844)];
const _scales = [1.0, 2.35];

Widget _shell(Widget child, {required double scale, String lang = 'ku'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang(lang),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
      ChangeNotifierProvider<ReducedMotionProvider>(
        create: (_) => ReducedMotionProvider(initialUserReduce: true),
      ),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.dark(),
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: appChild!,
      ),
      home: child,
    ),
  );
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// [root] altındaki her metinde hiçbir söz iki satıra bölünmemeli ve hiçbir
/// metin "…" ile kesilmemeli.
void _expectNoMidWordBreaks(Finder root, String where) {
  for (final element
      in find
          .descendant(of: root, matching: find.byType(RichText))
          .evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    final text = paragraph.text.toPlainText();
    expect(
      paragraph.didExceedMaxLines,
      isFalse,
      reason: '$where: "$text" kesildi',
    );
    for (final word in RegExp(r'\S+').allMatches(text)) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: word.start, extentOffset: word.end),
        // `max`: kutu satırın tam boyunu kaplar; yedek yazı tipine düşen
        // harf (î, ş) farklı üst çizgiyle sahte "ikinci satır" üretmez.
        boxHeightStyle: ui.BoxHeightStyle.max,
      );
      final lines = boxes.map((b) => b.top.round()).toSet();
      expect(
        lines.length,
        lessThanOrEqualTo(1),
        reason:
            '$where: "${word.group(0)}" ("$text") kelime ortasından bölündü',
      );
    }
  }
}

const _categories = [
  'Ziman',
  'Çand',
  'Dîrok',
  'Wêje',
  'Cografya',
  'Muzîk',
  'Sînema',
];

void main() {
  // Ölçü fontunda her harf kare; kelime bölünmesi ancak gerçek yazı
  // tipiyle anlamlı ölçülür.
  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StoryProgressStore.resetInstance();
  });

  group('L5 + S10: ana sayfa konu ızgarası', () {
    Widget grid({required bool isKu, required double scale}) => _shell(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(SahneSpace.page),
          child: HomeTopicGrid(
            isKu: isKu,
            categories: _categories,
            progress: const {
              'Çand': CategoryProgress(
                category: 'Çand',
                correct: 4,
                threshold: 10,
              ),
              'Dîrok': CategoryProgress(
                category: 'Dîrok',
                correct: 2,
                threshold: 10,
              ),
            },
            questionCounts: const {
              'Ziman': 241,
              'Çand': 214,
              'Dîrok': 138,
              'Wêje': 151,
              'Cografya': 245,
              'Muzîk': 120,
              'Sînema': 71,
            },
            onOpen: (_) {},
          ),
        ),
      ),
      scale: scale,
      lang: isKu ? 'ku' : 'tr',
    );

    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final isKu in [true, false]) {
          testWidgets('ad ve sayı bölünmez, taşma yok '
              '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x, '
              '${isKu ? 'ku' : 'tr'})', (tester) async {
            _setSize(tester, size);
            await tester.pumpWidget(grid(isKu: isKu, scale: scale));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            _expectNoMidWordBreaks(
              find.byKey(const ValueKey('home-topic-grid')),
              'konu ızgarası',
            );
          });
        }
      }
    }

    testWidgets('büyük yazıda sütun sayısı düşer', (tester) async {
      _setSize(tester, _sizes.first);
      await tester.pumpWidget(grid(isKu: true, scale: 1.0));
      await tester.pumpAndSettle();
      double leftOf(String c) =>
          tester.getTopLeft(find.byKey(ValueKey('home-topic-$c'))).dx;
      final normalColumns = _categories.map(leftOf).toSet().length;
      expect(normalColumns, greaterThanOrEqualTo(3));

      await tester.pumpWidget(grid(isKu: true, scale: 2.35));
      await tester.pumpAndSettle();
      final largeColumns = _categories.map(leftOf).toSet().length;
      expect(largeColumns, lessThan(normalColumns));
    });

    testWidgets(
      'S10: oynanmış ve oynanmamış karoda soru sayısı durur, boylar eşit',
      (tester) async {
        _setSize(tester, _sizes.last);
        await tester.pumpWidget(grid(isKu: false, scale: 1.0));
        await tester.pumpAndSettle();
        // Oynanmış (Çand, Dîrok) ve oynanmamış (Ziman, Wêje) karoların
        // hepsinde sayı satırı var; çubuk yalnız oynanmışlarda.
        for (final c in _categories) {
          final tile = find.byKey(ValueKey('home-topic-$c'));
          expect(
            find.descendant(of: tile, matching: find.textContaining(' soru')),
            findsOneWidget,
            reason: '$c karosunda soru sayısı yok',
          );
        }
        expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
        // Aynı satırdaki karolar (Ziman oynanmamış, Çand ve Dîrok oynanmış) eşit yükseklikte.
        final heights = ['Ziman', 'Çand', 'Dîrok']
            .map((c) => tester.getSize(find.byKey(ValueKey('home-topic-$c'))))
            .map((s) => s.height)
            .toSet();
        expect(heights.length, 1, reason: 'karo boyları eşit değil: $heights');
      },
    );
  });

  group('L14: mağaza ızgarası', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('ürün adları bölünmez, taşma yok '
            '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x)', (
          tester,
        ) async {
          // Izgara ListView'in içinde tembel kurulur; kartların hepsi
          // kurulsun diye yükseklik büyük tutulur (genişlik gerçek).
          _setSize(tester, Size(size.width, 20000));
          await tester.pumpWidget(
            _shell(
              ShopScreen(repository: MockZanKurdRepository()),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final cards = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'shop-item-surface-',
                ),
          );
          expect(cards, findsWidgets);
          final lefts = cards
              .evaluate()
              .map((e) => tester.getTopLeft(find.byWidget(e.widget)).dx)
              .toSet();
          if (scale > 2) {
            expect(lefts.length, 1, reason: 'büyük yazıda tek sütun olmalı');
          } else {
            expect(lefts.length, 2, reason: 'normal yazıda iki sütun');
          }
          _expectNoMidWordBreaks(find.byType(GridView), 'mağaza ızgarası');
        });
      }
    }
  });

  group('S9: sonuç istatistik karoları', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('aynı satırdaki karolar eşit yükseklikte '
            '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x)', (
          tester,
        ) async {
          _setSize(tester, size);
          await tester.pumpWidget(
            _shell(
              const Scaffold(
                body: Padding(
                  padding: EdgeInsets.all(SahneSpace.page),
                  child: ResultStatTiles(
                    correct: 2,
                    wrong: 3,
                    unanswered: 0,
                    streak: 1,
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final cards = find.descendant(
            of: find.byType(ResultStatTiles),
            matching: find.byType(SahneSurfaceCard),
          );
          expect(cards, findsNWidgets(3));
          final rows = <int, Set<double>>{};
          for (var i = 0; i < 3; i++) {
            final top = tester.getTopLeft(cards.at(i)).dy.round();
            rows
                .putIfAbsent(top, () => {})
                .add(tester.getSize(cards.at(i)).height);
          }
          for (final entry in rows.entries) {
            expect(
              entry.value.length,
              1,
              reason: 'satır ${entry.key}: boylar ${entry.value}',
            );
          }
          _expectNoMidWordBreaks(find.byType(ResultStatTiles), 'karolar');
        });
      }
    }
  });

  group('S2: rozet hücresi', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('kazanılmış rozet taşmaz '
            '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x)', (
          tester,
        ) async {
          _setSize(tester, size);
          final cellWidth = (size.width - 2 * SahneSpace.page) / 3;
          await tester.pumpWidget(
            _shell(
              Scaffold(
                body: Center(
                  // Profil ızgarası: 3 sütun, en-boy 0.76.
                  child: SizedBox(
                    width: cellWidth,
                    height: cellWidth / 0.76,
                    child: const BadgeWidget(
                      badgeId: 'speed_demon',
                      titleKu: 'Leztir',
                      titleTr: 'Hızlı',
                      descriptionKu: '',
                      descriptionTr: '',
                      iconName: 'speed',
                      isUnlocked: true,
                      isKu: true,
                    ),
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.text('Hat qezenckirin'), findsOneWidget);
        });
      }
    }
  });

  group('S8: haftalık grafik y ekseni', () {
    test('etiketler tamsayı adımlı ve eşit aralıklı', () {
      for (var maxVal = 1; maxVal <= 500; maxVal++) {
        final step = niceStep(maxVal);
        final count = (maxVal / step).ceil();
        expect(count, lessThanOrEqualTo(5), reason: 'maxVal=$maxVal');
        expect(step * count, greaterThanOrEqualTo(maxVal));
        expect(
          const [1, 2, 5].contains(_leading(step)),
          isTrue,
          reason: 'adım $step 1/2/5 x 10^n değil',
        );
      }
      // Kusurun kendisi: tavan 5 iken eski eksen 0,1,3,4,5 basıyordu.
      expect(niceStep(5), 1);
      final labels = [for (var i = 0; i <= 5; i++) i * niceStep(5)];
      expect(labels, [0, 1, 2, 3, 4, 5]);
    });

    testWidgets('grafik taşmadan çizilir', (tester) async {
      _setSize(tester, _sizes.first);
      await tester.pumpWidget(
        _shell(
          const Scaffold(
            body: WeeklyPerformanceChart(
              history: {
                '2026-09-01': {'correct': 4, 'wrong': 1},
                '2026-09-02': {'correct': 2, 'wrong': 3},
              },
              isKu: true,
            ),
          ),
          scale: 2.35,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('S12: sonuç ekranı açıklama listesi', () {
    const longPrompt =
        '10. Di fîlmê "Dema Hespên Serxweş" de, da ku hêstir li ber '
        'sermaya zivistana çiyê xwe ragirin, çi didin wan hespên xwe yên '
        'ku ji ber sermayê diricifin û nikarin bimeşin?';
    const record = AnswerRecord(
      id: 'r10',
      category: 'Sînema',
      prompt: longPrompt,
      answers: ['Viskî', 'Av', 'Şîr', 'Çay'],
      correctAnswer: 'Viskî',
      selectedAnswer: 'Av',
      explanation: 'x',
    );
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('uzun soru metni kesilmez '
            '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x)', (
          tester,
        ) async {
          _setSize(tester, size);
          await tester.pumpWidget(
            _shell(
              const Scaffold(
                body: SingleChildScrollView(
                  child: ResultExplanationEntry(
                    index: 10,
                    record: record,
                    explanation: 'Qaçaxçî viskiyê didin hêstiran.',
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final prompt = find.textContaining('sermaya zivistana');
          expect(prompt, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(prompt);
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(paragraph.text.toPlainText(), contains('nikarin bimeşin?'));
          _expectNoMidWordBreaks(
            find.byType(ResultExplanationEntry),
            'açıklama listesi',
          );
        });
      }
    }
  });

  group('L4: çîrok rehberi sayfası', () {
    for (final scale in _scales) {
      testWidgets('güvenli alanın altında açılır (${scale}x)', (tester) async {
        _setSize(tester, _sizes.first);
        tester.view.padding = const FakeViewPadding(top: 47);
        tester.view.viewPadding = const FakeViewPadding(top: 47);
        addTearDown(tester.view.resetPadding);
        addTearDown(tester.view.resetViewPadding);
        await tester.pumpWidget(
          _shell(
            StoryScreen(story: cayxaneStory, guide: cayxaneGuide),
            scale: scale,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('story-open-guide')));
        await tester.pumpAndSettle();
        final sheetTop = tester.getTopLeft(find.byType(BottomSheet)).dy;
        expect(
          sheetTop,
          greaterThanOrEqualTo(47),
          reason: 'rehber sayfası durum çubuğuna girdi',
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('L10: ders alt gezinmesi', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('son adımda "Biqedîne" bölünmez '
            '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x)', (
          tester,
        ) async {
          _setSize(tester, size);
          await tester.pumpWidget(
            _shell(
              Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(SahneSpace.page),
                  child: LessonSlideNavigation(
                    showBack: true,
                    isLast: true,
                    onBack: () {},
                    onNext: () {},
                    onMiniQuiz: () {},
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          _expectNoMidWordBreaks(
            find.byType(LessonSlideNavigation),
            'ders gezinmesi',
          );
          final next = tester.getTopLeft(find.text('Biqedîne'));
          final back = tester.getTopLeft(find.text('Paş'));
          if (scale > 2) {
            expect(back.dy, greaterThan(next.dy), reason: 'alt alta');
            expect(
              tester.getSize(find.text('Biqedîne')).width,
              lessThan(size.width),
            );
          }
        });
      }
    }
  });

  group('L13: hesap kaydet diyaloğu düğmeleri', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('iki düğme eşit genişlikte '
            '(${size.width.toInt()}x${size.height.toInt()}, ${scale}x)', (
          tester,
        ) async {
          _setSize(tester, size);
          await tester.pumpWidget(
            _shell(
              Scaffold(
                body: Center(
                  child: AlertDialog(
                    title: const Text('Hesabê xwe tomar bike'),
                    content: const Text('E-name'),
                    actions: [
                      DialogActionPair(
                        cancel: OutlinedButton(
                          onPressed: () {},
                          child: const Text('Betal bike'),
                        ),
                        confirm: FilledButton(
                          onPressed: () {},
                          child: const Text('Tomar bike'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final cancel = find.widgetWithText(OutlinedButton, 'Betal bike');
          final confirm = find.widgetWithText(FilledButton, 'Tomar bike');
          expect(
            tester.getSize(cancel).width,
            tester.getSize(confirm).width,
            reason: 'düğmeler eşit genişlikte değil',
          );
          expect(
            tester.getTopLeft(cancel).dx,
            scale > 2
                ? tester.getTopLeft(confirm).dx
                : lessThan(tester.getTopLeft(confirm).dx),
          );
          if (scale > 2) {
            expect(
              tester.getTopLeft(confirm).dy,
              lessThan(tester.getTopLeft(cancel).dy),
              reason: 'birincil üstte',
            );
          } else {
            expect(tester.getTopLeft(confirm).dy, tester.getTopLeft(cancel).dy);
          }
          _expectNoMidWordBreaks(find.byType(DialogActionPair), 'diyalog');
        });
      }
    }
  });
}

int _leading(int n) {
  while (n >= 10) {
    n ~/= 10;
  }
  return n;
}
