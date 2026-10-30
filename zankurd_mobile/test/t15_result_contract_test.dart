import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/quiz_reward_settlement_service.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const _captureDir = String.fromEnvironment('T15_CAPTURE_DIR');
const _phase = String.fromEnvironment('T15_PHASE', defaultValue: 'sonra');
final _captureKey = GlobalKey();

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File(
      '$_captureDir/${name.replaceFirst('_', '_${_phase}_')}.png',
    ).writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _pumpResult(
  WidgetTester tester, {
  required bool crowd,
  required bool win,
  bool ku = false,
  double scale = 1,
  double width = 402,
  bool mixed = false,
}) async {
  tester.view.physicalSize = Size(width, 874);
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
  tester.view.viewPadding = const FakeViewPadding(top: 59, bottom: 34);
  addTearDown(tester.view.reset);
  final repo = freshMockRepository();
  final players = [
    Player(
      id: 'user',
      name: 'Azad',
      score: win ? 422 : 0,
      rank: win ? 1 : 2,
      state: '',
    ),
    Player(
      id: 'opp',
      name: 'Cano',
      score: win ? 151 : 422,
      rank: win ? 2 : 1,
      state: '',
    ),
    if (crowd) ...const [
      Player(id: 'third', name: 'Dilan', score: 0, rank: 2, state: ''),
      Player(id: 'fourth', name: 'Bero', score: 0, rank: 2, state: ''),
    ],
  ];
  await tester.pumpWidget(
    testShell(
      reducedMotion: true,
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(
            key: _captureKey,
            child: QuizResultScreen(
              repository: repo,
              room: GameRoom(
                id: 't15-${crowd ? 'room' : 'duel'}',
                name: 'T15',
                code: 'T15',
                category: 'Ziman',
                questionCount: 10,
                maxPlayers: crowd ? 4 : 2,
                isCustom: crowd,
                status: RoomStatus.finished,
                players: players,
              ),
              resultOwnerUserId: 'user',
              rewardSettlementState: QuizRewardSettlementState.claimed,
              score: win ? 422 : 0,
              correctCount: win ? 3 : 0,
              wrongCount: win ? 0 : 1,
              totalQuestions: 10,
              bestStreak: win ? 3 : 0,
              coinsAwarded: 20,
              opponents: players.skip(1).toList(),
              answerRecords: [
                for (var i = 0; i < 10; i++)
                  AnswerRecord(
                    id: 't15-$i',
                    category: mixed && i >= 3 ? 'Dîrok' : 'Ziman',
                    prompt: 'Pirs $i',
                    answers: const ['A', 'B'],
                    correctAnswer: 'A',
                    selectedAnswer: i < 3 && win
                        ? 'A'
                        : i == 0
                        ? 'B'
                        : null,
                    explanation: '',
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await (FontLoader(
      'Lucide',
    )..addFont(rootBundle.load('assets/fonts/Lucide.ttf'))).load();
  });
  testWidgets(
    'T17 sıralama sınırdaki satırı yarım göstermez; kaydırınca bütünü görünür',
    (tester) async {
      await _pumpResult(tester, crowd: true, win: false, ku: true);
      final last = find.text('Bero');
      final row = find
          .ancestor(of: last, matching: find.byType(SahneListRow))
          .first;
      final scroll = find.byType(Scrollable).first;
      final state = tester.state<ScrollableState>(scroll);
      final viewport = tester.getRect(scroll);
      state.position.jumpTo(
        state.position.pixels +
            tester.getRect(row).bottom -
            viewport.bottom -
            8,
      );
      await tester.pumpAndSettle();
      expect(
        last.hitTestable(),
        findsNothing,
        reason: 'alt sınırdaki yarım satır gösterilmemeli',
      );
      state.position.jumpTo(state.position.pixels + 32);
      await tester.pumpAndSettle();
      expect(last.hitTestable(), findsOneWidget);
      expect(tester.getRect(row).bottom, lessThanOrEqualTo(viewport.bottom));
    },
  );

  testWidgets('T17 sıralama alt eylem alanında solmaz, son satıra kayılır', (
    tester,
  ) async {
    await _pumpResult(tester, crowd: true, win: false, ku: true);
    expect(find.byKey(const ValueKey('sahne-stage-dock-fade')), findsNothing);
    final last = find.text('Bero');
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(last, 200, scrollable: scroll);
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    final viewport = tester.getRect(scroll);
    expect(tester.getRect(last).bottom, lessThanOrEqualTo(viewport.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('T16 S1: geniş KU doğruluk etiketi parıltıyla örtüşmez', (
    tester,
  ) async {
    await _pumpResult(tester, crowd: true, win: true, ku: true);
    final caption = tester.getRect(find.textContaining('Di 10 pirsan de'));
    final sparkles = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_Sparkle',
    );
    expect(sparkles, findsWidgets);
    for (final sparkle in sparkles.evaluate()) {
      expect(
        tester.getRect(find.byWidget(sparkle.widget)).overlaps(caption),
        isFalse,
      );
    }
  });
  testWidgets('T16: Sen avatarı gerçek oyuncu adını korur', (tester) async {
    await _pumpResult(tester, crowd: false, win: true);
    final scroll = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(PlayerAvatar).last,
      400,
      scrollable: scroll,
    );
    final avatars = tester.widgetList<PlayerAvatar>(find.byType(PlayerAvatar));
    expect(avatars.where((a) => a.displayName == 'Sen'), isEmpty);
    expect(avatars.where((a) => a.displayName == 'Azad'), isNotEmpty);
  });
  testWidgets(
    'T16: oda ayrıntı başlığı cevaplanan konu sayısına bağlı değildir',
    (tester) async {
      await _pumpResult(tester, crowd: true, win: true, mixed: true);
      final section = find.byKey(const ValueKey('result-details-section'));
      await tester.scrollUntilVisible(
        section,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<ResultCollapsibleSection>(section).title,
        'Ayrıntılar',
      );
      await _pumpResult(tester, crowd: true, win: false, mixed: true);
      await tester.scrollUntilVisible(
        section,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<ResultCollapsibleSection>(section).title,
        'Ayrıntılar',
      );
    },
  );
  testWidgets('T16: sonuç doğruluğu toplam soru paydasını açıklar', (
    tester,
  ) async {
    await _pumpResult(tester, crowd: false, win: true);
    expect(find.text('10 soruda %30 doğruluk'), findsOneWidget);
  });
  for (final crowd in [false, true]) {
    for (final win in [false, true]) {
      for (final ku in [false, true]) {
        final scene =
            '${crowd ? 'oda' : 'duello'}_${win ? 'kazanan' : 'kaybeden'}_${ku ? 'KU' : 'TR'}';
        testWidgets('S1–S6 S15 sonuç ilk görünümü $scene', (tester) async {
          await _pumpResult(tester, crowd: crowd, win: win, ku: ku);
          for (final s in [1, 2, 3, 4, 5, 6, if (crowd && !win) 15]) {
            await _capture(tester, 'S${s}_$scene');
          }
          final hero = tester.widget<SahneResultHero>(
            find.byType(SahneResultHero),
          );
          final stats = tester.widget<SahneResultStats>(
            find.byType(SahneResultStats),
          );
          expect(
            stats.stats.where((s) => s.visible),
            hasLength(4),
            reason: 'S4 sıfır seri/boş dahil dört metrik',
          );
          final labels = stats.stats.map((s) => find.text(s.label)).toList();
          final rects = labels
              .map(
                (label) => tester.getRect(
                  find
                      .ancestor(of: label, matching: find.byType(DecoratedBox))
                      .first,
                ),
              )
              .toList();
          expect(rects[0].top, closeTo(rects[1].top, .1));
          expect(rects[2].top, closeTo(rects[3].top, .1));
          expect(rects[2].top, greaterThan(rects[0].bottom));
          for (final label in labels) {
            expect(
              tester.widget<Text>(label).style!.fontSize,
              greaterThanOrEqualTo(14),
            );
          }
          for (var i = 0; i < labels.length; i++) {
            final tile = find
                .ancestor(of: labels[i], matching: find.byType(DecoratedBox))
                .first;
            final background =
                (tester.widget<DecoratedBox>(tile).decoration
                        as ShapeDecoration)
                    .color!;
            final foreground = tester.widget<Text>(labels[i]).style!.color!;
            final luminances = [
              background.computeLuminance(),
              foreground.computeLuminance(),
            ]..sort();
            expect(
              (luminances.last + .05) / (luminances.first + .05),
              greaterThanOrEqualTo(4.5),
              reason: 'S1 ${stats.stats[i].label} normal metin kontrastı',
            );
          }
          final clip = find.byKey(const ValueKey('result-celebration-clip'));
          if (clip.evaluate().isNotEmpty) {
            expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
            expect(
              tester.getRect(clip).bottom,
              lessThanOrEqualTo(
                tester.getRect(find.byType(ResultStatTiles)).top,
              ),
            );
          }
          for (final decoration in tester.widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(ResultStatTiles),
              matching: find.byType(DecoratedBox),
            ),
          )) {
            final shape = decoration.decoration;
            if (shape is ShapeDecoration) {
              expect(
                shape.color!.a,
                1,
                reason: 'S1 yıldızlar sayım zemininden geçemez',
              );
            }
          }
          if (!crowd) {
            expect(
              hero.value,
              isNull,
              reason: 'S2 kişisel dev puan tekrarlanmaz',
            );
            expect(hero.subtitle, isNull);
            final comparison = find.byKey(
              const ValueKey('result-duel-score-comparison'),
            );
            expect(comparison, findsOneWidget);
            expect(
              find.descendant(
                of: comparison,
                matching: find.text(ku ? 'Tu' : 'Sen'),
              ),
              findsOneWidget,
            );
            expect(
              find.descendant(of: comparison, matching: find.text('Cano')),
              findsOneWidget,
            );
            expect(
              find.descendant(
                of: comparison,
                matching: find.text(ku ? 'pûan' : 'puan'),
              ),
              findsNWidgets(2),
            );
            final mine = tester.widget<Text>(
              find.byKey(const ValueKey('result-duel-score-me')),
            );
            final theirs = tester.widget<Text>(
              find.byKey(const ValueKey('result-duel-score-opponent')),
            );
            expect(mine.style, theirs.style);
            final header = tester.widget<SahneResultScaffold>(
              find.byType(SahneResultScaffold),
            );
            if (!ku) {
              expect(header.contextLabel, 'Canlı düello · Dil · 10 soru');
            }
          }
          expect(hero.caption, contains(ku ? 'rastbûn' : 'doğruluk'));
          expect(find.textContaining('= XP'), findsNothing);
          expect(find.text('+0 XP'), findsNothing);
          if (win) expect(find.text('+422 XP'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('result-level-journey-progress')),
            findsOneWidget,
          );
          final rows = find.byType(SahneListRow);
          final viewport = tester.getRect(find.byType(ListView).first);
          expect(
            tester.getRect(rows.first).bottom,
            lessThanOrEqualTo(viewport.bottom - 8),
            reason: 'S5 ilk sıra tümüyle görünür',
          );
          if (crowd && !win) {
            expect(
              hero.caption,
              contains(
                ku
                    ? '4 lîstikvanan'
                    : '4 oyuncu arasında 2. sırayı 3 kişi paylaştınız.',
              ),
            );
            expect(
              find.byKey(const ValueKey('result-score-unit')),
              findsOneWidget,
            );
            expect(hero.value, 0);
          }
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -2500),
          );
          await tester.pumpAndSettle();
          await _capture(tester, 'S5_${scene}_liste_sonu');
          expect(
            tester.getRect(rows.last).top,
            greaterThanOrEqualTo(viewport.top),
          );
          expect(
            tester.getRect(rows.last).bottom,
            lessThan(tester.getRect(find.byType(SahneResultDock)).top),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('S1 hareketli kutlamanın hiçbir karesi sayım alanına ulaşamaz', (
    tester,
  ) async {
    freshMockRepository();
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: RepaintBoundary(
          key: _captureKey,
          child: SahneResultScaffold(
            neutral: true,
            hero: const SahneResultHero(
              emblem: SahneResultEmblem.win(),
              title: 'Kazandın!',
              value: 422,
              valueLabel: 'puan',
              celebrate: true,
            ),
            stats: const ResultStatTiles(
              fourStats: true,
              compact: true,
              correct: 3,
              wrong: 0,
              unanswered: 7,
              streak: 3,
            ),
            primary: SahneResultAction(label: 'Tekrar oyna', onPressed: () {}),
          ),
        ),
      ),
    );
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      final clip = find.byKey(const ValueKey('result-celebration-clip'));
      expect(tester.widget<ClipRect>(clip).clipBehavior, Clip.hardEdge);
      expect(
        tester.getRect(clip).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(ResultStatTiles)).top),
      );
      if (frame == 10 || frame == 25) {
        await _capture(tester, 'S1_animasyon_${frame * 50}ms');
      }
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });
  for (final crowd in [false, true]) {
    testWidgets('S4 S15 dar ekran büyük yazı crowd=$crowd', (tester) async {
      await _pumpResult(
        tester,
        crowd: crowd,
        win: false,
        ku: true,
        scale: 2,
        width: 360,
      );
      await _capture(tester, 'S4_buyuk_yazi_${crowd ? 'oda' : 'duello'}');
      if (crowd) await _capture(tester, 'S15_buyuk_yazi_oda');
      final stats = tester.widget<SahneResultStats>(
        find.byType(SahneResultStats),
      );
      expect(stats.stats.where((s) => s.visible), hasLength(4));
      for (final s in stats.stats) {
        expect(tester.widget<Text>(find.text(s.label)).maxLines, isNull);
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
