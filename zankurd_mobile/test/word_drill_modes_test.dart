import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/word_drill.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/word_drill_screen.dart';

import 'support/widget_test_helpers.dart';

/// Kutu ilerledikçe değişen tekrar türleri (2026-10-25).
///
/// ## Kusur
///
/// Tekrar her kutuda aynı soruydu: Kurmancî sözcük → dört Türkçe anlam.
/// Beşinci kutudaki kelime de yalnız TANINIYORDU; öğrenen sözcüğü hiç
/// hatırlamıyor, yazmıyor, sesini Hawar harfiyle eşlemiyordu.
///
/// ## Kural
///
/// Kutu 1 anlam, 2 geri çağırma, 3 dinleme (ses yoksa geri çağırma), 4+
/// harf dizme (uygun değilse dinleme/geri çağırma). Yazım sorularında harf
/// işareti önemlidir (e ≠ ê).
void main() {
  LearnerLexiconEntry entry(String id) => LearnerLexicon.byId(id)!;

  group('tür seçimi', () {
    test('kutuya göre tür', () {
      final cav = entry('cav');
      WordReviewMode m(int box, {bool listen = true}) =>
          WordReviewQuestion.modeForBox(box, entry: cav, canListen: listen);
      expect(m(1), WordReviewMode.meaning);
      expect(m(2), WordReviewMode.reverse);
      expect(m(3), WordReviewMode.listen);
      expect(m(3, listen: false), WordReviewMode.reverse);
      expect(m(4), WordReviewMode.spell);
      expect(m(5), WordReviewMode.spell);
    });

    test('çok sözcüklü madde harf dizmeye girmez', () {
      final rojbas = entry('rojbas');
      expect(WordReviewQuestion.canSpell(rojbas), isTrue);
      final multi = LearnerLexicon.entries.firstWhere(
        (e) => e.termKu.trim().contains(' '),
      );
      expect(WordReviewQuestion.canSpell(multi), isFalse);
      expect(
        WordReviewQuestion.modeForBox(4, entry: multi, canListen: false),
        WordReviewMode.reverse,
      );
    });
  });

  group('soru kurma', () {
    test('Hawar varyantları tek harfi çiftiyle değiştirir', () {
      final v = WordReviewQuestion.hawarVariants('Şêr');
      expect(v, containsAll(['Sêr', 'Şer']));
      expect(v, isNot(contains('Şêr')));
      expect(WordReviewQuestion.hawarVariants('bav'), isEmpty);
    });

    test('geri çağırma: dört farklı Kurmancî şık, biri doğru', () {
      for (var seed = 0; seed < 20; seed++) {
        final q = WordReviewQuestion.buildFor(
          entry('cav'),
          WordReviewMode.reverse,
          random: math.Random(seed),
        );
        expect(q.options, hasLength(4));
        expect(q.options.map((o) => o.toLowerCase()).toSet(), hasLength(4));
        expect(q.options.where(q.isCorrect), hasLength(1));
      }
    });

    test('dinleme: Hawar varyantı şıklarda, doğru yazım tek', () {
      final q = WordReviewQuestion.buildFor(
        entry('cav'),
        WordReviewMode.listen,
        random: math.Random(1),
      );
      expect(q.options, hasLength(4));
      expect(q.options, contains('cav'));
      expect(q.options.where(q.isCorrect), hasLength(1));
      expect(q.isCorrect('çav'), isTrue);
      expect(q.isCorrect('Çav'), isTrue);
    });

    test('harf dizme: harfler sözcüğün harfleri, sırası karışık', () {
      final q = WordReviewQuestion.buildFor(
        entry('rojbas'),
        WordReviewMode.spell,
        random: math.Random(2),
      );
      final term = entry('rojbas').termKu.toLowerCase();
      expect([...q.letters]..sort(), [...term.split('')]..sort());
      expect(q.letters.join(), isNot(term));
    });
  });

  group('ekran', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      WordListStore.resetInstance();
      LocalProgressScope.debugReset();
    });
    tearDown(() {
      WordListStore.resetInstance();
      LocalProgressScope.debugReset();
    });

    Future<void> pump(WidgetTester tester, SavedWord word) async {
      tester.view.devicePixelRatio = 3.0;
      tester.view.physicalSize = const Size(390, 900) * 3;
      addTearDown(tester.view.reset);
      final store = await WordListStore.load(storage: InMemoryDataStorage());
      await tester.pumpWidget(
        testShell(
          languageProvider: turkishLang(),
          child: WordDrillScreen(
            store: store,
            words: [word],
            random: math.Random(5),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    SavedWord saved(String id, int box) =>
        SavedWord(entryId: id, box: box, dueAtMs: 0, addedAtMs: 0);

    testWidgets('kutu 2: Türkçe anlam sorulur, Kurmancî şıklar', (
      tester,
    ) async {
      await pump(tester, saved('cav', 2));
      expect(find.byKey(const ValueKey('word-review-mode-reverse')), findsOne);
      expect(find.text('göz'), findsOneWidget);
      await tester.tap(find.text('çav'));
      await tester.pump();
      expect(find.text('Doğru'), findsOneWidget);
      expect(find.byKey(const ValueKey('word-review-reveal')), findsOne);

      // Bitiş ekranı kelime özetini gösterir.
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('word-review-next')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('word-review-summary')), findsOne);
      expect(find.text('çav'), findsOneWidget);
    });

    testWidgets('kutu 4: harfleri dizerek yazılır', (tester) async {
      await pump(tester, saved('cav', 4));
      expect(find.byKey(const ValueKey('word-review-mode-spell')), findsOne);
      final q = WordReviewQuestion.buildFor(
        entry('cav'),
        WordReviewMode.spell,
        random: math.Random(5),
      );
      // Ekrandaki karolar aynı tohumla aynı sıradadır; doğru sırayla dokun.
      final used = <int>{};
      for (final ch in 'çav'.split('')) {
        final i = List.generate(
          q.letters.length,
          (i) => i,
        ).firstWhere((i) => q.letters[i] == ch && !used.contains(i));
        used.add(i);
        await tester.tap(find.byKey(ValueKey('word-review-letter-$i')));
        await tester.pump();
      }
      await tester.tap(find.byKey(const ValueKey('word-review-check')));
      await tester.pump();
      expect(find.text('Doğru'), findsOneWidget);
    });
  });
}
