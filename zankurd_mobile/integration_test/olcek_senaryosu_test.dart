// Ölçek senaryosu İSKELETİ (ChatGPT Pro alan 9 #19, 2026-11-06).
//
// Niçin var: `performance_test.dart` yalnız sentetik 400 satırlık bir ListView
// ölçer; gerçek soru bankası (≈6,5 MiB, 25 JSON), gerçek sıralama ekranı ve
// büyük listeler hiçbir ölçümün altında değildi. Bu dosya o boşluğun İLK
// adımıdır: cihazdan bağımsız, sunucusuz, tekrarlanabilir üç ölçüm. Eşik
// (ms) DEĞİL rapor üretir; frame süreleri cihaza göre değişir. Yalnız çökme /
// istisna / bariz bozulma (boş veri) yakalanır.
//
// Çalıştırma (profile mode; yalnız gerçek cihazda anlamlı):
//   flutter drive \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/olcek_senaryosu_test.dart \
//     --profile -d <device_id>
//
// Sonraki adımlar (YAPILMADI; sunucu yükü canlıda/ayrı projede ölçülür):
//   * 1.000 / 5.000 / 10.000 sanal oyuncu: Supabase'e karşı k6/Artillery
//     betiği (ayrı bir STAGING projesinde; canlıya yük bindirilmez). Akışlar:
//     oyuncu başına eş zamanlı get_leaderboard + get_my_leaderboard_rank +
//     get_my_league, oda kurma/katılma/cevap, günlük yarışma başlatma.
//   * EXPLAIN (ANALYZE, BUFFERS): leaderboard_daily_rows(p_days) board CTE'si,
//     get_my_league hafta kapanışı, coin_transactions bakiye toplamı —
//     10.000 oyunculu sentetik veriyle (alan 9 #4, #5, #11 "doğrulanmalı").
//   * Cihazda soru bankası yükü: QuizQuestion.fromJson ana isolate'ta
//     (alan 9 #9); aşağıdaki ölçüm ilk veridir.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Soru bankası açılış yükü (gerçek 25 JSON varlığı)', (
    tester,
  ) async {
    final watch = Stopwatch()..start();
    await QuestionBankLoader.instance.load();
    watch.stop();
    final count = QuestionBankLoader.instance.allQuestions.length;
    // Rapor: ölçülen süre ve soru sayısı build/ çıktısına yazılır.
    binding.reportData = <String, dynamic>{
      'question_bank_load_ms': watch.elapsedMilliseconds,
      'question_bank_count': count,
      'question_bank_failed_assets':
          QuestionBankLoader.instance.failedAssets.length,
    };
    expect(count, greaterThan(1000), reason: 'soru bankası boş yüklenmemeli');
    expect(QuestionBankLoader.instance.failedAssets, isEmpty);
  });

  testWidgets('Büyük liste: 5.000 satırlık sıralama benzeri kaydırma', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemCount: 5000,
            itemExtent: 64,
            itemBuilder: (_, i) => ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text('Lîstikvan $i'),
              trailing: Text('${100000 - i * 7}'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final list = find.byType(Scrollable);
    await binding.traceAction(() async {
      for (var i = 0; i < 4; i++) {
        await tester.fling(list, const Offset(0, -600), 6000);
        await tester.pumpAndSettle();
      }
      await tester.fling(list, const Offset(0, 6000), 12000);
      await tester.pumpAndSettle();
    }, reportKey: 'buyuk_liste_timeline');
    expect(tester.takeException(), isNull);
  });
}
