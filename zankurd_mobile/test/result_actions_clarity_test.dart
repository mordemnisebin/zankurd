/// Sonuç ekranının eylem alanı: yinelenen "yanlışları incele" düğmesi ve
/// okunaksız ikincil düğmeler.
///
/// ## Kusur
///
/// 1. Yanlış varsa gösterilen küçük "Yanlışları incele" yan düğmesi
///    (`result-review-mistakes-button`, `openReview(wrongRecords)`) ile hemen
///    altındaki öğrenme kartının "Yanlış cevabı gözden geçir" düğmesi
///    (`learning-outcome-review`, `openReview(learningOutcome.reviewRecords)`)
///    `reviewCategory == null` olduğunda AYNI listeyi açıyordu —
///    `LearningOutcome.fromRecords`e göre `reviewCategory` null iken
///    `reviewRecords` zaten TÜM yanlışlardır (`selectedWrong = wrongRecords`
///    dalı). İki düğme aynı eylemi iki kez sunuyordu.
/// 2. `_ResultSideAction` 76×54 sabit bir kareydi ve etiket
///    `FittedBox(scaleDown)` içindeydi; "Yanlışları incele" bu kutuda ~8px'e
///    küçülüyordu — okunmuyordu.
///
/// ## Niçin sessiz kalırdı
///
/// `quiz_result_visual_test.dart`daki TEK sonuç kurulumu (`buildScreen`) iki
/// sorulu, TEK kategorili (Ziman) bir turdu: 2 cevap, 1 yanlış → %50 yanlış
/// eşiği TAM tutturuluyor, yani `reviewCategory` HEP doluydu — Kusur 1 yalnız
/// `reviewCategory == null` iken ortaya çıkar (kategori başına genelde tek
/// soru düşen "günün dersi" gibi karışık turlarda; bkz. `quiz_round_honesty_
/// test.dart`). Kusur 2 hiçbir testte etiketin GERÇEK piksel boyutunu ya da
/// `FittedBox` varlığını ölçmüyordu; testler yalnız düğmenin var olduğunu
/// (`findsOneWidget`) doğruluyordu, okunabilirliğini değil.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

// `quiz_result_visual_test.dart`taki `wrap`/`wrapResult` ile birebir aynı:
// sonuç ekranı bu sağlayıcılar olmadan kurulamıyor (dil, premium).
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

AnswerRecord _record(String id, String category, {required bool correct}) =>
    AnswerRecord(
      id: id,
      category: category,
      prompt: 'Pirs $id',
      answers: const ['A', 'B'],
      correctAnswer: 'A',
      selectedAnswer: correct ? 'A' : 'B',
      explanation: 'Şirove',
    );

/// Kusur 1'in koşulu: 3 kategoriden 3 cevap, 1 yanlış. Hiçbir kategori
/// `answered >= 2` eşiğini geçmediği için (`LearningOutcome.fromRecords`teki
/// `review` seçimi) `reviewCategory` null kalır — kart TÜM yanlışları açar.
List<AnswerRecord> _noDominantCategoryRecords() => [
  _record('1', 'Ziman', correct: true),
  _record('2', 'Cografya', correct: true),
  _record('3', 'Muzik', correct: false),
];

/// Kontrast senaryo: Ziman'da 2 cevap / %50 yanlış → `reviewCategory` =
/// 'Ziman' (dolu, eşik TAM tutturuluyor). Cografya'da AYRICA, Ziman'dan
/// bağımsız bir yanlış var. Kart yalnız Ziman'ın yanlışını açar (1 kayıt);
/// yan düğme HER İKİSİNİ de açar (2 kayıt) — burada iki düğme GERÇEKTEN
/// farklı kapsamlar sunar, ikisi de kalmalı.
List<AnswerRecord> _dominantCategoryPlusElsewhereRecords() => [
  _record('1', 'Ziman', correct: true),
  _record('2', 'Ziman', correct: false),
  _record('3', 'Cografya', correct: false),
];

QuizResultScreen _buildScreen(
  MockZanKurdRepository repository,
  List<AnswerRecord> records,
) {
  final correct = records.where((r) => r.isCorrect).length;
  final wrong = records.where((r) => !r.isCorrect && !r.isUnanswered).length;
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: correct * 100,
    correctCount: correct,
    wrongCount: wrong,
    totalQuestions: records.length,
    bestStreak: 1,
    coinsAwarded: 0,
    answerRecords: records,
  );
}

