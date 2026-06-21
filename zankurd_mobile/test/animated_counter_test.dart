import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/animated_counter.dart';

Widget _host(int value) => MaterialApp(
      home: Scaffold(
        body: Center(child: AnimatedCounter(value: value)),
      ),
    );

void main() {
  testWidgets('ilk değeri animasyonsuz gösterir', (tester) async {
    await tester.pumpWidget(_host(42));
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('değer değişince son değere ulaşır', (tester) async {
    await tester.pumpWidget(_host(10));
    expect(find.text('10'), findsOneWidget);

    await tester.pumpWidget(_host(50));
    // Animasyon ortasında ara bir değer gösterilir (10 da 50 de değil).
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('10'), findsNothing);
    expect(find.text('50'), findsNothing);

    // Animasyon bitince hedef değere ulaşır.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('50'), findsOneWidget);
  });

  testWidgets('verilen stili uygular', (tester) async {
    const style = TextStyle(fontSize: 20, fontWeight: FontWeight.w900);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AnimatedCounter(value: 7, style: style)),
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('7'));
    expect(text.style?.fontWeight, FontWeight.w900);
    expect(text.style?.fontSize, 20);
  });
}
