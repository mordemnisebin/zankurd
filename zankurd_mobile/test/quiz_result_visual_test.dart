// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

Widget wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

Widget wrapResult(
  Widget child, {
  String language = 'tr',
  double textScale = 1.0,
  bool dark = false,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(
      create: (_) => LanguageProvider()..setLang(language),
    ),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  ),
);

QuizResultScreen buildScreen(MockZanKurdRepository repository) {
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 1840,
    correctCount: 8,
    wrongCount: 2,
    totalQuestions: 10,
    bestStreak: 5,
    coinsAwarded: 120,
    answerRecords: const [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Ev gotin çi wateyê dide?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: 'Rast bersiv A ye.',
      ),
      AnswerRecord(
        id: 'q2',
        category: 'Ziman',
        prompt: 'Kîjan bersiv rast e?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: 'Rast bersiv A ye.',
      ),
      // 2026-10-02: ikinci yanlış BAŞKA bir konuda. Zayıf konu artık yanlışı
      // olan her turda seçilir (eşiğe bağlı değil); kart yalnız o konunun
      // yanlışını açar, "yanlışları incele" yan düğmesi ise HEPSİNİ açar —
      // iki eylem farklı kapsamda olduğu sürece ikisi de görünür. Tek
      // konuda toplanan yanlışlarda yan düğme kartı tekrarlamasın diye
      // gizlenir (bkz. `result_actions_clarity_test.dart`).
      AnswerRecord(
        id: 'q3',
        category: 'Cografya',
        prompt: 'Kîjan çiya herî bilind e?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'C',
        explanation: 'Rast bersiv A ye.',
      ),
    ],
  );
}

QuizResultScreen buildLearningScreen(MockZanKurdRepository repository) {
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 1840,
    correctCount: 8,
    wrongCount: 2,
    totalQuestions: 10,
    bestStreak: 5,
    coinsAwarded: 120,
    isLearningExperience: true,
    answerRecords: const [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Ev gotin çi wateyê dide?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: 'Rast bersiv A ye.',
      ),
      AnswerRecord(
        id: 'q2',
        category: 'Ziman',
        prompt: 'Kîjan bersiv rast e?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: 'Rast bersiv A ye.',
      ),
    ],
  );
}

QuizResultScreen buildPerfectScreen(MockZanKurdRepository repository) {
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 1000,
    correctCount: 10,
    wrongCount: 0,
    totalQuestions: 10,
    bestStreak: 10,
    coinsAwarded: 50,
    answerRecords: const [],
  );
}

class _ResultActionVariant {
  const _ResultActionVariant({
    required this.name,
    required this.language,
    required this.size,
    required this.textScale,
    this.dark = false,
  });

  final String name;
  final String language;
  final Size size;
  final double textScale;
  final bool dark;
}

const _resultActionVariants = [
  _ResultActionVariant(
    name: 'TR 360×800 @1.0',
    language: 'tr',
    size: Size(360, 800),
    textScale: 1.0,
  ),
  _ResultActionVariant(
    name: 'KU 360×800 @1.0',
    language: 'ku',
    size: Size(360, 800),
    textScale: 1.0,
  ),
  _ResultActionVariant(
    name: 'TR 390×844 @1.3',
    language: 'tr',
    size: Size(390, 844),
    textScale: 1.3,
  ),
  _ResultActionVariant(
    name: 'KU 390×844 @1.3',
    language: 'ku',
    size: Size(390, 844),
    textScale: 1.3,
  ),
  _ResultActionVariant(
    name: 'TR 390×844 @2.0',
    language: 'tr',
    size: Size(390, 844),
    textScale: 2.0,
  ),
  _ResultActionVariant(
    name: 'KU 390×844 @2.0 dark',
    language: 'ku',
    size: Size(390, 844),
    textScale: 2.0,
    dark: true,
  ),
];

