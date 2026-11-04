import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/widgets/daily_event_board.dart';
import 'package:zankurd_mobile/src/widgets/startup_prompts.dart';

import 'support/widget_test_helpers.dart';

/// Akış/durum bekçileri (GPT-6 Pro ekran denetimi, 2026-11-04).
///
/// ## Kusurlar
///
/// 1. Günlük etkinlik panosunun dakika zamanlayıcısı yalnız sayacı yeniden
///    çiziyordu; gün değişince (ya da uygulamaya dönülünce) önceki günün
///    sıralaması ve "dünün kazananı" ekranda kalıyordu.
/// 2. Yaş / rıza pencerelerinde kayıt sürerken düğmeler açıktı; hızlı çift
///    dokunuş iki `_choose` başlatıyor ve ikinci `pop` arkadaki ekranı
///    kapatıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// İkisi de yalnız zamanlama koşulunda görünür: testler tek dokunuş ve tek
/// gün varsayar, `pumpAndSettle` iki dokunuş arasındaki aralığı kapatır.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('gün değişip uygulamaya dönülünce pano yeniden yüklenir', (
    tester,
  ) async {
    var saat = DateTime(2026, 10, 24, 23, 50);
    final repo = _CountingRepo();
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: SingleChildScrollView(
            child: DailyEventBoardCard(repository: repo, clock: () => saat),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repo.loads, 1);

    // Aynı gün içinde dönüş yeniden yüklemez.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.loads, 1);

    saat = DateTime(2026, 10, 25, 0, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repo.loads, 2, reason: 'yeni gün: önceki günün panosu kalmamalı');
  });

  testWidgets('yaş penceresi: ikinci hızlı dokunuş arkadaki ekranı kapatmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Builder(
                    builder: (inner) => Scaffold(
                      body: Column(
                        children: [
                          const Text('arka ekran'),
                          TextButton(
                            onPressed: () =>
                                StartupPrompts.showAgeGateSheet(inner),
                            child: const Text('aç'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('git'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('git'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();

    final yes = find.byKey(const ValueKey('age-gate-yes'));
    await tester.tap(yes);
    // Kayıt sürerken (ilk await) ikinci dokunuş: düğme kapalı olmalı.
    await tester.tap(yes, warnIfMissed: false);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.text('arka ekran'), findsOneWidget);
  });
}

class _CountingRepo extends MockZanKurdRepository {
  int loads = 0;

  @override
  Future<DailyEventBoard?> loadDailyEventBoard() async {
    loads++;
    return null;
  }
}
