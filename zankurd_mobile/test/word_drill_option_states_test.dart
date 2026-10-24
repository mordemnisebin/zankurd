import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/word_drill_screen.dart';

import 'support/widget_test_helpers.dart';

/// Kelime tekrarında cevap sonrası şık durumları.
///
/// ## Kusur
///
/// Cevaptan sonra şıklar `onPressed: null` ile pasifleştiriliyordu; pasif
/// `SahneButton` ton dolgusunu değil ortak soluk dolguyu çizer. Doğru şık
/// yeşil, yanlış seçilen kırmızı olmalıydı ama dördü de aynı gri kalıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Mevcut testler düğme anahtarını, skoru ve kutu geçişini sınıyordu; rengi
/// (pasif düğmenin temadan gelen dolgusu) sınayan yoktu.
///
/// ## Kural
///
/// Cevaptan sonra doğru şık `correct`, yanlış seçilen `selected && !correct`,
/// ötekiler `dimmed` olan quiz şık çubuğudur (`QuizOptionTile`); cevaptan
/// önce hiçbirinde durum yoktur (renk cevabı ele vermez).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });
  tearDown(() {
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 3.0;
    tester.view.physicalSize = const Size(390, 800) * 3;
    addTearDown(tester.view.reset);
    final store = await WordListStore.load(storage: InMemoryDataStorage());
    await store.add(
      'rojbas',
      now: DateTime.now().subtract(const Duration(days: 1)),
    );
    await tester.pumpWidget(
      testShell(
        languageProvider: turkishLang(),
        child: WordDrillScreen(store: store, random: math.Random(3)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  List<QuizOptionTile> tiles(WidgetTester tester) =>
      tester.widgetList<QuizOptionTile>(find.byType(QuizOptionTile)).toList();

  testWidgets('cevaptan önce hiçbir şıkta durum yok', (tester) async {
    await pump(tester);
    final all = tiles(tester);
    expect(all, hasLength(4));
    for (final tile in all) {
      expect(tile.correct, isFalse);
      expect(tile.selected, isFalse);
      expect(tile.dimmed, isFalse);
      expect(tile.disabled, isFalse);
    }
  });

  testWidgets('yanlış seçimde: doğru yeşil, seçilen yanlış, ötekiler sönük', (
    tester,
  ) async {
    await pump(tester);
    final right = LearnerLexicon.byId('rojbas')!.meaningTr;
    final wrongIndex = tiles(tester).indexWhere((t) => t.answer != right);
    await tester.tap(find.byKey(ValueKey('word-review-option-$wrongIndex')));
    await tester.pump();

    final all = tiles(tester);
    for (var i = 0; i < all.length; i++) {
      final tile = all[i];
      expect(tile.disabled, isTrue);
      if (tile.answer == right) {
        expect(tile.correct, isTrue, reason: 'doğru şık yeşil');
        expect(tile.dimmed, isFalse);
      } else if (i == wrongIndex) {
        expect(tile.selected, isTrue, reason: 'seçilen yanlış kırmızı');
        expect(tile.correct, isFalse);
        expect(tile.dimmed, isFalse);
      } else {
        expect(tile.dimmed, isTrue);
        expect(tile.selected, isFalse);
        expect(tile.correct, isFalse);
      }
    }
  });

  testWidgets('doğru seçimde yalnız doğru şık yeşil', (tester) async {
    await pump(tester);
    final right = LearnerLexicon.byId('rojbas')!.meaningTr;
    await tester.tap(find.text(right).first);
    await tester.pump();
    final all = tiles(tester);
    expect(all.where((t) => t.correct).map((t) => t.answer), [right]);
    expect(all.where((t) => t.selected && !t.correct), isEmpty);
    expect(all.where((t) => t.dimmed), hasLength(3));
  });
}
