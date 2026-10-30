// 2026-10-28 JÜRİ K6 / K6+ / K7 / K7+: soru sahnesi, sonuç ve cevaplar ekranı.
//
// ## Kusur
//
// * Soru ekranı her modda başka bir ekran gibiydi: üst bant konunun rengine
//   boyanıyordu (Dil → turkuaz, öğrenme → yeşil), soru metni boş gradyanın
//   ortasında yüzüyor, üstte ekranın üçte biri boş kalıyordu; cevaptan sonra
//   yalnız turuncu bir "Sonraki" vardı.
// * Sonuç ekranı bütün zemini bordoya boyuyordu ("kırmızı = hata" okunuyor,
//   başarı anı kırmızıydı); turuncu "Tekrar oyna" dahil ilk görünümde
//   açıklama listesi ekranı itiyordu.
// * Cevaplar ekranı her karta dört şık + üç satırlık açıklama basıyordu.
//
// ## Niçin sessiz kalırdı
//
// Hiçbiri taşma ya da istisna değildir; her test "soru var, şık var" der.
// Yalnız renk (bant), konum (soru üstü), sayı (turuncu düğme) ve görünürlük
// ölçülürse yakalanır.
//
// ## Geçersiz kılınan eski kararlar
//
// * 2026-10-20 "konu bandı" (kategori renkli üst bant) → kalktı; mod tek
//   küçük çip.
// * 2026-10-20 "şıklar alta oturur, soru boş alanda ortalanır" (anchorHeight)
//   → kalktı; soru ÜSTTEN başlar.
// * 2026-10-20 sonuç sahnesi mod renginde gradyan (Boyax/Zimrût) → nötr
//   sahne.
//
// ## 2026-10-28 TUR 2 (R3 soru sahnesi, R5 sonuç)
//
// * R3: "soru ÜSTTEN başlar" da değişti. Kısa soruda grup başlığa
//   yapışıyor, altta ölü ~%50 kalıyordu (kurul: dört model). Yeni kural:
//   soru + şıklar grubu üst çubuk ile alt perde arasındaki kullanılabilir
//   yüksekliğin %30–55'inde (üst-orta) durur; uzun soruda boşluk sıfırlanır
//   ve alan kayar. Şık ≥ 60; joker ≥ 48 × 48, adı ≥ 11 sp, fiyat/"Ücretsiz"
//   ayrı hap.
// * R5: "Konulara göre" ve "Yeni rozet" katlı (tek satır özet); kutlama
//   ışıması hareket azaltmada durağan; başlık başarıya göre.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/widgets/quiz_stage_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

