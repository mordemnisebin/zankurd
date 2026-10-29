import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_fit.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

/// SORU SIĞMA BEKÇİSİ — EK (2026-10-29, Astra kod incelemesi KARAR DÜZELT).
///
/// `soru_sigma_test` soru kartı + şıkların yerini ölçer. Bu dosya onun
/// göremediği DÖRT kaymayı ve bankanın TAMAMINI ölçer:
///  1. alt perde (joker dizisi, çift cevap ipucu, "Süre doldu" şeridi, cevap
///     şeridi) her durumda AYNI yükseklikte;
///  2. seyirci jokeri yüzdesi ve rakip rozetleri şıkkın boyunu değiştirmez,
///     rozetler çubuğun yatay sınırı içinde kalır;
///  3. en uzun konu adları (TR+KU, 1,3× yazı, dar telefon) üst çubukta
///     kırpılmaz;
///  4. bankadaki HER çoktan seçmeli soru 375×667 / 1,0 düello ve oda
///     varyantında `QuizFit.fits == true` verir (sığmayan sayısı 0).

const _s375 = Size(375, 667);

void _yuzey(WidgetTester tester, Size size, {double top = 20}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  final pad = FakeViewPadding(top: top, bottom: size.height > 700 ? 34 : 0);
  tester.view.padding = pad;
  tester.view.viewPadding = pad;
  addTearDown(tester.view.reset);
}

const _uzun = QuizQuestion(
  id: 'ek-1',
  category: 'Ziman',
  prompt:
      'Di rêzimana Kurmancî de peyva «navdêr» ji bo çi tê bikaranîn û di '
      'hevokê de çi erkî dike?',
  promptTr:
      'Dilbilgisinde «isim» sözcüğü ne için kullanılır ve cümlede ne iş görür?',
  answers: [
    'Ji bo navê kes, tişt an cihan tê bikaranîn',
    'Ji bo kirina karekî tê bikaranîn',
    'Ji bo diyarkirina rengê tiştan tê bikaranîn',
    'Ji bo girêdana du hevokan tê bikaranîn',
  ],
  answersTr: [
    'Kişi, nesne ya da yer adı için kullanılır',
    'Bir eylemi yapmak için kullanılır',
    'Nesnelerin rengini belirtmek için kullanılır',
    'İki cümleyi bağlamak için kullanılır',
  ],
  correctAnswer: 'Ji bo navê kes, tişt an cihan tê bikaranîn',
  correctAnswerTr: 'Kişi, nesne ya da yer adı için kullanılır',
  explanation: 'Navdêr navê kes, tişt an cihan e.',
);

GameRoom _oda(bool crowd) => GameRoom(
  id: 'ek-r',
  name: 'Oda',
  code: 'ZK-EK',
  category: 'Ziman',
  status: RoomStatus.active,
  questionCount: 2,
  players: const [
    Player(name: 'Tolhildan Mawal', score: 0, state: 'Hazır'),
    Player(name: 'Rakip Oyuncu', score: 0, state: 'Hazır'),
    Player(name: 'Üçüncü', score: 0, state: 'Hazır'),
    Player(name: 'Dördüncü', score: 0, state: 'Hazır'),
  ],
  maxPlayers: crowd ? 4 : 2,
  isCustom: crowd,
  hostId: 'h',
);

