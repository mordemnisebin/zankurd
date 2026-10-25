import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/app_config.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/my_words_screen.dart';
import 'package:zankurd_mobile/src/screens/word_drill_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';

import 'support/widget_test_helpers.dart';

/// Serbest kelime pratiği (2026-10-25).
///
/// ## Kural
///
/// * Herkese açık: sahibin ilkesi öğrenmenin ayrım gözetmeden herkese
///   açık olması. Önce Pro'ya kilitlenmişti; geri alındı. Abone olmayan
///   da "Tüm kelimelerim" / "Zorlandıklarım" pratiğini açar.
/// * Pratik kutu ve vadeyi DEĞİŞTİRMEZ (Leitner aralıkları bozulmasın).
/// * Paywall bu özelliği Pro faydası diye anmaz.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
    AppConfig.debugHasRevenuecatConfig = true;
  });
  tearDown(() {
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
    AppConfig.debugHasRevenuecatConfig = null;
    PremiumService.debugCanSell = null;
  });

  Future<WordListStore> seed() async {
    final store = await WordListStore.load(storage: InMemoryDataStorage());
    final past = DateTime.now().subtract(const Duration(days: 1));
    await store.add('rojbas', now: past);
    await store.add('cav', now: past);
    return store;
  }

  Future<void> pump(
    WidgetTester tester,
    WordListStore store,
    PremiumService premium,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        premiumService: premium,
        child: MyWordsScreen(repository: MockZanKurdRepository(), store: store),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('abone olmayan da pratik açar, kutular değişmez', (tester) async {
    final store = await seed();
    final before = {for (final w in store.words) w.entryId: w.box};
    await pump(tester, store, PremiumService.fallback());

    expect(find.byKey(const ValueKey('my-words-practice')), findsOneWidget);
    expect(find.byKey(const ValueKey('my-words-practice-weak')), findsOne);
    await tester.tap(find.byKey(const ValueKey('my-words-practice-all')));
    await tester.pumpAndSettle();
    expect(find.byType(WordDrillScreen), findsOneWidget);
    expect(
      tester.widget<WordDrillScreen>(find.byType(WordDrillScreen)).practice,
      isTrue,
    );

    // İlk şıkka dokun (doğru ya da yanlış fark etmez): kutu yazılmamalı.
    await tester.tap(find.byKey(const ValueKey('word-review-option-0')));
    await tester.pumpAndSettle();
    final after = {for (final w in store.words) w.entryId: w.box};
    expect(after, before);
  });
}
