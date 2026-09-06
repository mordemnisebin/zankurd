import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// QuizScreen responsive yerleşim bekçisi — ZKR-P1-001.
///
/// Niçin var: `quiz_screen.dart` yerleşim dalını `constraints.maxWidth >= 700`
/// ile seçiyordu. Değişkenin adı `landscape` idi ama gerçek yönelim hiç
/// ölçülmüyordu. Sonuç: 700px'ten geniş **her** viewport — bütün masaüstü
/// tarayıcılar ve *dikey* tabletler dahil — telefon-yatay için tasarlanmış iki
/// sütunlu düzene düşüyordu. O düzende sağ sütun `CrossAxisAlignment.start`
/// ile tepeye yapıştığı için birincil "devam" düğmesi şıkların 130px kadar
/// *üstünde* ve 390px kadar sağında kalıyor, ekranın altında ~790px boşluk
/// kalıyordu (2026-07-31 denetimi, 1440×900 ölçümü).
///
/// Bu dosya niyeti değil geometriyi ölçer: hangi yerleşim dalının seçildiğini
/// sabit anahtarlardan, CTA ile son şıkkın ilişkisini ise gerçek `Rect`
/// değerlerinden okur. Çevrilmiş arayüz metnine hiç bakmaz — düğme
/// `ValueKey('quiz-next-button')`, şıklar `QuizOptionTile` tipiyle bulunur.
void main() {
  // Kısa metinler bilerek: bu dosyanın konusu içerik taşması değil, yerleşim
  // dalı ve CTA konumu. Uzun metin ölçüsü TEST H'de ayrıca zorlanıyor.
  const question = QuizQuestion(
    id: 'resp-q1',
    category: 'Ziman',
    prompt: 'Pîr ne demektir?',
    answers: ['Yaşlı', 'Genç', 'Hızlı', 'Yavaş'],
    correctAnswer: 'Yaşlı',
    explanation: 'Pîr yaşlı demektir.',
  );
  const question2 = QuizQuestion(
    id: 'resp-q2',
    category: 'Ziman',
    prompt: 'Kanî ne demektir?',
    answers: ['Pınar', 'Dağ', 'Deniz', 'Ova'],
    correctAnswer: 'Pınar',
    explanation: 'Kanî pınar demektir.',
  );

  /// Yerleşim dalını doğrudan gösteren sabit anahtarlar (üretim kodunda zaten
  /// var; bu test için yeni anahtar eklenmedi).
  const stackedScrollKey = ValueKey('quiz-portrait-scroll');
  const compactLandscapeKey = ValueKey('quiz-landscape-content');
  const primaryCtaKey = ValueKey('quiz-next-button');

  Future<void> pumpQuizAt(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: QuizScreen(
              repository: repository,
              room: repository.createRoom(),
              questions: const [question, question2],
              enableTimer: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Gerçek kullanıcı akışı: bir şık seçilir, reveal olur ve CTA etkin duruma
  /// gelir. Üretim state'ini zorlayan test-only bayrak kullanılmıyor.
  Future<void> answerFirstQuestion(WidgetTester tester) async {
    final option = find.text(question.correctAnswer).first;
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Finder lastOption() => find.byType(QuizOptionTile).last;
  Finder cta() => find.byKey(primaryCtaKey);

  /// Stacked dalda şıklar kaydırılabilir alanda, CTA ise sabit alt barda.
  /// Küçük ekranlarda son şık görünür alanın altında kalabileceği için
  /// ölçümden önce görünür hale getirilir — aksi halde ölçülen `Rect` hiç
  /// çizilmemiş bir konumu gösterirdi.
  Future<void> revealLastOption(WidgetTester tester) async {
    await tester.ensureVisible(lastOption());
    await tester.pumpAndSettle();
  }

  /// İki dikdörtgen gerçekten üst üste biniyor mu (sıfır olmayan alanla).
  bool overlaps(Rect a, Rect b) => a.overlaps(b);

  /// Bütün şıkların kapladığı toplam alan.
  ///
  /// Tek bir karo yerine birleşim ölçülüyor, çünkü şıklar yeterli genişlikte
  /// **iki sütunlu bir ızgaraya** diziliyor: "son şık" sağ sütundaki alt karo
  /// olur ve tek başına içerik sütununun yalnız sağ yarısını kaplar. Doğru
  /// referans, cevap bloğunun bütünüdür.
  Rect answerBlockRect(WidgetTester tester) {
    final rects = <Rect>[
      for (
        var i = 0;
        i < tester.widgetList(find.byType(QuizOptionTile)).length;
        i++
      )
        tester.getRect(find.byType(QuizOptionTile).at(i)),
    ];
    expect(rects, isNotEmpty, reason: 'en az bir cevap şıkkı bulunmalı');
    return rects.reduce((a, b) => a.expandToInclude(b));
  }

  /// Stacked yerleşimin iki geometri sözleşmesi.
  void expectStackedGeometry(WidgetTester tester, String label) {
    final answers = answerBlockRect(tester);
    final ctaRect = tester.getRect(cta());

    // 1) CTA bütün şıkların ALTINDA — okuma akışının sonunda.
    expect(
      ctaRect.top,
      greaterThanOrEqualTo(answers.bottom),
      reason:
          '$label: birincil CTA bütün şıkların altında olmalı. '
          'cta.top=${ctaRect.top}, answers.bottom=${answers.bottom}',
    );

    // 2) CTA aynı içerik sütununda — sağ üstte ayrı bir sütuna kopmamış.
    //    Hem merkez kontrolü hem de anlamlı yatay örtüşme aranıyor: yalnız
    //    merkez kontrolü, CTA'nın cevap bloğunun kenarına sıkışmış dar bir
    //    şerit olduğu durumu kaçırırdı.
    expect(
      ctaRect.center.dx,
      inInclusiveRange(answers.left, answers.right),
      reason:
          '$label: CTA merkezi cevap bloğunun yatay alanında olmalı. '
          'cta.center.dx=${ctaRect.center.dx}, '
          'answers=[${answers.left}, ${answers.right}]',
    );

    final overlapWidth =
        (ctaRect.right < answers.right ? ctaRect.right : answers.right) -
        (ctaRect.left > answers.left ? ctaRect.left : answers.left);
    expect(
      overlapWidth,
      greaterThanOrEqualTo(ctaRect.width * 0.9),
      reason:
          '$label: CTA yatayda cevap bloğuyla neredeyse tümüyle örtüşmeli '
          '(aynı içerik sütunu). örtüşme=$overlapWidth, cta.width=${ctaRect.width}',
    );
  }

  void expectNoLayoutException(WidgetTester tester, String label) {
    expect(
      tester.takeException(),
      isNull,
      reason: '$label: yerleşim istisnası (ör. RenderFlex overflow) oluşmamalı',
    );
  }

  /// Stacked dalda ortak doğrulama gövdesi.
  Future<void> expectStackedLayout(
    WidgetTester tester,
    Size size,
    String label, {
    double textScale = 1.0,
  }) async {
    await pumpQuizAt(tester, size, textScale: textScale);
    expect(
      find.byKey(stackedScrollKey),
      findsOneWidget,
      reason: '$label: stacked (dikey) yerleşim dalı seçilmeliydi',
    );
    expect(
      find.byKey(compactLandscapeKey),
      findsNothing,
      reason: '$label: telefon-yatay iki sütunlu dala girilmemeliydi',
    );

    await answerFirstQuestion(tester);
    await revealLastOption(tester);

    expect(cta(), findsOneWidget, reason: '$label: birincil CTA bulunmalı');
    expectStackedGeometry(tester, label);
    expectNoLayoutException(tester, label);
  }

  // ── TEST A — dikey tablet ──────────────────────────────────────────────
  testWidgets('A · 768×1024 dikey tablet stacked yerleşim kullanır', (
    tester,
  ) async {
    await expectStackedLayout(tester, const Size(768, 1024), '768×1024');
  });

  // ── TEST B — masaüstü ──────────────────────────────────────────────────
  testWidgets('B · 1440×900 masaüstü stacked yerleşim kullanır', (
    tester,
  ) async {
    await expectStackedLayout(tester, const Size(1440, 900), '1440×900');
  });

  // ── TEST C — tablet yatay (kısa değil) ─────────────────────────────────
  testWidgets('C · 1024×768 tablet-yatay stacked yerleşim kullanır', (
    tester,
  ) async {
    await expectStackedLayout(tester, const Size(1024, 768), '1024×768');
  });

  // ── TEST G — geniş masaüstü ────────────────────────────────────────────
  testWidgets('G · 1920×1080 geniş masaüstü stacked yerleşim kullanır', (
    tester,
  ) async {
    await expectStackedLayout(tester, const Size(1920, 1080), '1920×1080');

    // İçerik kontrolsüz biçimde tüm ekrana yayılmamalı: mevcut max-width
    // sistemi (800px içerik adası) korunuyor.
    final answers = answerBlockRect(tester);
    expect(
      answers.width,
      lessThanOrEqualTo(820.0),
      reason:
          '1920×1080: cevap bloğu mevcut max-width sınırını aşmamalı '
          '(ölçülen ${answers.width})',
    );
    expect(
      tester.getRect(cta()).width,
      lessThanOrEqualTo(820.0),
      reason: '1920×1080: CTA de aynı içerik adası içinde kalmalı',
    );
  });

  // ── TEST E — telefon dikey (regresyon) ─────────────────────────────────
  testWidgets('E · 390×844 telefon-dikey davranışı korunur', (tester) async {
    await expectStackedLayout(tester, const Size(390, 844), '390×844');
  });

  // ── TEST F — küçük telefon ─────────────────────────────────────────────
  testWidgets('F · 320×568 küçük telefonda CTA erişilebilir, taşma yok', (
    tester,
  ) async {
    await pumpQuizAt(tester, const Size(320, 568));
    expect(find.byKey(stackedScrollKey), findsOneWidget);

    await answerFirstQuestion(tester);

    // CTA sabit alt barda: küçük ekranda da viewport içinde kalmalı.
    final ctaRect = tester.getRect(cta());
    expect(ctaRect.top, greaterThanOrEqualTo(0.0));
    expect(
      ctaRect.bottom,
      lessThanOrEqualTo(568.0),
      reason: '320×568: CTA viewport dışına taşmamalı',
    );

    // Şıklar kaydırma ile ulaşılabilir olmalı.
    await revealLastOption(tester);
    expectStackedGeometry(tester, '320×568');
    expectNoLayoutException(tester, '320×568');
  });

  // ── TEST D — gerçek telefon-yatay (korunmalı) ──────────────────────────
  testWidgets('D · 844×390 telefon-yatay compact landscape dalını korur', (
    tester,
  ) async {
    await pumpQuizAt(tester, const Size(844, 390));

    expect(
      find.byKey(compactLandscapeKey),
      findsOneWidget,
      reason: '844×390 gerçek kısa-yatay: compact landscape dalı korunmalı',
    );
    expect(find.byKey(stackedScrollKey), findsNothing);

    await answerFirstQuestion(tester);

    expect(cta(), findsOneWidget, reason: '844×390: CTA kaybolmamalı');
    final ctaRect = tester.getRect(cta());

    // Compact landscape'te CTA sağ sütunda; şıklarla ÇAKIŞMAMALI.
    for (
      var i = 0;
      i < tester.widgetList(find.byType(QuizOptionTile)).length;
      i++
    ) {
      final optionRect = tester.getRect(find.byType(QuizOptionTile).at(i));
      expect(
        overlaps(ctaRect, optionRect),
        isFalse,
        reason: '844×390: CTA $i numaralı şıkla çakışmamalı',
      );
    }

    // Dokunma alanı en az 44×44 logical pixel.
    expect(ctaRect.height, greaterThanOrEqualTo(44.0));
    expect(ctaRect.width, greaterThanOrEqualTo(44.0));

    expectNoLayoutException(tester, '844×390');
  });

  testWidgets('D2 · 932×430 telefon-yatay compact landscape dalını korur', (
    tester,
  ) async {
    await pumpQuizAt(tester, const Size(932, 430));

    expect(find.byKey(compactLandscapeKey), findsOneWidget);
    expect(find.byKey(stackedScrollKey), findsNothing);

    await answerFirstQuestion(tester);

    expect(cta(), findsOneWidget);
    final ctaRect = tester.getRect(cta());
    for (
      var i = 0;
      i < tester.widgetList(find.byType(QuizOptionTile)).length;
      i++
    ) {
      expect(
        overlaps(ctaRect, tester.getRect(find.byType(QuizOptionTile).at(i))),
        isFalse,
        reason: '932×430: CTA $i numaralı şıkla çakışmamalı',
      );
    }
    expect(ctaRect.height, greaterThanOrEqualTo(44.0));
    expectNoLayoutException(tester, '932×430');
  });

  // ── 667×375 — küçük telefon yatay, stacked kalmalı ─────────────────────
  testWidgets('667×375 küçük telefon-yatay iki sütuna zorlanmaz', (
    tester,
  ) async {
    await pumpQuizAt(tester, const Size(667, 375));

    expect(
      find.byKey(compactLandscapeKey),
      findsNothing,
      reason: '667×375: 700px eşiğinin altında, iki sütuna zorlanmamalı',
    );
    expect(find.byKey(stackedScrollKey), findsOneWidget);
    expectNoLayoutException(tester, '667×375');
  });

  testWidgets('700×656 sınırında panel gövde ölçümüyle aynı dalı kullanır', (
    tester,
  ) async {
    // AppBar sonrası gövde yaklaşık 600px'e iner. Dış LayoutBuilder compact
    // seçtiğinde soru paneli de aynı ölçümü kullanmalı; aksi hâlde panel,
    // tam pencere yüksekliği 656px olduğu için stacked görsel kararına döner.
    await pumpQuizAt(tester, const Size(700, 656));

    expect(find.byKey(compactLandscapeKey), findsOneWidget);
    final ghostIcon = tester.widget<Icon>(
      find.byKey(const ValueKey('quiz-question-ghost-icon')),
    );
    expect(ghostIcon.size, 88.0);
    expectNoLayoutException(tester, '700×656');
  });

  // ── 1366×768 masaüstü ──────────────────────────────────────────────────
  testWidgets('1366×768 masaüstü stacked yerleşim kullanır', (tester) async {
    await expectStackedLayout(tester, const Size(1366, 768), '1366×768');
  });

  // ── TEST H — yüksek metin ölçeği ───────────────────────────────────────
  testWidgets('H1 · 390×844 yüksek metin ölçeğinde taşma yok', (tester) async {
    await expectStackedLayout(
      tester,
      const Size(390, 844),
      '390×844 @1.6x',
      textScale: 1.6,
    );
  });

  testWidgets('H2 · 768×1024 yüksek metin ölçeğinde taşma yok', (tester) async {
    await expectStackedLayout(
      tester,
      const Size(768, 1024),
      '768×1024 @1.6x',
      textScale: 1.6,
    );
  });

  testWidgets('H3 · 390×844 @2.0 answer reachability korunur', (tester) async {
    await pumpQuizAt(tester, const Size(390, 844), textScale: 2.0);

    final options = find.byType(QuizOptionTile);
    expect(options, findsNWidgets(4));
    final last = options.last;
    final cta = find.byKey(primaryCtaKey);
    expect(cta, findsOneWidget);

    await tester.ensureVisible(last);
    await tester.pumpAndSettle();

    final viewport = tester.getRect(find.byType(Scaffold));
    final lastRect = tester.getRect(last);
    expect(lastRect.bottom, lessThanOrEqualTo(viewport.bottom));

    final semantics = tester.getSemantics(last);
    expect(semantics.flagsCollection.isButton, isTrue);
    await tester.tap(last, warnIfMissed: false);
    await tester.pump();

    expect(tester.getRect(cta).bottom, lessThanOrEqualTo(viewport.bottom));
    expect(tester.takeException(), isNull);
  });
}
