import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

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

Future<void> _expectReadablePrimaryReviewAction(
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

  final action = find.byKey(const ValueKey('result-primary-review-mistakes'));
  // Özet kartı eylemi katmanın altına itti; önce kaydırıp kur, sonra ölç.
  await tester.scrollUntilVisible(action, 600);
  await tester.pumpAndSettle();
  expect(action, findsOneWidget, reason: variant.name);

  final expectedLabel = Tr.forKu(K.reviewMistakes, variant.language == 'ku');
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
  final replay = find.byKey(const ValueKey('result-play-again-button'));
  await tester.scrollUntilVisible(replay, 600);
  await tester.pumpAndSettle();
  expect(replay, findsOneWidget, reason: variant.name);
  // İkinci kaydırmadan sonra birincilin karesi bayat; aynı kareden ölç.
  final freshPrimaryRect = tester.getRect(action);
  expect(
    tester.getRect(replay).top,
    greaterThanOrEqualTo(freshPrimaryRect.bottom),
    reason:
        '${variant.name}: narrow result secondary action below primary olmalı',
  );
  expect(tester.takeException(), isNull, reason: variant.name);

  await tester.scrollUntilVisible(action, 600);
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
  expect(find.byType(QuizResultScreen), findsNothing, reason: variant.name);
}

void main() {
  for (final variant in _resultActionVariants) {
    testWidgets(
      'primary review action readable — ${variant.name}',
      (tester) => _expectReadablePrimaryReviewAction(tester, variant),
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

  testWidgets('wide result keeps primary and secondary actions in one row', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(wrapResult(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));

    final primary = tester.getRect(
      find.byKey(const ValueKey('result-primary-review-mistakes')),
    );
    final secondary = tester.getRect(
      find.byKey(const ValueKey('result-play-again-button')),
    );
    expect(secondary.center.dy, inInclusiveRange(primary.top, primary.bottom));
    expect(secondary.left, greaterThan(primary.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('light solo vitrin kimlik yeşili gradyan taşır', (tester) async {
    await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    final header = tester.widget<Container>(
      find.byKey(const ValueKey('result-score-header')),
    );
    final decoration = header.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;
    // 2026-07-24: solo vitrin kimlik anıdır — turuncu yalnız eylem
    // butonunda kalır, beyaz metin perdesiz AA geçmeli.
    //
    // 2026-08-03: iki güvence de aynen duruyor; sabitlenen ŞEY değişti.
    // Test `culturalBrandBg`i tek tek eşitliyordu, yani kimliğin hangi
    // renk olduğunu dondurmuştu. Oysa korunması gereken kural "yeşil
    // olsun" değil, "eylem rengi OLMASIN ve beyazı perdesiz okutsun".
    // Marka yeşilinden koyu turuncuya inen eski gradyan gerçek cihazda
    // kutlama değil çamur veriyordu; Rengîn kutlama yüzeyi derin
    // mürekkepten ametiste geçer. Kural test edilir, sabit edilmez.
    expect(gradient.colors, hasLength(2));
    for (final color in gradient.colors) {
      final luminance = color.computeLuminance();
      expect(
        1.05 / (luminance + 0.05),
        greaterThanOrEqualTo(4.5),
        reason: 'beyaz metin perdesiz okunmalı: $color',
      );
      // Kimlik yüzeyi eylem rengini kullanamaz.
      expect(
        color,
        isNot(AppTheme.brand),
        reason: 'vitrin eylem turuncusunu kullanmamalı',
      );
      expect(color, isNot(AppTheme.brandDeep));
      expect(color, isNot(AppTheme.brandLite));
    }
  });

  testWidgets(
    'yanlış varsa inceleme ana eylem, diğer yollar kapalı gruptadır',
    (tester) async {
      await tester.pumpWidget(wrap(buildScreen(MockZanKurdRepository())));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      final primary = find.byKey(
        const ValueKey('result-primary-review-mistakes'),
      );
      await tester.scrollUntilVisible(primary, 600);
      await tester.pumpAndSettle();
      expect(primary, findsOneWidget);
      expect(
        find.byKey(const ValueKey('result-play-again-button')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('result-more-options')), findsOneWidget);
      expect(find.byKey(const ValueKey('result-home-button')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('result-more-options')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('result-home-button')), findsOneWidget);
    },
  );

  // 2026-07-23 M33: Roj maskotu sonuç ekranında görünsün ve yüksek
  // doğrulukta (8/10 = %80) kutlama modunda olsun.
  testWidgets('skor başlığında Roj maskotu kutlama modunda görünür', (
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
    final mascot = tester.widget<RojMascot>(find.byType(RojMascot));
    expect(mascot.mood, RojMood.celebrate);
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
