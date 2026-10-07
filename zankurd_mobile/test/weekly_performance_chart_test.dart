import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/widgets/weekly_performance_chart.dart';

/// Profildeki haftalık çubuk grafik 1 saniyelik easeOutQuart büyümeyle
/// çiziliyordu ve "hareketi azalt" tercihini hiç okumuyordu.
///
/// Çubuk yüksekliği süsüdür, veri taşımaz: tercih açıkken çubuklar ilk
/// karede tam boyda durmalı. Aksi hâlde ayar, profilin en hareketli
/// yüzeyinde yok sayılmış olur.
void main() {
  const history = {
    '2026-09-01': {'correct': 4, 'wrong': 1},
    '2026-09-02': {'correct': 2, 'wrong': 3},
  };

  testWidgets('hareketi azalt açıkken çubuklar büyümez', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReducedMotionProvider(initialUserReduce: true),
        child: const MaterialApp(
          home: Scaffold(
            body: WeeklyPerformanceChart(history: history, isKu: true),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
    expect(
      find.descendant(
        of: find.byType(WeeklyPerformanceChart),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('tercih kapalıyken çubuklar büyür', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WeeklyPerformanceChart(history: history, isKu: true),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
  });
}
