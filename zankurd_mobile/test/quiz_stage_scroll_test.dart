import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/coach_mark.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// Soru sahnesinin kayan gövdesi — 2026-09-30 simülatör denetiminin dört
/// kusuru, iki telefon boyu (375×667, 390×844) ve iki yazı ölçeğinde
/// (1.0 ve iOS "Ekstra Büyük" 2.35).
///
/// * **S1** — cevaptan sonra "Açıklamayı gör" satırı alt eylem perdesinin
///   (Sonraki/Bitir) arkasında yarım kalıyordu. `_revealExplanation` hedefi
///   yalnız serbest metin türlerinin kutusuydu; şıklı sorudaki satırın
///   anahtarı yoktu, hedef bulunamayınca çağrı sessizce dönüyordu. Üstüne
///   çağrı test ortamında hiç koşmuyordu (`isFlutterTestEnvironment`), bu
///   yüzden 2273 testin hiçbiri görmedi.
/// * **L1** — kaydırılan içerik elmas ilerleme şeridinin dibinde sert bir
///   çizgiyle kesiliyordu; harfler elmasların arkasından giriyor gibiydi.
///   Sessizdi çünkü içerik ekrana sığdığı sürece kaydırma olmaz; büyük
///   yazıda soru metni tek başına ekranı doldurur.
/// * **L3** — soru değişince kaydırma konumu korunuyor, yeni soru ortadan
///   başlıyordu. Sessizdi çünkü test ortamında ilk soru hiç kaydırılmazdı.
/// * **L10** — öğretici katmandaki yan yana düğmeler büyük yazıda dar
///   yuvaya sıkışıp "Pê/ş" diye kelime ortasından kırılıyordu.
///
/// Ölçüler GERÇEK yazı tipiyle (`loadAppFonts`) alınır: ölçü fontu her
/// harfi kare sayar ve büyük yazıdaki satır kırılmalarını yanıltır.
const _long1 = QuizQuestion(
  id: 'stage-scroll-1',
  category: 'Ziman',
  prompt:
      'Di rêzimana Kurmancî de peyva «navdêr» ji bo çi tê bikaranîn û '
      'di hevokê de çi erkî dike?',
  answers: [
    'Ji bo navê kes, tişt an cihan tê bikaranîn',
    'Ji bo kirina karekî tê bikaranîn',
    'Ji bo diyarkirina rengê tiştan tê bikaranîn',
    'Ji bo girêdana du hevokan tê bikaranîn',
  ],
  correctAnswer: 'Ji bo navê kes, tişt an cihan tê bikaranîn',
  explanation: 'Navdêr navê kes, tişt an cihan e.',
);

const _long2 = QuizQuestion(
  id: 'stage-scroll-2',
  category: 'Ziman',
  prompt:
      'Kîjan ji van peyvan di rêzimana Kurmancî de wekî lêker tê '
      'hesibandin û ji bo çi tê bikaranîn?',
  answers: [
    'Xwendin, ji bo kirina karekî',
    'Şîn, ji bo diyarkirina rengekî',
    'Mal, ji bo navê cihekî',
    'Û, ji bo girêdana du peyvan',
  ],
  correctAnswer: 'Xwendin, ji bo kirina karekî',
  explanation: 'Xwendin lêker e.',
);