Future<void> _pumpQuiz(
  WidgetTester tester, {
  required bool ku,
  required double scale,
  Size size = _s375,
  QuizQuestion q = _uzun,
  bool solo = true,
  bool is1v1 = false,
  bool crowd = false,
  bool timer = false,
  QuizExperience experience = QuizExperience.competition,
}) async {
  _yuzey(tester, size);
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  final repository = freshMockRepository();
  SharedPreferences.setMockInitialValues({
    'zankurd.quiz_tutorial.seen': true,
    'zankurd.navTour.seen': true,
  });
  await tester.pumpWidget(
    testShell(
      languageProvider: ku ? kurmanciLang() : null,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: QuizScreen(
            repository: repository,
            room: solo ? repository.createRoom() : _oda(crowd),
            questions: [q, q],
            experience: experience,
            is1v1: is1v1,
            enableTimer: timer,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// Alt perdenin AYRILAN yüksekliği; ayrıca içerik bu yükseklikten büyükse
/// (perde sabit kalsa bile içerik kırpılır / taşar) test düşer.
double _dock(WidgetTester tester) {
  final dock = find.byType(QuizStableDockHeight).first;
  final h = tester.getSize(dock).height;
  final content = tester.getSize(
    find.descendant(of: dock, matching: find.byType(Column)).first,
  );
  expect(
    content.height,
    lessThanOrEqualTo(h + 0.5),
    reason: 'alt perde içeriği ayrılan $h pt\'yi aşıyor: ${content.height}',
  );
  return h;
}

List<Rect> _kutular(WidgetTester tester) => [
  for (final e in find.byKey(const ValueKey('quiz-option-base')).evaluate())
    tester.getRect(find.byElementPredicate((x) => x == e)),
  if (find.byKey(const ValueKey('quiz-prompt-card')).evaluate().isNotEmpty)
    tester.getRect(find.byKey(const ValueKey('quiz-prompt-card'))),
];

void _ayni(List<Rect> a, List<Rect> b, String neden) {
  expect(b.length, a.length, reason: '$neden: öğe sayısı');
  for (var i = 0; i < a.length; i++) {
    expect(
      (a[i].top - b[i].top).abs() + (a[i].height - b[i].height).abs(),
      lessThanOrEqualTo(0.5),
      reason: '$neden: öğe $i ${a[i]} → ${b[i]}',
    );
  }
}

Future<void> _yanlisCevapla(WidgetTester tester) async {
  final shown = _uzun.localized(isKu: false, learning: false);
  final i = shown.displayAnswers.indexWhere((a) => a != shown.correctAnswer);
  await tester.tap(
    find.byKey(const ValueKey('quiz-option-base')).at(i),
    warnIfMissed: false,
  );
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);

  // ── 1. Alt perde her durumda aynı yükseklikte ───────────────────────────
  for (final ku in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      final ad = '${ku ? 'KU' : 'TR'} x$scale';

      testWidgets('alt perde sabit: yarış, joker → cevap şeridi ($ad)', (
        tester,
      ) async {
        await _pumpQuiz(tester, ku: ku, scale: scale);
        final h0 = _dock(tester);
        await tester.pump(const Duration(milliseconds: 1200));
        expect(_dock(tester), closeTo(h0, 0.5), reason: 'ilk kare → 1,2 sn');
        final onceler = _kutular(tester);
        await _yanlisCevapla(tester);
        expect(_dock(tester), closeTo(h0, 0.5), reason: 'cevap şeridi');
        expect(tester.takeException(), isNull);
        _ayni(onceler, _kutular(tester), '$ad cevap sonrası');
      });

      testWidgets('alt perde sabit: çift cevap ipucu yuvası ($ad)', (
        tester,
      ) async {
        await _pumpQuiz(tester, ku: ku, scale: scale);
        await tester.pump(const Duration(milliseconds: 600));
        final h0 = _dock(tester);
        final onceler = _kutular(tester);
        // Joker sırası: 50/50, seyirci, çift cevap, değiştir.
        await tester.tap(find.byType(WildcardButton).at(2));
        await tester.pump(const Duration(milliseconds: 300));
        expect(_dock(tester), closeTo(h0, 0.5), reason: 'joker sonrası');
        final shown = _uzun.localized(isKu: ku, learning: false);
        final yanlis = shown.displayAnswers.indexWhere(
          (a) => a != shown.correctAnswer,
        );
        await tester.tap(
          find.byKey(const ValueKey('quiz-option-base')).at(yanlis),
          warnIfMissed: false,
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(_dock(tester), closeTo(h0, 0.5), reason: 'ipucu görünürken');
        expect(tester.takeException(), isNull);
        _ayni(onceler, _kutular(tester), '$ad çift cevap ipucu');
      });

      testWidgets('şık boyları sabit: seyirci jokeri yüzdesi ($ad)', (
        tester,
      ) async {
        await _pumpQuiz(tester, ku: ku, scale: scale);
        await tester.pump(const Duration(milliseconds: 600));
        final onceler = _kutular(tester);
        await tester.tap(find.byType(WildcardButton).at(1));
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.takeException(), isNull);
        _ayni(onceler, _kutular(tester), '$ad seyirci yüzdesi');
      });

      testWidgets('alt perde sabit: süre dolunca "Süre doldu" ($ad)', (
        tester,
      ) async {
        await _pumpQuiz(tester, ku: ku, scale: scale, timer: true);
        await tester.pump(const Duration(milliseconds: 600));
        final h0 = _dock(tester);
        final onceler = _kutular(tester);
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(seconds: 1));
          if (find
              .byKey(const ValueKey('quiz-feedback-wrong'))
              .evaluate()
              .isNotEmpty) {
            break;
          }
        }
        await tester.pump(const Duration(milliseconds: 600));
        expect(
          find.byKey(const ValueKey('quiz-feedback-wrong')),
          findsOneWidget,
          reason: 'süre doldu şeridi',
        );
        expect(_dock(tester), closeTo(h0, 0.5), reason: 'süre doldu şeridi');
        expect(tester.takeException(), isNull);
        // Süre dolunca zaman aşımı bildirimi gövdeye eklenir (gerçek içerik);
        // soru kartı ve şıklar yine yerinde.
        final sonra = _kutular(tester);
        expect(sonra.length, onceler.length);
        for (var i = 0; i < sonra.length; i++) {
          expect(sonra[i].top, closeTo(onceler[i].top, 0.5));
        }
      });

      for (final (ad2, is1v1, crowd) in [
        ('düello', true, false),
        ('oda', false, true),
      ]) {
        testWidgets('alt perde sabit: $ad2 bekleme etiketi ($ad)', (
          tester,
        ) async {
          await _pumpQuiz(
            tester,
            ku: ku,
            scale: scale,
            solo: false,
            is1v1: is1v1,
            crowd: crowd,
          );
          await tester.pump(const Duration(milliseconds: 1200));
          final h0 = _dock(tester);
          final onceler = _kutular(tester);
          await _yanlisCevapla(tester);
          expect(_dock(tester), closeTo(h0, 0.5), reason: '$ad2 bekleme');
          expect(tester.takeException(), isNull);
          _ayni(onceler, _kutular(tester), '$ad $ad2 cevap sonrası');
        });
      }
    }
  }

  // ── 2. Rozetler çubuğun boyunu değiştirmez, çubuktan taşmaz ─────────────
  testWidgets('şık rozetleri: yüzde + uzun rakip adları boyu değiştirmez', (
    tester,
  ) async {
    _yuzey(tester, _s375);
    Widget kolon({double? yuzde, List<String>? adlar}) => testShell(
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
          child: Column(
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: QuizOptionTile(
                    key: ValueKey('t$i'),
                    index: i,
                    answer: 'Ji bo navê kes, tişt an cihan tê bikaranîn $i',
                    selected: false,
                    correct: false,
                    disabled: false,
                    onTap: () {},
                    audiencePercent: i == 1 ? yuzde : null,
                    opponentNamesWhoSelected: i == 2 ? adlar : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(kolon());
    await tester.pump();
    final onceler = [
      for (var i = 0; i < 4; i++) tester.getRect(find.byKey(ValueKey('t$i'))),
    ];
    await tester.pumpWidget(
      kolon(
        yuzde: 0.42,
        adlar: const [
          'Tolhildan Mawal Ezîzo',
          'Rakip Oyuncu Uzun Ad',
          'Üçüncü Oyuncu Adı',
        ],
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    for (var i = 0; i < 4; i++) {
      final r = tester.getRect(find.byKey(ValueKey('t$i')));
      expect(r.height, closeTo(onceler[i].height, 0.5), reason: 'şık $i boyu');
      expect(r.top, closeTo(onceler[i].top, 0.5), reason: 'şık $i yeri');
    }
    // Rozetler çubuğun yatay sınırında kalır.
    final tile = tester.getRect(find.byKey(const ValueKey('t2')));
    for (final e in find.byType(Flexible).evaluate()) {
      final rb = e.renderObject;
      if (rb is! RenderBox || !rb.hasSize) continue;
      final box = rb.localToGlobal(Offset.zero) & rb.size;
      if ((box.top - tile.top).abs() < 12 && box.height < 30) {
        expect(box.left, greaterThanOrEqualTo(tile.left - 0.5));
        expect(box.right, lessThanOrEqualTo(tile.right + 0.5));
      }
    }
  });

  // ── 3. Konu adları üst çubukta kırpılmaz ────────────────────────────────
  testWidgets('üst çubuk: en uzun konu adları kırpılmaz (TR+KU, 1,3×)', (
    tester,
  ) async {
    const kategoriler = [
      'Ziman',
      'Çand',
      'Dîrok',
      'Edebiyat',
      'Cografya',
      'Muzîk',
      'Siyaset',
      'Paradigma',
      'Teknolojî',
      'Sînema',
      'Cîhan',
      'Tevlihev',
    ];
    for (final ku in [false, true]) {
      for (final size in const [Size(320, 568), _s375]) {
        for (final kat in kategoriler) {
          final q = QuizQuestion(
            id: 'kat-$kat',
            category: kat,
            prompt: 'Kurt soru?',
            promptTr: 'Kısa soru?',
            answers: const ['A', 'B', 'C', 'D'],
            correctAnswer: 'A',
            explanation: 'x',
          );
          await _pumpQuiz(tester, ku: ku, scale: 1.3, size: size, q: q);
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull, reason: '$kat taşma');
          for (final e in find.byType(RichText).evaluate()) {
            final r = e.renderObject;
            if (r is RenderParagraph && r.didExceedMaxLines) {
              fail(
                '${ku ? 'KU' : 'TR'} ${size.width.toInt()} $kat: '
                '"${r.text.toPlainText()}" kırpıldı',
              );
            }
          }
        }
      }
    }
  });

  // ── 4. Bankanın TAMAMI: sığmayan sayısı 0 ───────────────────────────────
  testWidgets('banka taraması: her soru 375×667 @1,0 düello/oda sığar', (
    tester,
  ) async {
    final rows = <Map<String, dynamic>>[];
    for (final f in Directory('assets/data').listSync().whereType<File>()) {
      if (!f.path.endsWith('.json')) continue;
      Object? d;
      try {
        d = jsonDecode(f.readAsStringSync());
      } catch (_) {
        continue;
      }
      if (d is Map) d = d['questions'] ?? d['items'];
      if (d is! List) continue;
      for (final r in d) {
        if (r is Map<String, dynamic> &&
            r['prompt'] is String &&
            r['answers'] is List &&
            (r['answers'] as List).length >= 3 &&
            (r['type'] ?? 'multipleChoice') == 'multipleChoice') {
          rows.add(r);
        }
      }
    }
    expect(rows.length, greaterThan(3000), reason: 'banka okunamadı');

    final sigmayan = <String, List<String>>{};
    for (final (ad, is1v1, crowd) in [
      ('düello', true, false),
      ('oda', false, true),
    ]) {
      await _pumpQuiz(
        tester,
        ku: false,
        scale: 1.0,
        solo: false,
        is1v1: is1v1,
        crowd: crowd,
        q: const QuizQuestion(
          id: 'tara',
          category: 'Ziman',
          prompt: 'Kurt?',
          promptTr: 'Kısa?',
          answers: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          explanation: 'x',
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));
      final scroll = tester.getRect(
        find.byKey(const ValueKey('quiz-portrait-scroll')),
      );
      final kart = tester.getRect(
        find.byKey(const ValueKey('quiz-prompt-card')),
      );
      // Soru bloğunun ÜSTÜNDEKİ bantlar (skor kartı + aralık), 16'lık
      // nominal üst boşluk düşülmüş.
      final above = kart.top - scroll.top - 16;
      // ignore: avoid_print
      print('ABOVE $ad $above scroll=${scroll.height}');
      final context = tester.element(find.byType(QuizScreen));
      for (final ku in [false, true]) {
        for (final r in rows) {
          final prompt = ku
              ? r['prompt'] as String
              : ((r['promptTr'] ?? r['prompt']) as String);
          final answers = ku
              ? [for (final a in r['answers'] as List) '$a']
              : [
                  for (final a in (r['answersTr'] ?? r['answers']) as List)
                    '$a',
                ];
          final fit = QuizFit.choose(
            context: context,
            prompt: prompt,
            answers: answers,
            width: 343,
            available: scroll.height - above,
            listenButton: false,
            titleLineBudget: QuizQuestionPrompt.maxTitleLines - 1,
            short: true,
          );
          if (!fit.fits) {
            sigmayan
                .putIfAbsent('$ad ${ku ? 'KU' : 'TR'}', () => [])
                .add('${r['id']} (${prompt.length} kr)');
          }
        }
      }
    }
    expect(
      sigmayan,
      isEmpty,
      reason:
          'Sığmayan sorular (kademe tükendi): '
          '${sigmayan.map((k, v) => MapEntry(k, v.take(5).toList()))}',
    );
  });
}