void main() {
  testWidgets(
    'baskın kategori yokken yan düğme yok, kart düğmesi hepsini açar',
    (tester) async {
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(
        wrap(_buildScreen(repository, _noDominantCategoryRecords())),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('result-review-mistakes-button')),
        findsNothing,
        reason:
            'reviewCategory null iken kart zaten TÜM yanlışları açıyor; '
            'yan düğme birebir aynı eylemi ikinci kez sunardı (Kusur 1).',
      );
      final cardReview = find.byKey(const ValueKey('learning-outcome-review'));
      expect(cardReview, findsOneWidget);

      await tester.ensureVisible(cardReview);
      await tester.pumpAndSettle();
      await tester.tap(cardReview);
      await tester.pumpAndSettle();
      expect(
        find.byType(ReviewScreen),
        findsOneWidget,
        reason: 'kart düğmesi tek başına gözden geçirmeyi açabilmeli',
      );
    },
  );

  testWidgets('baskın kategori VE başka yerde yanlış varsa iki düğme de kalır', (
    tester,
  ) async {
    final repository = MockZanKurdRepository();
    await tester.pumpWidget(
      wrap(_buildScreen(repository, _dominantCategoryPlusElsewhereRecords())),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('result-review-mistakes-button')),
      findsOneWidget,
      reason:
          'reviewCategory doluyken kart yalnız O KONUYU açar; yan düğme hâlâ '
          'HEPSİNİ açan tek yoldur — burada iki düğme farklıdır, ikisi kalmalı.',
    );
    expect(
      find.byKey(const ValueKey('learning-outcome-review')),
      findsOneWidget,
    );
  });

  testWidgets(
    'yan eylem etiketleri okunur boyutta, FittedBox küçültmez, düğme >= 48 yüksek',
    (tester) async {
      final repository = MockZanKurdRepository();
      await tester.pumpWidget(
        wrap(_buildScreen(repository, _dominantCategoryPlusElsewhereRecords())),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      const sideActionKeys = [
        'result-review-mistakes-button',
        'result-share-button',
      ];
      for (final keyName in sideActionKeys) {
        final button = find.byKey(ValueKey(keyName));
        expect(button, findsOneWidget, reason: keyName);
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: button, matching: find.byType(FittedBox)),
          findsNothing,
          reason:
              '$keyName: Kusur 2 — FittedBox(scaleDown) etiketi ~8pxe '
              'küçültüyordu; hap düğmede FittedBox hiç olmamalı.',
        );

        final label = tester.widget<Text>(
          find.descendant(of: button, matching: find.byType(Text)),
        );
        expect(
          label.style?.fontSize,
          isNotNull,
          reason: '$keyName: etiket stili fontSize taşımalı',
        );
        expect(
          label.style!.fontSize!,
          greaterThanOrEqualTo(13),
          reason: '$keyName: Kusur 2 — küçülen etiket okunmuyordu',
        );

        expect(
          tester.getRect(button).height,
          greaterThanOrEqualTo(48),
          reason: '$keyName: dokunma hedefi tabanı 48pt olmalı',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['tr', 'ku']) {
    testWidgets(
      'dar ekran + %200 yazı ($language): taşma yok, haplar üst üste binmez',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repository = MockZanKurdRepository();
        await tester.pumpWidget(
          wrapResult(
            _buildScreen(repository, _dominantCategoryPlusElsewhereRecords()),
            language: language,
            textScale: 2.0,
          ),
        );
        await tester.pump(const Duration(seconds: 1));

        // Sliver, önbellek uzunluğunun ötesindeki çocukları henüz kurmamış
        // olabilir; `buildScreen`deki `_expectReadablePrimaryNextAction` ile
        // AYNI desen — önce kaydır, SONRA var say. Haplar aynı bloktaki
        // bitişik öğeler olduğu için TEK kaydırma ikisini de görünür kılar.
        final review = find.byKey(
          const ValueKey('result-review-mistakes-button'),
        );
        final share = find.byKey(const ValueKey('result-share-button'));
        await tester.scrollUntilVisible(review, 600);
        await tester.pumpAndSettle();

        expect(review, findsOneWidget, reason: language);
        expect(share, findsOneWidget, reason: language);

        final reviewRect = tester.getRect(review);
        final shareRect = tester.getRect(share);
        expect(
          reviewRect.overlaps(shareRect),
          isFalse,
          reason:
              '$language: haplar üst üste binmemeli — $reviewRect / $shareRect',
        );
        expect(tester.takeException(), isNull, reason: language);
      },
    );
  }
}