/// Bekçinin iki telefon boyu ve iki yazı ölçeği.
const _sizes = [Size(375, 667), Size(390, 844)];
const _scales = [1.0, 2.35];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  const scrollKey = ValueKey('quiz-portrait-scroll');
  const progressKey = ValueKey('quiz-progress-bar');
  const nextKey = ValueKey('quiz-next-button');
  const explanationKey = ValueKey('quiz-view-explanation');
  final boundaryKey = GlobalKey();

  Future<void> pumpQuiz(
    WidgetTester tester,
    Size size,
    double scale, {
    bool learning = true,
    bool tutorialSeen = true,
    List<QuizQuestion> questions = const [_long1, _long2],
    bool reducedMotion = false,
    bool kurmanci = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': tutorialSeen,
      'zankurd.navTour.seen': true,
    });
    final repository = freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': tutorialSeen,
      'zankurd.navTour.seen': true,
    });
    await tester.pumpWidget(
      testShell(
        reducedMotion: reducedMotion,
        languageProvider: kurmanci ? kurmanciLang() : null,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: boundaryKey,
              child: QuizScreen(
                repository: repository,
                room: repository.createRoom(),
                questions: questions,
                experience: learning
                    ? QuizExperience.learning
                    : QuizExperience.competition,
                enableTimer: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ScrollPosition position(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(scrollKey),
          matching: find.byType(Scrollable),
        ),
      )
      .position;

  Future<void> answerWrong(WidgetTester tester, QuizQuestion q) async {
    final wrong = q.answers.firstWhere((a) => a != q.correctAnswer);
    final tile = find.text(wrong).first;
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile, warnIfMissed: false);
    // Açıklama satırı 800 ms'lik denetleyicinin bitişinde açılır, üstüne
    // 320 ms'lik kaydırma biner.
    await tester.pumpAndSettle(const Duration(seconds: 2));
  }

  group('S1 — açıklama satırı alt perdenin üstünde tamamen görünür', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
          '2026-09-30 simülatör: ${size.width.toInt()}x${size.height.toInt()} '
          '@$scale cevaptan sonra "Açıklamayı gör" satırı perdenin üstünde',
          (tester) async {
            await pumpQuiz(tester, size, scale);
            // Kusur SESSİZ kalıyordu: hedef anahtarı yoktu ve çağrı test
            // ortamında hiç koşmuyordu.
            await answerWrong(tester, _long1);

            final row = find.byKey(explanationKey);
            expect(row, findsOneWidget);
            final rowRect = tester.getRect(row);
            final viewport = tester.getRect(find.byKey(scrollKey));
            final dock = tester.getRect(find.byKey(nextKey));
            final progress = tester.getRect(find.byKey(progressKey));

            expect(
              rowRect.bottom,
              lessThanOrEqualTo(dock.top),
              reason: 'satır alt perdenin (Sonraki) arkasında kalmamalı',
            );
            expect(rowRect.bottom, lessThanOrEqualTo(viewport.bottom));
            expect(
              rowRect.top,
              greaterThanOrEqualTo(progress.bottom),
              reason: 'satır elmas şeridinin altına kaçmamalı',
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }

    testWidgets(
      '2026-09-30 simülatör: hareketi azalt açıkken satır anlık görünür',
      (tester) async {
        await pumpQuiz(tester, const Size(375, 667), 2.35, reducedMotion: true);
        await answerWrong(tester, _long1);
        final rowRect = tester.getRect(find.byKey(explanationKey));
        final dock = tester.getRect(find.byKey(nextKey));
        expect(rowRect.bottom, lessThanOrEqualTo(dock.top));
      },
    );
  });

  group('L1 — kayan içerik başlığın altında kırpılır ve söner', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
          '2026-09-30 simülatör: ${size.width.toInt()}x${size.height.toInt()} '
          '@$scale kaydırılmış içerik elmas şeridinin bölgesine çizilmez',
          (tester) async {
            await pumpQuiz(tester, size, scale, learning: false);
            final viewport = tester.getRect(find.byKey(scrollKey));
            final progress = tester.getRect(find.byKey(progressKey));
            // Kayan alanın kendisi şeridin ALTINDA başlar: başlık bölgesi
            // kayan alana ait değildir, içerik oraya çizilemez.
            expect(
              viewport.top,
              greaterThanOrEqualTo(progress.bottom - 0.5),
              reason: 'kayan alan elmas şeridinin altından başlamalı',
            );

            final pos = position(tester);
            if (scale > 1) {
              expect(
                pos.maxScrollExtent,
                greaterThan(0),
                reason: 'büyük yazıda gövde kaymalı (test kurulumu)',
              );
            }
            // İçeriği kaydır: bir metin satırı kayan alanın tam üst
            // kenarına gelsin.
            pos.jumpTo((pos.maxScrollExtent / 2).clamp(0.0, 400.0));
            await tester.pump();

            // Piksel bekçisi: kayan alanın ilk iki satırı (başlığa en yakın
            // bölge) neredeyse arka plan olmalı. Sönme olmasa kaydırılmış
            // beyaz harf burada ~250 parlaklığında çizilirdi.
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final brightest = await tester.runAsync(() async {
              final image = await boundary.toImage();
              final data = await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              );
              var maxLum = 0.0;
              final top = viewport.top.ceil();
              for (var y = top; y < top + 2; y++) {
                for (var x = 0; x < image.width; x++) {
                  final i = (y * image.width + x) * 4;
                  final lum =
                      0.2126 * data!.getUint8(i) +
                      0.7152 * data.getUint8(i + 1) +
                      0.0722 * data.getUint8(i + 2);
                  if (lum > maxLum) maxLum = lum;
                }
              }
              return maxLum;
            });
            expect(
              brightest,
              lessThan(90),
              reason: 'başlığın hemen altında parlak metin pikseli var',
            );
          },
        );
      }
    }
  });

  group('L3 — yeni soruda kaydırma başa döner', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
          '2026-09-30 simülatör: ${size.width.toInt()}x${size.height.toInt()} '
          '@$scale ikinci soru en üstten başlar',
          (tester) async {
            await pumpQuiz(tester, size, scale);
            await answerWrong(tester, _long1);
            final pos = position(tester);
            if (pos.maxScrollExtent > 0) {
              pos.jumpTo(pos.maxScrollExtent);
              await tester.pump();
              expect(
                position(tester).pixels,
                greaterThan(0),
                reason: 'ilk soru kaydırılmış olmalı (test kurulumu)',
              );
            }
            // Cevaptan sonra alt perdede "Sonraki" var.
            await tester.tap(find.byKey(nextKey));
            await tester.pumpAndSettle();

            expect(find.textContaining('lêker'), findsWidgets);
            expect(
              position(tester).pixels,
              0,
              reason: 'yeni soru kaydırma konumunu devralmamalı',
            );
          },
        );
      }
    }
  });

  group('L10 — öğretici katman düğmeleri kırılmaz', () {
    /// Etiket tek satırda mı? (kelime ortasından kırılma = birden çok satır)
    bool singleLine(WidgetTester tester, Finder text) {
      final paragraph = tester.renderObject<RenderParagraph>(text);
      return paragraph.size.height <=
          paragraph.getMinIntrinsicHeight(double.infinity) + 1;
    }

    for (final ku in [false, true]) {
      for (final size in _sizes) {
        for (final scale in _scales) {
          testWidgets(
            '2026-09-30 simülatör: ${ku ? 'KU' : 'TR'} ${size.width.toInt()}x${size.height.toInt()} '
            '@$scale "Pêş" etiketi tek satır, düğmeler taşmaz',
            (tester) async {
              await pumpQuiz(
                tester,
                size,
                scale,
                tutorialSeen: false,
                kurmanci: ku,
              );
              await tester.pumpAndSettle();
              // Anahtarsız aranır; sıra düzene bağlı olduğu için ikisi de
              // ölçülür.
              final buttons = find.descendant(
                of: find.byType(CoachMarkOverlay),
                matching: find.byType(SahneButton),
              );
              expect(buttons, findsNWidgets(2));
              final screen = Offset.zero & size;
              final rects = <Rect>[];
              for (var i = 0; i < 2; i++) {
                final button = buttons.at(i);
                final label = find.descendant(
                  of: button,
                  matching: find.byType(Text),
                );
                expect(
                  singleLine(tester, label.first),
                  isTrue,
                  reason: 'düğme etiketi kelime ortasından kırılmamalı',
                );
                final r = tester.getRect(button);
                expect(screen.contains(r.topLeft), isTrue);
                expect(screen.contains(r.bottomRight), isTrue);
                rects.add(r);
              }
              expect(rects[0].overlaps(rects[1]), isFalse);
              final stackedVertically =
                  rects[0].bottom <= rects[1].top ||
                  rects[1].bottom <= rects[0].top;
              if (scale > 1.25) {
                expect(
                  stackedVertically,
                  isTrue,
                  reason: 'büyük yazıda düğmeler alt alta dizilir',
                );
              } else {
                expect(
                  (rects[0].center.dy - rects[1].center.dy).abs(),
                  lessThan(4),
                  reason: 'normal yazıda düğmeler yan yana kalır',
                );
              }
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  });

  group('L8 — seviye sınavı başlığı ilerleme çubuğuna binmez', () {
    for (final ku in [false, true]) {
      for (final size in _sizes) {
        for (final scale in _scales) {
          testWidgets('2026-09-30 simülatör: ${ku ? 'KU' : 'TR'} '
              '${size.width.toInt()}x${size.height.toInt()} @$scale '
              'başlık ilerleme çubuğunun üstünde biter', (tester) async {
            // Kusur SESSİZDİ: üst satır yüksekliği çocuklar ölçülmeden 68'e
            // sabitleniyordu (`CustomMultiChildLayout.getSize`); "Asta xwe
            // diyar bike" büyük yazıda iki satıra çıkınca bandın dışına
            // taşıp altındaki çubuğun üstüne biniyordu. Normal ölçekte
            // başlık tek satırdır ve testler yalnız orada koşuyordu.
            tester.view.physicalSize = size;
            tester.view.devicePixelRatio = 1;
            tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
            tester.view.viewPadding = const FakeViewPadding(
              top: 47,
              bottom: 34,
            );
            addTearDown(tester.view.reset);
            SharedPreferences.setMockInitialValues({});
            PlacementStore.resetInstance();
            await tester.pumpWidget(
              testShell(
                languageProvider: ku ? kurmanciLang() : null,
                child: Builder(
                  builder: (context) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: LevelPlacementScreen(
                      repository: freshMockRepository(),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            final title = find.text(
              ku ? 'Asta xwe diyar bike' : 'Seviyeni belirle',
            );
            expect(title, findsOneWidget);
            final progress = find.byType(SahneProgressBar);
            expect(progress, findsOneWidget);
            // Kutu değil ÇİZİLEN satırlar ölçülür: eski yerleşimde kutu 68'e
            // kelepçeliydi, taşan satırlar kutunun dışına boyanıyordu.
            final paragraph = tester.renderObject<RenderParagraph>(title);
            final need = paragraph.getMaxIntrinsicHeight(paragraph.size.width);
            final rect = tester.getRect(title);
            expect(
              rect.center.dy + need / 2,
              lessThanOrEqualTo(tester.getRect(progress).top),
              reason: 'başlığın çizilen satırları çubuğa binmemeli',
            );
            expect(need, lessThanOrEqualTo(rect.height + 0.5));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
