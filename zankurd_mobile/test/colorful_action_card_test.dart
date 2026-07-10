import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/colorful_action_card.dart';

void main() {
  testWidgets('ColorfulActionCard renders and invokes callback', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: '1 vs 1',
            subtitle: 'Hemen oyna',
            icon: Icons.bolt_rounded,
            colors: const [AppTheme.playPink, Color(0xFFFF6B70)],
            onTap: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('1 vs 1'), findsOneWidget);
    expect(find.text('Hemen oyna'), findsOneWidget);
    await tester.tap(find.text('1 vs 1'));
    expect(taps, 1);
  });

  testWidgets('loading card ignores taps and shows progress', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ColorfulActionCard(
            title: 'Günün Yarışması',
            icon: Icons.emoji_events_rounded,
            colors: const [AppTheme.brandOrange, AppTheme.brandOrangeWarm],
            loading: true,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Günün Yarışması'));
    expect(tapped, isFalse);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
