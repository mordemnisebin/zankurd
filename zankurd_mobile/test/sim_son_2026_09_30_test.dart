// 2026-09-30 simülatör: son dört kusur (karşılama kaydırması, konu çubuğu
// oranı, çıkış diyaloğu hizası, başarı ızgarası ikon çizgisi).
//
// Ortak sebep: ekran turu ve widget testleri 1.0 yazı ölçeğinde koşuyordu;
// dört kusurun üçü yalnız iOS "Ekstra Büyük" yazıda (2.35x) görünür (dördüncüsü
// iki satırlı ad gerektirir), biri de (konu çubuğu) hiçbir testin oranı
// ölçmemesinden sessiz kaldı. Bu dosyanın bekçileri iki telefon boyunda
// (375x667, 390x844) ve iki ölçekte (1.0, 2.35) koşar; gerçek yazı tipiyle
// (`loadAppFonts`) ölçer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/badge_widget.dart';
import 'package:zankurd_mobile/src/widgets/dialog_action_pair.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

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
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 47, bottom: 34),
        ),
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

String _tag(Size size, double scale) =>
    '${size.width.toInt()}x${size.height.toInt()}, ${scale}x';

void main() {
  setUpAll(loadAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1: karşılama ekranı büyük yazıda kesilmez', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(
          'iki sayfa da kaydırarak tamamen görünür (${_tag(size, scale)})',
          (tester) async {
            _setSize(tester, size);
            await tester.pumpWidget(
              _shell(OnboardingScreen(onComplete: () {}), scale: scale),
            );
            await tester.pumpAndSettle();
            final surface = tester.getRect(
              find.byKey(const ValueKey('onboarding-surface')),
            );

            for (var page = 0; page < 2; page++) {
              final scroll = find.byType(SingleChildScrollView);
              expect(scroll, findsOneWidget);
              final scrollable = find.descendant(
                of: scroll,
                matching: find.byType(Scrollable),
              );
              final position = tester
                  .state<ScrollableState>(scrollable)
                  .position;
              final viewport = tester.getRect(scroll);
              final overflows = position.maxScrollExtent > 0;

              // Taşan bandın kaydırılabildiği görünür olmalı.
              final bar = find.byKey(
                const ValueKey('onboarding-text-scrollbar'),
              );
              expect(bar, findsOneWidget);
              if (overflows) {
                await tester.drag(scroll, const Offset(0, -40));
                await tester.pumpAndSettle();
                expect(
                  position.pixels,
                  greaterThan(0),
                  reason: 'sayfa $page kaydırılamıyor',
                );
              }

              // Sonuna kadar kaydır: son madde alt kenarı görünür alanda.
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              final texts = find.descendant(
                of: scroll,
                matching: find.byType(RichText),
              );
              for (final e in texts.evaluate()) {
                final p = e.renderObject! as RenderParagraph;
                expect(
                  p.didExceedMaxLines,
                  isFalse,
                  reason: '"${p.text.toPlainText()}" kesildi',
                );
              }
              final lastText = tester.getRect(texts.last);
              expect(
                lastText.bottom,
                lessThanOrEqualTo(viewport.bottom + 0.5),
                reason: 'sayfa $page son satır kesik',
              );
              position.jumpTo(0);
              await tester.pumpAndSettle();
              expect(
                tester.getRect(texts.first).top,
                greaterThanOrEqualTo(viewport.top - 0.5),
                reason: 'sayfa $page başlık kesik',
              );

              // Yaş onayı ve düğme her zaman erişilebilir.
              for (final f in [
                find.byKey(const ValueKey('onboarding-age-gate')),
                find.text(page == 1 ? 'Dest pê bike' : 'Bidomîne'),
              ]) {
                if (f.evaluate().isEmpty) continue;
                final r = tester.getRect(f);
                expect(r.bottom, lessThanOrEqualTo(surface.bottom));
                expect(r.top, greaterThanOrEqualTo(surface.top));
              }
              if (page == 0) {
                await tester.tap(find.text('Bidomîne'));
                await tester.pumpAndSettle();
              }
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });

  group('2: konu performans çubuğu doğru/yanlış oranını gösterir', () {
    Future<void> pumpBar(WidgetTester tester, int correct, int mistakes) =>
        tester.pumpWidget(
          _shell(
            Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  child: CategoryOutcomeBar(
                    correct: correct,
                    mistakes: mistakes,
                  ),
                ),
              ),
            ),
            scale: 1,
          ),
        );

    testWidgets('0 doğru 1 yanlış: yeşil pay yok, tamamı kırmızı', (
      tester,
    ) async {
      await pumpBar(tester, 0, 1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-bar-correct')), findsNothing);
      final wrong = find.byKey(const ValueKey('category-bar-wrong'));
      expect(wrong, findsOneWidget);
      expect(tester.getSize(wrong).width, closeTo(200, 0.5));
      expect(const CategoryOutcomeBar(correct: 0, mistakes: 1).correctShare, 0);
    });

    testWidgets('1 doğru 0 yanlış: tamamı yeşil, kırmızı yok', (tester) async {
      await pumpBar(tester, 1, 0);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('category-bar-wrong')), findsNothing);
      expect(
        tester
            .getSize(find.byKey(const ValueKey('category-bar-correct')))
            .width,
        closeTo(200, 0.5),
      );
    });

    testWidgets('3 doğru 1 yanlış: paylar 3:1', (tester) async {
      await pumpBar(tester, 3, 1);
      await tester.pumpAndSettle();
      final ok = tester
          .getSize(find.byKey(const ValueKey('category-bar-correct')))
          .width;
      final err = tester
          .getSize(find.byKey(const ValueKey('category-bar-wrong')))
          .width;
      expect(ok / err, closeTo(3, 0.1));
      expect(
        const CategoryOutcomeBar(correct: 3, mistakes: 1).correctShare,
        0.75,
      );
    });
  });

  group('3: çıkış diyaloğu düğmeleri eşit ve hizalı', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets('soru ekranı çıkış diyaloğu (${_tag(size, scale)})', (
          tester,
        ) async {
          _setSize(tester, size);
          final repository = freshMockRepository();
          SharedPreferences.setMockInitialValues({
            'zankurd.onboarding.seen': true,
            'zankurd.profileName.completed.user': true,
            'zankurd.navTour.seen': true,
            'zankurd.quiz_tutorial.seen': true,
          });
          await tester.pumpWidget(
            _quizShell(repository, scale: scale, size: size),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('aç'));
          await tester.pumpAndSettle();
          final answer = find.text(repository.questions.first.answers.first);
          await tester.ensureVisible(answer);
          await tester.pumpAndSettle();
          await tester.tap(answer);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('quiz-close')));
          await tester.pumpAndSettle();

          expect(find.byType(DialogActionPair), findsOneWidget);
          final leave = find.widgetWithText(TextButton, 'Çık');
          final stay = find.widgetWithText(FilledButton, 'Devam et');
          expect(leave, findsOneWidget);
          expect(stay, findsOneWidget);
          expect(
            tester.getSize(leave).width,
            closeTo(tester.getSize(stay).width, 0.5),
            reason: 'düğmeler eşit genişlikte değil',
          );
          if (scale > 2) {
            expect(
              tester.getTopLeft(leave).dx,
              tester.getTopLeft(stay).dx,
              reason: 'alt alta değil / sola hizasız',
            );
            expect(
              tester.getTopLeft(stay).dy,
              lessThan(tester.getTopLeft(leave).dy),
              reason: 'birincil (Devam et) üstte olmalı',
            );
          } else {
            expect(tester.getTopLeft(stay).dy, tester.getTopLeft(leave).dy);
            expect(
              tester.getTopLeft(leave).dx,
              lessThan(tester.getTopLeft(stay).dx),
            );
          }
        });
      }
    }

    test('iki eylemli her AlertDialog DialogActionPair kullanır', () {
      // Elle `actions: [Text.., Filled..]` yazan yeni bir diyalog aynı
      // hizasızlığı geri getirir; kaynakta iki eylemli çıplak dizi kalmamalı.
      final offenders = <String>[];
      for (final f in Directory('lib/src').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final s = f.readAsStringSync();
        for (final m in RegExp(
          r'AlertDialog\([\s\S]*?actions: \[\s*\n\s*(TextButton|OutlinedButton|SahneButton\.text)\(',
        ).allMatches(s)) {
          offenders.add('${f.path}@${m.start}');
        }
      }
      expect(offenders, isEmpty, reason: offenders.join(', '));
    });
  });

  group('4: başarı ızgarasında ikonlar aynı çizgide', () {
    for (final size in _sizes) {
      for (final scale in _scales) {
        testWidgets(_tag(size, scale), (tester) async {
          _setSize(tester, size);
          const titles = ['30 roj li pey hev', '500 pirs', 'Lîstika bêkêmasî'];
          await tester.pumpWidget(
            _shell(
              Scaffold(
                body: GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio: 0.76,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final title in titles)
                      BadgeWidget(
                        badgeId: title,
                        titleKu: title,
                        titleTr: title,
                        descriptionKu: '',
                        descriptionTr: '',
                        iconName: 'stars',
                        isUnlocked: false,
                        isKu: true,
                      ),
                  ],
                ),
              ),
              scale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final firstIconTops = <double>[];
          for (final badge in find.byType(BadgeWidget).evaluate()) {
            final box = find
                .descendant(
                  of: find.byWidget(badge.widget),
                  matching: find.byWidgetPredicate(
                    (w) => w is SizedBox && w.width == 40 && w.height == 40,
                  ),
                )
                .first;
            firstIconTops.add(tester.getTopLeft(box).dy);
          }
          expect(firstIconTops.length, 3);
          for (final y in firstIconTops) {
            expect(y, closeTo(firstIconTops.first, 0.5));
          }
        });
      }
    }
  });
}

Widget _quizShell(
  MockZanKurdRepository repository, {
  required double scale,
  required Size size,
}) {
  return MediaQuery(
    data: MediaQueryData(
      size: size,
      textScaler: TextScaler.linear(scale),
      padding: const EdgeInsets.only(top: 47, bottom: 34),
    ),
    child: testShell(
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => QuizScreen(
                repository: repository,
                room: repository.createRoom(),
                questions: [repository.questions.first],
                experience: QuizExperience.learning,
              ),
            ),
          ),
          child: const Text('aç'),
        ),
      ),
    ),
  );
}