Future<void> _expectReadablePrimaryNextAction(
  WidgetTester tester,
  _ResultActionVariant variant,
) async {
  await tester.binding.setSurfaceSize(variant.size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository = MockZanKurdRepository();
  await tester.pumpWidget(
    wrapResult(
      buildScreen(repository),
      language: variant.language,
      textScale: variant.textScale,
      dark: variant.dark,
    ),
  );
  await tester.pump(const Duration(seconds: 1));

  final action = find.byKey(const ValueKey('result-play-again-button'));
  // Özet kartı eylemi katmanın altına itti; önce kaydırıp kur, sonra ölç.
  await tester.scrollUntilVisible(action, 600);
  await tester.pumpAndSettle();
  expect(action, findsOneWidget, reason: variant.name);

  final expectedLabel = Tr.forKu(K.playAgain, variant.language == 'ku');
  final buttonSemantics = tester.getSemantics(action);
  expect(buttonSemantics.flagsCollection.isButton, isTrue);
  expect(buttonSemantics.label, contains(expectedLabel), reason: variant.name);

  final label = find.descendant(of: action, matching: find.byType(Text));
  expect(label, findsOneWidget, reason: variant.name);
  final paragraph = tester.renderObject<RenderParagraph>(label);
  expect(
    paragraph.didExceedMaxLines,
    isFalse,
    reason: '${variant.name}: primary CTA label ellipsis olmamalı',
  );
  expect(
    paragraph.text.toPlainText(),
    expectedLabel,
    reason: '${variant.name}: tam lokalize label korunmalı',
  );

  final buttonRect = tester.getRect(action);
  final labelRect = tester.getRect(label);
  expect(buttonRect.contains(labelRect.topLeft), isTrue, reason: variant.name);
  expect(
    buttonRect.contains(labelRect.bottomRight),
    isTrue,
    reason: variant.name,
  );
  expect(buttonRect.height, greaterThanOrEqualTo(54), reason: variant.name);
  expect(tester.takeException(), isNull, reason: variant.name);
}

void main() {
  for (final variant in _resultActionVariants) {
    testWidgets(
      'primary next action readable — ${variant.name}',
      (tester) => _expectReadablePrimaryNextAction(tester, variant),
    );
  }

  testWidgets(
    'perfect result primary replay label and callback are preserved',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrapResult(buildPerfectScreen(MockZanKurdRepository()), textScale: 2.0),
      );
      await tester.pump(const Duration(seconds: 1));

      final action = find.byKey(const ValueKey('result-play-again-button'));
      expect(action, findsOneWidget);
      await tester.ensureVisible(action);
      await tester.pump();
      final label = find.descendant(of: action, matching: find.byType(Text));
      final paragraph = tester.renderObject<RenderParagraph>(label);
      expect(paragraph.text.toPlainText(), 'Tekrar oyna');
      expect(paragraph.didExceedMaxLines, isFalse);
      expect(tester.getRect(action).height, greaterThanOrEqualTo(54));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'öğrenme sonucunda Devam Et ana eylem, yanlış inceleme özette kalır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        wrapResult(buildLearningScreen(MockZanKurdRepository())),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final primary = find.byKey(
        const ValueKey('result-primary-learning-continue'),
      );
      expect(primary, findsOneWidget);
      await tester.ensureVisible(primary);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: primary, matching: find.text('Devam et')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('result-primary-review-mistakes')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('learning-outcome-review')),
        findsOneWidget,
      );

      await tester.tap(primary);
      await tester.pumpAndSettle();
      expect(
        find.byType(ReviewScreen),
        findsNothing,
        reason: 'Devam Et yanlışlar ekranını açmamalı.',
      );
    },
  );

  // 2026-09-29 Şahnê: birincil eylem sahnenin alt perdesinde TEK başına
  // durur; ikincil "yanlışları incele" gövdede, onun üstündedir. Eskiden
  // geniş ekranda ikisi aynı satırdaydı — o yerleşim kalktı. Korunan kural:
  // geniş ekranda iki eylem de ilk bakışta görünür ve birincil ikincilin
  // altında (baş parmağa yakın) kalır.
  testWidgets('wide result keeps primary and secondary actions visible', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrapResult(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));

    final primary = tester.getRect(
      find.byKey(const ValueKey('result-play-again-button')),
    );
    final secondaryFinder = find.byKey(
      const ValueKey('result-review-mistakes-button'),
      skipOffstage: false,
    );
    await tester.ensureVisible(secondaryFinder);
    await tester.pump();
    final secondary = tester.getRect(secondaryFinder);
    expect(primary.bottom, lessThanOrEqualTo(900));
    expect(secondary.bottom, lessThanOrEqualTo(primary.top));
    expect(tester.takeException(), isNull);
  });

  // 2026-09-29 Şahnê: sonuç bir oyun sahnesidir — gündüz temasında da GECE
  // (C iskeleti); vitrinin kendi gradyanı (`Container.decoration`) kalktı.
  // Korunan kural aynı: vitrin eylem turuncusunu kullanmaz ve üstündeki
  // metin perdesiz AA okunur.
  testWidgets('light solo vitrin gündüzde de gece sahnesi taşır', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('result-score-header'));
    expect(header, findsOneWidget);
    final t = SahneTokens.of(tester.element(header));
    expect(t, same(SahneTokens.night), reason: 'sonuç gündüzde de gece');
    double contrast(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
    }

    expect(contrast(t.tx, t.bg), greaterThanOrEqualTo(4.5));
    expect(t.bg, isNot(t.act), reason: 'vitrin eylem turuncusunu kullanmaz');
  });

  // 2026-09-29 Şahnê: birincil eylem alt perdede sabittir — gövdedeki
  // öğrenme özetinden "önce" okunmak için yukarıda durması gerekmez; hiç
  // kaydırmadan ekranda olması yeter. Özet gövdede, perdenin arkasından
  // kayar.
  testWidgets('sonraki durak ana eylemi öğrenme özetinden önce gelir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final primary = find.byKey(const ValueKey('result-play-again-button'));
    final outcome = find.byKey(
      const ValueKey('learning-outcome-card'),
      skipOffstage: false,
    );
    expect(primary, findsOneWidget);
    expect(outcome, findsOneWidget);
    expect(tester.getRect(primary).bottom, lessThanOrEqualTo(844));
    await tester.ensureVisible(outcome);
    await tester.pumpAndSettle();
    expect(
      tester.getRect(primary).bottom,
      lessThanOrEqualTo(844),
      reason: 'özet okunurken de birincil eylem ekranda kalır',
    );
  });

  testWidgets('dar sonuçta öğrenme özeti ikincil eylemlerden önce gelir', (
    tester,
  ) async {
    // 2026-10-02: fixture ikinci bir konu (Cografya) kazandı, kategori listesi
    // uzadı; kart ile yan düğme aynı anda kurulu kalsın diye yükseklik
    // artırıldı (genişlik — "dar" olan — aynı).
    await tester.binding.setSurfaceSize(const Size(390, 1100));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final outcome = find.byKey(const ValueKey('learning-outcome-card'));
    final review = find.byKey(const ValueKey('result-review-mistakes-button'));
    final share = find.byKey(const ValueKey('result-share-button'));
    await tester.scrollUntilVisible(review, 300);
    await tester.pumpAndSettle();
    expect(outcome, findsOneWidget);
    expect(review, findsOneWidget);
    expect(share, findsOneWidget);
    expect(
      tester.getBottomLeft(outcome).dy,
      lessThan(tester.getTopLeft(review).dy),
    );
    expect(
      tester.getBottomLeft(outcome).dy,
      lessThan(tester.getTopLeft(share).dy),
    );
  });

  testWidgets('yanlış varsa sonraki durak ana eylem, inceleme ikincil kalır', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 2026-09-29 Şahnê: birincil alt perdede hep görünür; ikincil eylemler
    // gövdede, kaydırınca görünür (eskiden aynı satırdaydılar).
    final primary = find.byKey(const ValueKey('result-play-again-button'));
    expect(primary, findsOneWidget);
    final review = find.byKey(const ValueKey('result-review-mistakes-button'));
    await tester.scrollUntilVisible(review, 300);
    await tester.pumpAndSettle();
    expect(review, findsOneWidget);
    final more = find.byKey(const ValueKey('result-more-options'));
    await tester.scrollUntilVisible(more, 300);
    await tester.pumpAndSettle();
    expect(more, findsOneWidget);
    expect(find.byKey(const ValueKey('result-home-button')), findsNothing);

    await tester.tap(more);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-home-button')), findsOneWidget);
  });

  // 2026-07-23 M33: Roj maskotu sonuç ekranında görünsün ve yüksek
  // doğrulukta (8/10 = %80) kutlama modunda olsun.
  //
  // 2026-09-29 Şahnê: maskot yok. Kutlama artık puanın arkasındaki sonuç
  // ışınlarıdır ([SahneResultBackdropPainter.rays]); yüksek doğrulukta
  // ışınlar yanar.
  testWidgets('skor başlığı yüksek doğrulukta kutlama ışınlarını yakar', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('result-score-header')),
      findsOneWidget,
      reason: 'M33 eklerken mevcut skor başlığı bozulmamalı',
    );
    final backdrops = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((p) => p.painter)
        .whereType<SahneResultBackdropPainter>();
    expect(backdrops, hasLength(1));
    expect(backdrops.single.rays, isTrue);
  });

  testWidgets('skor vitrini kazanılan XPyi seviye yoluna bağlar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
    await XPStore.loadForTest(0);
    addTearDown(XPStore.resetInstance);

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final journey = find.byKey(const ValueKey('result-level-journey-progress'));
    expect(journey, findsOneWidget);
    expect(
      find.descendant(of: journey, matching: find.textContaining('Seviye ')),
      findsOneWidget,
    );
    // 2026-09-29 Şahnê: seviye yolu Şahnê ilerleme çubuğudur
    // (`SahneProgressBar`, Zêr tonu).
    final progress = tester.widget<SahneProgressBar>(
      find.descendant(of: journey, matching: find.byType(SahneProgressBar)),
    );
    expect(progress.value, inInclusiveRange(0.0, 1.0));
    expect(progress.value, greaterThan(0));
  });

  testWidgets('360 px genişlikte overflow oluşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  for (final size in <Size>[
    const Size(320, 568),
    const Size(844, 390),
    const Size(768, 1024),
    const Size(1440, 900),
  ]) {
    testWidgets('sonuç ${size.width.toInt()}x${size.height.toInt()} taşmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }
}
