// Kusur: ana ekranda günün turu kartı "Te gera rojê qedand" + düğmeyle çizilir,
// sıra satırı ("Îro #2 · 6/10") pano ağdan gelince araya eklenir ve düğme ile
// altındaki her şeyi aşağı iterdi (2026-11-03 simülatör kareleri f7 -> f8).
// Niçin sessiz: testler sıra verisini baştan verir ya da hiç vermezdi; veri
// ÖNCE yok SONRA var iken konum ölçülmezdi.
// Sözleşme: sıra satırının yeri ilk kareden ayrılır; düğme konumu değişmez.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/screens/home/daily_tour_card.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  testWidgets('sıra verisi gelince düğme ve sonraki kart yerinden oynamaz', (
    tester,
  ) async {
    Widget host(DailyEventEntry? entry) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              DailyTourCard(
                isKu: true,
                loading: false,
                doneToday: true,
                myEntry: entry,
                onStart: () {},
                onPractice: () {},
              ),
              const SizedBox(key: ValueKey('sonraki-kart'), height: 40),
            ],
          ),
        ),
      ),
    );

    await tester.pumpWidget(host(null));
    final button = find.byKey(const ValueKey('home-daily-task-practice'));
    final next = find.byKey(const ValueKey('sonraki-kart'));
    final before = (tester.getTopLeft(button), tester.getTopLeft(next));

    await tester.pumpWidget(
      host(
        const DailyEventEntry(
          rank: 2,
          name: 'Ben',
          correct: 6,
          total: 10,
          seconds: 80,
          isMe: true,
        ),
      ),
    );
    expect(find.byKey(const ValueKey('home-daily-task-rank')), findsOneWidget);
    expect((tester.getTopLeft(button), tester.getTopLeft(next)), before);
  });
}
