import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/kilim_progress_bar.dart';

void main() {
  testWidgets('kilim ilerleme doluluk oranını ve kültürel deseni gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(body: KilimProgressBar(value: 0.6, height: 10)),
      ),
    );

    expect(find.byKey(const ValueKey('kilim-progress-track')), findsOneWidget);
    expect(find.byKey(const ValueKey('kilim-progress-fill')), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
