// İlk 5 dakika akışı (2026-11-03): tanıtım -> amaç -> "Kurmancî biliyor
// musun?" -> ilk ders -> ilk başarı -> hesap önerisi.
//
// EKSİK NEYDİ: amaç ayarlarda, seviye sınavı öğrenme sekmesinde küçük bir
// şerit, "Kelimelerim" boşken çıkmaz sokaktı; yeni oyuncu tanıtımdan sonra
// ne yapacağını bilmeden boş bir ana ekrana düşüyordu.
//
// Bu dosya şunları sabitler:
//  * işaret yalnız yeni tanıtımda konur; işaretsiz (mevcut) kullanıcı akışı
//    ASLA görmez, tüketilen işaret ikinci kez akış açmaz;
//  * iki soru 375x667'de ve büyük yazıda taşmadan çizilir;
//  * "Atla" ve iki cevap da planı kaydeder (kullanıcı hiçbir yerde kilitlenmez);
//  * ilk başarı ekranı kelimeyi ve sesini gösterir, tek dokunuşla kapanır;
//  * boş "Kelimelerim"in ilk derse giden düğmesi vardır.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/first_run_store.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/models/learning_goal.dart';
import 'package:zankurd_mobile/src/screens/first_run_choice_screen.dart';
import 'package:zankurd_mobile/src/screens/my_words_screen.dart';

import 'support/widget_test_helpers.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(375, 667),
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      languageProvider: turkishLang(),
      child: MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)),
        child: child,
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('FirstRunStore', () {
    test('işaretsiz (mevcut) kullanıcıya plan verilmez', () async {
      expect(await FirstRunStore.stage(), isNull);
      expect(await FirstRunStore.consumeLaunch(), isNull);
    });

    test(
      'tanıtım sonrası choice, cevaptan sonra launch; tüketilince silinir',
      () async {
        await FirstRunStore.armChoice();
        expect(await FirstRunStore.stage(), FirstRunStage.choice);
        // choice aşamasında iniş planı yok.
        expect(await FirstRunStore.consumeLaunch(), isNull);

        await FirstRunStore.saveChoice(
          const FirstRunPlan(
            goal: LearningGoal.discoverCulture,
            wantsPlacement: true,
          ),
        );
        expect(await FirstRunStore.stage(), FirstRunStage.launch);
        final plan = await FirstRunStore.consumeLaunch();
        expect(plan?.goal, LearningGoal.discoverCulture);
        expect(plan?.wantsPlacement, isTrue);
        // İkinci kez akış açılmaz.
        expect(await FirstRunStore.stage(), isNull);
        expect(await FirstRunStore.consumeLaunch(), isNull);
      },
    );
  });

  group('FirstRunChoiceScreen', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('iki adım 375x667 ve ${scale}x yazıda taşmaz', (
        tester,
      ) async {
        await _pump(tester, FirstRunChoiceScreen(onDone: () {}), scale: scale);
        expect(find.text('Bugün neye odaklanmak istersin?'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('learning-goal-language')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.ensureVisible(
          find.byKey(const ValueKey('first-run-goal-next')),
        );
        await tester.tap(find.byKey(const ValueKey('first-run-goal-next')));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Kurmancî biliyor musun?'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('first-run-know-some')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('amaç + "baştan" cevabı planı kaydeder', (tester) async {
      var done = 0;
      await _pump(tester, FirstRunChoiceScreen(onDone: () => done++));
      await tester.tap(find.byKey(const ValueKey('learning-goal-culture')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('first-run-goal-next')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('first-run-know-beginner')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(done, 1);
      final plan = await FirstRunStore.consumeLaunch();
      expect(plan?.goal, LearningGoal.discoverCulture);
      expect(plan?.wantsPlacement, isFalse);
    });

    testWidgets(
      '"biraz biliyorum" seviye sınavı ister; Atla varsayılanı yazar',
      (tester) async {
        await _pump(tester, FirstRunChoiceScreen(onDone: () {}));
        await tester.tap(find.byKey(const ValueKey('first-run-goal-next')));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.byKey(const ValueKey('first-run-know-some')));
        await tester.pump(const Duration(milliseconds: 300));
        expect((await FirstRunStore.consumeLaunch())?.wantsPlacement, isTrue);

        // Önceki ekranın durumu (adım, kilit) yeni ekrana sızmasın.
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, FirstRunChoiceScreen(onDone: () {}));
        await tester.tap(find.byKey(const ValueKey('first-run-skip')));
        await tester.pump(const Duration(milliseconds: 300));
        final skipped = await FirstRunStore.consumeLaunch();
        expect(skipped, isNotNull);
        expect(skipped?.goal, isNull);
        expect(skipped?.wantsPlacement, isFalse);
      },
    );
  });

  testWidgets('ilk başarı ekranı kelimeyi gösterir ve tek dokunuşla kapanır', (
    tester,
  ) async {
    const entry = LearnerLexiconEntry(
      id: 'x',
      termKu: 'Silav',
      meaningTr: 'Merhaba',
      sourceId: 's',
    );
    await _pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const FirstSuccessScreen(entry: entry),
              ),
            ),
            child: const Text('aç'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('first-success-word')), findsOneWidget);
    expect(find.text('Silav'), findsOneWidget);
    expect(find.text('Merhaba'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('first-success-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('first-success-word')), findsNothing);
  });

  testWidgets('boş Kelimelerim ilk derse giden düğme taşır', (tester) async {
    final store = await WordListStore.load(storage: InMemoryDataStorage());
    await _pump(
      tester,
      MyWordsScreen(repository: MockZanKurdRepository(), store: store),
    );
    expect(find.text('İlk derse başla'), findsOneWidget);
  });
}
