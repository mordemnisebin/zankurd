import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/daily_mission_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/play_hub_nav.dart';
import 'support/widget_test_helpers.dart';

/// Sırayla düello bittiğinde günlük görevler ilerler.
///
/// ## Kusur (Codex denetimi 2026-10-29, ürün #4)
///
/// Günlük görev güncellemesi (`DailyMissionStore.reportQuizCompleted`) yalnız
/// normal quiz sonuç akışında çağrılıyordu. Sırayla düelloyu ya da sunucu
/// puanlı kupa maçını bitiren kullanıcı "yarış tamamla" ve "doğru cevap"
/// görevlerini ilerletemiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Düello testleri sonuç ekranını doğruluyordu; görev deposuna kimse
/// bakmıyordu. Kusur "ekran çalışıyor ama yan etki eksik" türündeydi.
///
/// ## Kural
///
/// Düello bitişinde doğru cevaplar bugünün sayacına bir kez eklenir.
class _CountingDuelRepository extends MockZanKurdRepository {
  @override
  Future<AsyncDuelAnswer> answerAsyncDuel({
    required String duelId,
    required int questionIndex,
    required String choice,
    required int responseMs,
  }) async {
    final answer = await super.answerAsyncDuel(
      duelId: duelId,
      questionIndex: questionIndex,
      choice: choice,
      responseMs: responseMs,
    );
    // Test deterministik olsun diye her cevap DOĞRU döner (başlangıçtaki
    // sorular sunucudaki gibi doğru şıkkı gizler; gerçek doğruyu bilemeyiz).
    return AsyncDuelAnswer(
      correct: true,
      correctOption: choice,
      answered: answer.answered,
      total: answer.total,
      finished: answer.finished,
      result: answer.result,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyMissionStore.resetInstance();
  });

  testWidgets('düello bitince doğru cevaplar günlük sayaca bir kez işlenir', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _CountingDuelRepository();
    freshMockRepository();

    await tester.pumpWidget(
      testShell(
        child: PlayHubScreen(repository: repository, asyncDuelEnabled: true),
      ),
    );
    await tester.pumpAndSettle();
    await openAsyncOpponentSheet(tester);
    await tester.tap(find.byKey(const ValueKey('opponent-sheet-random')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byKey(const ValueKey('async-duel-option-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1300));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('async-duel-result')), findsOneWidget);

    final store = await DailyMissionStore.load();
    expect(store.correctAnswersToday, 7);
  });
}