const _records = [
  AnswerRecord(
    id: 'r1',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek', 'yol', 'dağ'],
    correctAnswer: 'su',
    selectedAnswer: 'su',
    explanation: '«av» Türkçede «su» demektir.',
    explanationKu: '«av» bi Tirkî dibe «su».',
    explanationTr: '«av» Türkçede «su» demektir.',
  ),
  AnswerRecord(
    id: 'r2',
    category: 'Çand',
    prompt: 'Çay li kîjan firaxê tê vexwarin?',
    answers: ['bardak', 'kase', 'sênî', 'beroş'],
    correctAnswer: 'bardak',
    selectedAnswer: 'kase',
    explanation: 'Çay genellikle «bardak» ile içilir.',
    explanationKu: 'Çay bi gelemperî di «bardak»ê de tê vexwarin.',
    explanationTr: 'Çay genellikle «bardak» ile içilir.',
  ),
];

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.quiz_tutorial.seen': true,
      'zankurd.navTour.seen': true,
    });
  });

  Future<void> pumpQuiz(
    WidgetTester tester, {
    QuizExperience experience = QuizExperience.competition,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizScreen(
          repository: repo,
          room: repo.createRoom(),
          questions: repo.questions.take(2).toList(),
          experience: experience,
          enableTimer: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final experience in QuizExperience.values) {
    testWidgets('K6: ${experience.name} sahnesinde konu renkli bant yok, mod '
        'çipi var', (tester) async {
      await pumpQuiz(tester, experience: experience);
      expect(
        find.byKey(const ValueKey('sahne-stage-band')),
        findsNothing,
        reason: 'konu renkli (turkuaz/yeşil) üst bant geri gelmiş',
      );
      expect(
        find.byKey(const ValueKey('sahne-stage-band-floor')),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('quiz-mode-chip')), findsOneWidget);
    });
  }

  for (final experience in [
    QuizExperience.competition,
    QuizExperience.learning,
  ]) {
    testWidgets('R3: ${experience.name} soru+şık grubu kullanılabilir alanın '
        'üst-ortasında (%30–55), açık kartta', (tester) async {
      await pumpQuiz(tester, experience: experience);
      final card = find.byKey(const ValueKey('quiz-prompt-card'));
      expect(card, findsOneWidget);
      final scroll = tester.getRect(
        find.byKey(const ValueKey('quiz-portrait-scroll')),
      );
      final tiles = find.byType(QuizOptionTile);
      final groupTop = tester.getTopLeft(card).dy;
      final groupBottom = tester.getBottomLeft(tiles.last).dy;
      final centre =
          ((groupTop + groupBottom) / 2 - scroll.top) / scroll.height;
      expect(
        centre,
        inInclusiveRange(0.30, 0.55),
        reason: 'grup dikey merkezi %${(centre * 100).round()}',
      );
      // Başlığa yapışık değil, altta ölü yarım ekran da yok.
      expect(groupTop - scroll.top, greaterThanOrEqualTo(16));
      expect(scroll.bottom - groupBottom, lessThan(scroll.height * 0.6));
      // Açık yüzey: koyu sahnede açık kart (yüksek karşıtlık).
      final box = tester.widget<Container>(card);
      final fill = (box.decoration as ShapeDecoration).color!;
      expect(fill.computeLuminance(), greaterThan(0.8));
    });
  }

  testWidgets('R3: şık 60-64, jokerler ≥ 48×48; ad ≥ 11 sp, fiyat ayrı hap', (
    tester,
  ) async {
    await pumpQuiz(tester);
    for (final e in find.byType(QuizOptionTile).evaluate()) {
      final h = tester.getSize(find.byWidget(e.widget)).height;
      expect(h, inInclusiveRange(60, 64));
    }
    final jokers = find.byType(SahneJokerButton);
    expect(jokers, findsWidgets);
    for (final e in jokers.evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    final names = find.byKey(const ValueKey('joker-name'));
    expect(names, findsWidgets);
    for (final e in names.evaluate()) {
      final text = e.widget as Text;
      // U8 (2026-10-28 tur 4): joker adı ≥ 12 sp.
      expect(text.style!.fontSize, greaterThanOrEqualTo(12));
      // Ad küçültülmez: kendi FittedBox'ı yok. Tek istisna alt perdenin
      // kutusu (`QuizStableDockHeight`): hesap doğruysa ölçek 1'dir; sapma
      // `soru_sigma_ek_test`te "içerik ≤ ayrılan yükseklik" ile yakalanır.
      final fitted = find.ancestor(
        of: find.byWidget(text),
        matching: find.byType(FittedBox),
      );
      expect(fitted.evaluate().length, lessThanOrEqualTo(1));
      if (fitted.evaluate().isNotEmpty) {
        expect(
          find.descendant(
            of: find.byType(QuizStableDockHeight),
            matching: find.byWidget(fitted.evaluate().single.widget),
          ),
          findsOneWidget,
        );
      }
    }
    // Fiyat/"Ücretsiz" adın metniyle aynı Text değil, ayrı hap.
    final free = find.byKey(const ValueKey('joker-free-badge'));
    if (free.evaluate().isNotEmpty) {
      final nameRect = tester.getRect(names.first);
      final badgeRect = tester.getRect(free.first);
      expect(badgeRect.top, greaterThanOrEqualTo(nameRect.bottom - 1));
    }
  });

  testWidgets('K6: şıklar ≥ 52 yüksek, aralık 8-12', (tester) async {
    await pumpQuiz(tester);
    final rects = [
      for (final e in find.byType(QuizOptionTile).evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(rects.length, greaterThanOrEqualTo(2));
    for (final r in rects) {
      expect(r.height, greaterThanOrEqualTo(52));
    }
    for (var i = 1; i < rects.length; i++) {
      final gap = rects[i].top - rects[i - 1].bottom;
      expect(gap, inInclusiveRange(8, 12));
    }
  });

  testWidgets('K6+: cevaptan sonra geri bildirim şeridi + Sonraki', (
    tester,
  ) async {
    await pumpQuiz(tester, experience: QuizExperience.learning);
    expect(find.byKey(const ValueKey('quiz-feedback-correct')), findsNothing);
    expect(find.byKey(const ValueKey('quiz-feedback-wrong')), findsNothing);
    // İlk şık.
    await tester.tap(find.byType(QuizOptionTile).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    final strip = find.byWidgetPredicate(
      (w) =>
          w.key == const ValueKey('quiz-feedback-correct') ||
          w.key == const ValueKey('quiz-feedback-wrong'),
    );
    expect(strip, findsOneWidget);
    expect(
      find.descendant(
        of: strip,
        matching: find.byKey(const ValueKey('quiz-next-button')),
      ),
      findsOneWidget,
      reason: '"Sonraki" aynı şeritte olmalı',
    );
  });

  // U6 (2026-10-28 tur 4): geri bildirim şeridindeki eylem turuncu-üstüne-
  // yeşil/kırmızı DEĞİL: beyaz dolgu + şeridin rengiyle yazı, ≥ 4,5:1.
  // Sessizdi: renk çarpışması istisna vermez; yalnız renk ölçülür.
  for (final pickFirst in [true, false]) {
    testWidgets('U6: şerit eylemi beyaz dolgu, turuncu değil '
        '(${pickFirst ? 'ilk' : 'son'} şık)', (tester) async {
      await pumpQuiz(tester, experience: QuizExperience.learning);
      final options = find.byType(QuizOptionTile);
      await tester.tap(pickFirst ? options.first : options.last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      final strip = find.byWidgetPredicate(
        (w) =>
            w.key == const ValueKey('quiz-feedback-correct') ||
            w.key == const ValueKey('quiz-feedback-wrong'),
      );
      expect(strip, findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.descendant(of: strip, matching: find.byType(FilledButton)),
      );
      final fill = button.style!.backgroundColor!.resolve({})!;
      final fg = button.style!.foregroundColor!.resolve({})!;
      final t = SahneTokens.of(tester.element(strip));
      expect(fill, Colors.white);
      expect(fill, isNot(t.act), reason: 'turuncu dolgu şeritte geri geldi');
      double lum(Color c) => c.computeLuminance();
      final hi = lum(fill) > lum(fg) ? lum(fill) : lum(fg);
      final lo = lum(fill) > lum(fg) ? lum(fg) : lum(fill);
      expect((hi + 0.05) / (lo + 0.05), greaterThanOrEqualTo(4.5));
    });
  }

  testWidgets('K7: sonuç nötr sahne, tek turuncu birincil', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repo,
          room: repo.createRoom(),
          score: 240,
          correctCount: 1,
          wrongCount: 1,
          totalQuestions: 2,
          bestStreak: 1,
          coinsAwarded: 30,
          answerRecords: _records,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    // Tam ekran bordo/Boyax gradyanı yok.
    expect(find.byKey(const ValueKey('sahne-stage-scene')), findsNothing);
    final primaries = find.byWidgetPredicate(
      (w) => w is SahneButton && w.isPrimary,
    );
    expect(primaries, findsOneWidget);
    // R5 (2026-10-28 tur 2): konu özeti ve rozetler katlı.
    expect(
      find.byKey(const ValueKey('result-category-learnings')),
      findsNothing,
      reason: '"Konulara göre" varsayılan kapalı olmalı',
    );
    // (Önbellek alanındaki satırlar ekran dışı sayılır: skipOffstage kapalı.)
    // T14 (2026-10-28 tur 3): zorlandın + konulara göre + rozet TEK katlı
    // "Ayrıntılar" bölümünde.
    expect(
      find.byKey(const ValueKey('result-details-section'), skipOffstage: false),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('result-category-section'),
        skipOffstage: false,
      ),
      findsNothing,
      reason: 'kapalıyken içerik kurulmaz',
    );
    // U5 (2026-10-28 tur 4): "Cevapları gör" AYRI düğme değil; cevaplar
    // "Ayrıntılar" katlı satırının içinde. Kapalıyken yok, satır açılınca var.
    expect(find.byKey(const ValueKey('result-see-answers')), findsNothing);
    expect(
      find.byKey(const ValueKey('result-collapsible-header')),
      findsOneWidget,
      reason: 'sonuçta TEK katlı satır (Ayrıntılar + Cevaplar)',
    );
    expect(find.byType(ResultExplanationEntry), findsNothing);
    final toggle = find.byKey(const ValueKey('result-collapsible-header'));
    await tester.scrollUntilVisible(
      toggle,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // Önbellekte kurulan başlık kısmen alt perdenin arkasında olabilir.
    // Gerçek kullanıcının dokunabildiği konuma kaydır ve merkezini doğrula.
    await Scrollable.ensureVisible(tester.element(toggle), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(toggle.hitTestable(), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    expect(find.byType(ResultExplanationEntry), findsWidgets);
  });

  testWidgets('U5: ödül çipleri tonlu (açık altın zemin, altın halka/yazı)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repo,
          room: repo.createRoom(),
          score: 240,
          correctCount: 1,
          wrongCount: 1,
          totalQuestions: 2,
          bestStreak: 1,
          coinsAwarded: 30,
          answerRecords: _records,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    final chips = find.descendant(
      of: find.byType(SahneResultRewards),
      matching: find.byType(SahneStatChip),
    );
    expect(chips, findsWidgets);
    final t = SahneTokens.of(tester.element(chips.first));
    for (final e in chips.evaluate()) {
      final chip = e.widget as SahneStatChip;
      expect(chip.tint, t.goldTint, reason: 'dolu doygun altın çip geri geldi');
      expect(chip.outline, t.gold);
      expect(chip.foreground, t.goldTx);
    }
  });

  testWidgets('R5: katlı bölüm dokununca açılır; ilk görünümde tek birincil', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: QuizResultScreen(
          repository: repo,
          room: repo.createRoom(),
          score: 240,
          correctCount: 2,
          wrongCount: 0,
          totalQuestions: 2,
          bestStreak: 2,
          coinsAwarded: 30,
          answerRecords: _records,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    // İki doğru → üç yıldız → başlık kutlama.
    expect(find.text('Tebrikler!'), findsOneWidget);
    // Kutlama ışıması çizilir. 2026-10-29 vay 2A: ışık TEK odakta —
    // madalyanın ışın diski; puanın arkasındaki ikinci ışıma/parıltı yok
    // (Astra: "madalya, maskot, ışınlar, yıldızlar aynı anda dikkat istiyor").
    expect(find.byKey(const ValueKey('result-ray-disc')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-score-celebration')),
      findsNothing,
    );
    // Skor ve birincil eylem ilk görünümde.
    expect(find.byKey(const ValueKey('result-score-count')), findsOneWidget);
    final play = find.byKey(const ValueKey('result-play-again-button'));
    expect(tester.getBottomLeft(play).dy, lessThanOrEqualTo(844));
    // Katlı başlık ≥ 48 yüksek, dokununca bölüm açılır.
    final header = find.descendant(
      of: find.byKey(const ValueKey('result-details-section')),
      matching: find.byKey(const ValueKey('result-collapsible-header')),
    );
    await tester.scrollUntilVisible(
      header,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.getSize(header.first).height, greaterThanOrEqualTo(48));
    await tester.tap(header.first);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('result-category-learnings')),
      findsOneWidget,
    );
  });

  testWidgets('R5: hareket azaltmada kutlama ışıması baştan durağan', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          disableAnimations: true,
        ),
        child: testShell(
          child: QuizResultScreen(
            repository: repo,
            room: repo.createRoom(),
            score: 240,
            correctCount: 2,
            wrongCount: 0,
            totalQuestions: 2,
            bestStreak: 2,
            coinsAwarded: 30,
            answerRecords: _records,
          ),
        ),
      ),
    );
    await tester.pump();
    // 2026-10-29 vay 2A: kutlama ışığı madalyanın ışın diskidir (hareketsiz);
    // hareket azaltmada konfeti hiç çizilmez, madalya baştan tam boydadır.
    expect(find.byKey(const ValueKey('result-ray-disc')), findsOneWidget);
    expect(find.byKey(const ValueKey('sahne-confetti-burst')), findsNothing);
    final scale = tester.widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byKey(const ValueKey('result-medal')),
            matching: find.byType(ScaleTransition),
          )
          .first,
    );
    expect(scale.scale.value, 1.0);
  });

  testWidgets('K7+: cevaplar kartı yalnız kendi + doğru şıkkı gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = MockZanKurdRepository();
    await tester.pumpWidget(
      testShell(
        child: ReviewScreen(room: repo.createRoom(), records: _records),
      ),
    );
    await tester.pump();
    // r2: seçilen "kase" (yanlış) + doğru "bardak" görünür; öteki şıklar gizli.
    expect(find.text('bardak'), findsOneWidget);
    expect(find.text('kase'), findsOneWidget);
    expect(find.text('sênî'), findsNothing);
    expect(find.text('beroş'), findsNothing);
    // "Tüm şıkları gör" hepsini açar.
    await tester.tap(find.byKey(const ValueKey('review-show-all-r2')));
    await tester.pump();
    expect(find.text('sênî'), findsOneWidget);
  });
}
