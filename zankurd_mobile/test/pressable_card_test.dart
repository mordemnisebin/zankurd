import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/widgets/pressable_card.dart';

void main() {
  testWidgets('onTap tetiklenir ve child render olur', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PressableCard(
            onTap: () => tapped = true,
            child: const Text('selam'),
          ),
        ),
      ),
    );

    expect(find.text('selam'), findsOneWidget);
    await tester.tap(find.text('selam'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });
}
